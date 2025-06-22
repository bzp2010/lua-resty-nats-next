local ngx            = ngx
local re_match       = ngx.re.match
local worker_exiting = ngx.worker.exiting

local protocol_msg = require("resty.nats.protocols.msg")
local protocol_hmsg = require("resty.nats.protocols.hmsg")
local protocol_err = require("resty.nats.protocols.err")

local _M = {}
local mt = { __index = _M }


_M.MESSAGE_TYPE = {
  INFO  = "INFO",
  MSG   = "MSG",
  HMSG  = "HMSG",
  PING  = "PING",
  PONG  = "PONG",
  PUB   = "PUB",
  SUB   = "SUB",
  UNSUB = "UNSUB",
  OK    = "+OK",
  ERR   = "-ERR",

  -- internal
  UNKNOWN = "UNKNOWN",
}

local FSM_state = {
  WAIT_CONTROL_LINE     = 1,
  WAIT_MSG_PAYLOAD      = 2, -- wait message payload
  WAIT_HEADERS_PAYLOAD  = 3, -- wait headers payload
}

function _M.new(on_message)
  return setmetatable({
    buf = "",
    state = FSM_state.WAIT_CONTROL_LINE,
    msg_buf = nil,
    on_message = on_message,
  }, mt)
end


function _M.parse(self, bytes)
  ---@type string
  bytes = self.buf .. bytes
  self.buf = ""

  local offset = 1
  while not worker_exiting() do
    if offset > #bytes then
      return
    end

    local remain = bytes:sub(offset)

    if self.state == FSM_state.WAIT_CONTROL_LINE then
      local line_ctx = {}
      local m = re_match(remain, [[^(.*)\r\n]], "jo", line_ctx)
      local line = m and m[1] or nil

      if line then
        if bytes:sub(offset, offset + 2) == self.MESSAGE_TYPE.MSG then
          self.state = FSM_state.WAIT_MSG_PAYLOAD
          local msg, err = protocol_msg.decode(line)
          if not msg then
            print("failed to decode message: " .. err)
            return
          end
          offset = offset + line_ctx.pos - 1
          self.msg_buf = msg
        elseif bytes:sub(offset, offset + 3) == self.MESSAGE_TYPE.HMSG then
          self.state = FSM_state.WAIT_HEADERS_PAYLOAD
          local msg, err = protocol_hmsg.decode(line)
          if not msg then
            print("failed to decode message: " .. err)
            return
          end
          offset = offset + line_ctx.pos - 1
          self.msg_buf = msg
        elseif bytes:sub(offset, offset + 3) == self.MESSAGE_TYPE.PING then
          self.on_message(self.MESSAGE_TYPE.PING)
          offset = offset + 6 -- PING\r\n
        elseif bytes:sub(offset, offset + 2) == self.MESSAGE_TYPE.OK then
          self.on_message(self.MESSAGE_TYPE.OK)
          offset = offset + 5 -- +OK\r\n
        elseif bytes:sub(offset, offset + 3) == self.MESSAGE_TYPE.ERR then
          local msg, err = protocol_err.decode(line)
          if not msg then
            print("failed to decode error message: " .. err)
            return
          end
          self.on_message(self.MESSAGE_TYPE.ERR, msg)
          offset = offset + line_ctx.pos - 1
        elseif bytes:sub(offset, offset + 3) == self.MESSAGE_TYPE.INFO then
          -- TODO: handle endpoints updated
          offset = offset + line_ctx.pos - 1
        end
      else
        self.buf = remain
        offset = #bytes + 1
      end
      goto CONTINUE
    end

    if self.state == FSM_state.WAIT_MSG_PAYLOAD then
      if not self.msg_buf then
        return "no message buffer found in WAIT_MSG_PAYLOAD state"
      end

      if #remain < self.msg_buf.size + 2 then -- payload size + \r\n
        self.buf = remain
        offset = #bytes + 1
        return
      end

      local payload_str = bytes:sub(offset, offset + self.msg_buf.size - 1)
      self.msg_buf.payload = payload_str
      offset = offset + self.msg_buf.size + 2 -- +2 for \r\n
      self.msg_buf.pos = nil
      self.on_message(self.msg_buf.headers and self.MESSAGE_TYPE.HMSG or self.MESSAGE_TYPE.MSG, self.msg_buf)

      self.msg_buf = nil
      self.state = FSM_state.WAIT_CONTROL_LINE
      goto CONTINUE
    end

    if self.state == FSM_state.WAIT_HEADERS_PAYLOAD then
      if not self.msg_buf then
        return "no message buffer found in WAIT_HEADERS_PAYLOAD state"
      end

      if #remain < self.msg_buf.headers_size + 4 then
        self.buf = remain -- save the rest of the buffer
        offset = #bytes + 1
        return
      end

      local headers_str = bytes:sub(offset, offset + self.msg_buf.headers_size - 5)
      self.msg_buf.headers = protocol_hmsg.decode_headers(headers_str)
      offset = offset + self.msg_buf.headers_size
      self.msg_buf.headers_size = nil
      self.state = FSM_state.WAIT_MSG_PAYLOAD
      goto CONTINUE
    end

    ::CONTINUE::
  end
end


return _M
