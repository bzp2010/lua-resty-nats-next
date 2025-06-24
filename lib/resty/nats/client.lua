local ngx            = ngx
local tcp            = ngx.socket.tcp
local thread_spawn   = ngx.thread.spawn
local thread_wait    = ngx.thread.wait
local thread_kill    = ngx.thread.kill
local worker_exiting = ngx.worker.exiting

local common           = require("resty.nats.common")

-- server-side messages
local protocol_parser  = require("resty.nats.protocols.parser")
local protocol_info    = require("resty.nats.protocols.info")

-- client-side messages
local protocol_connect = require("resty.nats.protocols.connect")
local protocol_pub     = require("resty.nats.protocols.pub")
local protocol_sub     = require("resty.nats.protocols.sub")
local protocol_unsub   = require("resty.nats.protocols.unsub")


local _M = {}
local mt = { __index = _M }


local function retryable_error(err)
  return err ~= "timeout" and err ~= "closed"
end


local function _handshake(self)
  -- Receive server-side INFO message
  local line, err = self.sock:receive()
  if not line then
    return false, "failed to read a line: " .. err
  end

  if line:sub(1, 4) ~= "INFO" then
    return false, "expected INFO line, got: " .. line
  end
  local server_info = protocol_info.decode(line)
  self.server_info.headers = server_info.headers

  if self.socket_config.keepalive then
    local count, err = self.sock:getreusedtimes()
    if not count and err then
      self.sock:close()
      return false, "failed to get connection reused times: " .. err
    end

    -- skip the TLS handshake and NATS handshake on reused connections
    if count > 0 then
      ngx.log(ngx.DEBUG, "reuse NATS connection, count: ", count)
      return true
    end
  end

  if self.socket_config.ssl and server_info and server_info.tls_required then
    local _, err = self.sock:sslhandshake(false, nil, self.socket_config.ssl_verify)
    if err then
      self.sock:close()
      return false, "failed to perform SSL handshake: " .. err
    end
  end

  local connect_msg = {
    verbose = false,
    pedantic = true,
    tls_required = self.socket_config.ssl,
    name = "lua-resty-nats-next",
    lang = "lua",
    version = common.VERSION,
    headers = server_info.headers,
  }
  for key, value in pairs(self.auth_config) do
    connect_msg[key] = value
  end

  local bytes, err = self.sock:send(protocol_connect.encode(connect_msg) .. "\r\n")
  if not bytes then
    return false, "failed to send connect message: " .. err
  end
  return true
end


function _M.connect(opts)
  local socket_config = {
    timeout = opts.timeout or 60000,
    keepalive = opts.keepalive or true,
    keepalive_timeout = opts.keepalive_timeout or (600 * 1000),
    keepalive_size = opts.keepalive_size or 2,
    keepalive_pool = opts.keepalive_pool or (opts.host .. ":" .. opts.port),
    ssl = opts.ssl or false,
    ssl_verify = opts.ssl_verify or true,
  }

  local sock, err = tcp()
  if not sock then
    return nil, err, true
  end

  sock:settimeout(socket_config.timeout)

  local ok, err = sock:connect(opts.host, opts.port, {
    pool = socket_config.keepalive_pool,
    pool_size = socket_config.keepalive_size,
    backlog = 0 -- disable backlog, ref: https://github.com/openresty/lua-nginx-module/blob/edd1b6a/src/ngx_http_lua_socket_tcp.c#L578
  })
  if not ok then
    return nil, err, true
  end

  local cli = setmetatable({
    host = opts.host,
    port = opts.port,
    sock = sock,
    server_info = { headers = true },
    auth_config = opts.auth_config or {},
    socket_config = socket_config,
    closing = false,

    subscriber_id = 0,
    subscriber_id_map = {},
    subscribers = {},
  }, mt)

  ok, err = _handshake(cli)
  if not ok then
    sock:close()
    return nil, err, false
  end

  return cli
end


function _M.subscribe(self, subject, cb)
  self.subscriber_id = self.subscriber_id + 1
  self.subscribers[self.subscriber_id] = cb
  self.subscriber_id_map[subject] = self.subscriber_id

  local bytes, err = self.sock:send(protocol_sub.encode({
    subject = subject,
    sid = self.subscriber_id,
    queue_group = nil, --TODO
  }) .. "\r\n")
  if not bytes then
    local retryable = retryable_error(err)
    if err == "timeout" then
      self.sock:close()
      return false, "connection timeout", retryable
    end
    return false, "failed to send SUB message: " .. err, retryable
  end
  return true
end


function _M.unsubscribe(self, subject)
  local subscriber_id = self.subscriber_id_map[subject]
  if not subscriber_id then
    return false, "no such subscription found", false
  end

  local bytes, err = self.sock:send(protocol_unsub.encode(subscriber_id, {}) .. "\r\n")
  if not bytes then
    local retryable = retryable_error(err)
    if err == "timeout" then
      self.sock:close()
      return false, "connection timeout", retryable
    end
    return false, "failed to send UNSUB message: " .. err, retryable
  end

  self.subscribers[subscriber_id] = nil
  self.subscriber_id_map[subject] = nil
  return true
end


function _M.publish(self, opts)
  local bytes, err = self.sock:send(protocol_pub.encode(opts) .. "\r\n")
  if not bytes then
    local retryable = retryable_error(err)
    if err == "timeout" then
      self.sock:close()
      return false, "connection timeout", retryable
    end
    return false, "failed to send PUB message: " .. err, retryable
  end
  return true
end


function _M.start_loop(self)
  ---@type tcpsock
  local sock = self.sock

  local error_handler = function (err)
    if not err then
      return
    end
    if err == "timeout" then
      sock:close()
    end
    error(err)
  end

  local parser = protocol_parser.new(function (type, message)
    if type == protocol_parser.MESSAGE_TYPE.PING then
      local bytes, err = sock:send("PONG\r\n")
      if not bytes then
        return error_handler(err)
      end
    elseif type == protocol_parser.MESSAGE_TYPE.MSG then
      local subscriber_id = tonumber(message.sid)
      if not subscriber_id then
        return error_handler("invalid subscriber ID: " .. message.sid)
      end

      local subscriber = self.subscribers[subscriber_id]
      if not subscriber then
        return error_handler("no subscriber found for ID: " .. subscriber_id)
      end

      subscriber(message)
    elseif type == protocol_parser.MESSAGE_TYPE.HMSG then
      local subscriber_id = tonumber(message.sid)
      if not subscriber_id then
        return error_handler("invalid subscriber ID: " .. message.sid)
      end

      local subscriber = self.subscribers[subscriber_id]
      if not subscriber then
        return error_handler("no subscriber found for ID: " .. subscriber_id)
      end

      subscriber(message)
    end
  end)

  local receive_thread = thread_spawn(function ()
    while not ngx.worker.exiting() do
      if self.closing then
        return
      end
      local line, err = sock:receiveany(70)
      if not line then
        return error_handler(err)
      end
      error_handler(parser:parse(line))
    end
  end)
  local ok, err = thread_wait(receive_thread)
  if not ok then
    error("failed to start receive thread: " .. err)
  end
  thread_kill(receive_thread)
end


function _M.close(self)
  if not self.closing then
    self.closing = true
  end
  if self.sock then
    ---@type tcpsock
    local sock = self.sock
    if self.socket_config.keepalive and not worker_exiting() then
      local ok, err = sock:setkeepalive(self.socket_config.keepalive_timeout)
      if not ok then
        sock:close()
        return "failed to keep connection: " .. err
      end
    else
      local ok, err = sock:close()
      if not ok then
        return "failed to close connection: " .. err
      end
    end
    self.sock = nil
  end
end


return _M
