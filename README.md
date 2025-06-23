# lua-resty-nats-next

The next generation of [NATS](https://nats.io) message queuing client for OpenResty.

It can be used in cross-Nginx worker or cross-instance Pub/Sub patterns.

## Table of Contents

- [Status](#status)
- [Installation](#installation)
- [Synopsis](#synopsis)
- [Description](#description)
- [Methods](#methods)
  - [connect](#connect)
  - [subscribe](#subscribe)
  - [unsubscribe](#unsubscribe)
  - [publish](#publish)
  - [start\_loop](#start_loop)

## Status

This library is now experimental. The most of the protocols in NATS core have been implemented.

## Installation

```shell
luarocks install https://raw.githubusercontent.com/bzp2010/lua-resty-nats-next/refs/heads/main/rockspec/lua-resty-nats-next-main-0.rockspec
```

## Synopsis

```nginx
http {
  lua_package_path "/path/to/lua-resty-nats-next/lib/?/init.lua;;";

  server {
    location / {
      content_by_lua_block {
        local cjson  = require("cjson.safe")
        local client = require("resty.nats.client")
        local cli, err = client.connect({
          host = "127.0.0.1",
          port = 4222,

          -- socket config
          timeout = 60000,
          keepalive_timeout = 600 * 1000,
          keepalive_size = 2,
          ssl = false,
          ssl_verify = true,
        })

        if not cli then
          ngx.log(ngx.INFO, "failed to connect to NATS server: ", err)
          return
        end

        cli:subscribe("foo.*", function(message)
          ngx.log(ngx.INFO, "Received message: ", cjson.encode(message))
        end)

        cli:start_loop()
      }
    }
  }
}
```

## Description

This module provides a completely non-blocking NATS client driven by the cosocket. As a more complete and modern implementation of the OpenResty NATS client, it is called `next`. It is the successor to some existing stale clients.

It can be used to support the following use cases:

1. Broadcasting message between Nginx workers or instances. For example, synchronizing health checker state in a local cluster.

2. Synchronizing real-time data between any workers. For example, to support real-time web applications where different clients can broadcast data to each other.

3. As a more lightweight alternative to Kafka, perform real-time message push via NATS/JetStream.

[Back to TOC](#table-of-contents)

## Methods

[Back to TOC](#table-of-contents)

### connect

**syntax:** *cli, err = client.connect(opts)*

**context:** *any applicable context for [ngx.socket.tcp](https://github.com/openresty/lua-nginx-module/?tab=readme-ov-file#ngxsockettcp)*

Return a new NATS client object.

The `opts` parameter is a Lua table with named options:

- `host`: (string) the hostname or IP of NATS server.
- `port`: (integer) the TCP port of NATS server.
- `auth_config`: (table, optional) the configuration of authentication, default `{}`. Created via the `resty.nats.auth` module.
- `timeout`: (integer, optional) the timeout of TCP connection, default `60000`(ms).
- `keepalive`: (boolean, optional) the flag for enabling connection pooling or not, default `true`. If you are mainly using the library's event loop to continuously receive message pushes, keepalive may not be necessary. A long connection that is not actively closed cannot be reclaimed by connection pooling and used for reuse.
- `keepalive_timeout`: (integer, optional) the maximum idle timeout for the connection. When the connection is not used again after keepalive_timeout milliseconds, the connection is closed. Default `600000`(ms).
- `keepalive_size`: (integer, optional) the size of connection pool, the maximum number of connections cached in a single connection pool, default `2`.
- `keepalive_pool`: (string, optional) the identifier of the connection pool, the same value will be treated as the same connection pool, default `<host>:<port>`. It is necessary to fine tune the settings as you can use different authentication methods to get different permissions on the NATS server.
- `ssl`: (boolean, optional) the flag for whether or not to use TLS to connect to the NATS server, default `false`. When the server requires mandatory TLS and this option is not turned on, the connection may not be established.
- `ssl_verify`: (boolean, optional) the flag of whether or not to verify the trusted server certificates, default `true`.

The return value will be the client object or `nil, err`.

[Back to TOC](#table-of-contents)

### subscribe

**syntax:** *ok, err = client:subscribe(subject, callback)*

**context:** *any applicable context for [ngx.socket.tcp](https://github.com/openresty/lua-nginx-module/?tab=readme-ov-file#ngxsockettcp)*

The `subject` parameter conforms to the [NATS definition of subject syntax](https://docs.nats.io/reference/reference-protocols/nats-protocol#protocol-conventions).

The `callback` parameter is a function that conforms to the prototype of `function (message)`. See the [`start_loop`](#start_loop) section below for the structure of the message.

The return value will be `ok, err`.

```lua
local ok, err = cli:subscribe("foo.*", function(message)
  ngx.log(ngx.INFO, "Received message: ", message.payload or "empty payload")
end)

if not ok then
  ngx.log(ngx.ERR, err)
end
```

[Back to TOC](#table-of-contents)

### unsubscribe

**syntax:** *ok, err = client:unsubscribe(subject)*

**context:** *any applicable context for [ngx.socket.tcp](https://github.com/openresty/lua-nginx-module/?tab=readme-ov-file#ngxsockettcp)*

The `subject` parameter conforms to the [NATS definition of subject syntax](https://docs.nats.io/reference/reference-protocols/nats-protocol#protocol-conventions).

If a subject has not been subscribed to, the function will return an error.

The return value will be `ok, err`.

```lua
local ok, err = cli:unsubscribe("foo.*")

if not ok then
  ngx.log(ngx.ERR, err)
end
```

[Back to TOC](#table-of-contents)

### publish

**syntax:** *ok, err = client:publish(opts)*

**context:** *any applicable context for [ngx.socket.tcp](https://github.com/openresty/lua-nginx-module/?tab=readme-ov-file#ngxsockettcp)*

The `opts` parameter is a Lua table with named options:

- `subject`, (string) the exact subject to publish to.
- `reply_to`, (string, optional) the exact subject to which the response is required, default `nil`.
- `payload`, (string, optional) the payload to publish, default empty string.

The return value will be `ok, err`.

```lua
local ok, err = cli:publish({ subject = "foo.bar", payload = "Hello World!"})

if not ok then
  ngx.log(ngx.ERR, err)
end
```

[Back to TOC](#table-of-contents)

### start_loop

**syntax:** *cli, err = client:start_loop()*

**context:** *any applicable context for [ngx.socket.tcp](https://github.com/openresty/lua-nginx-module/?tab=readme-ov-file#ngxsockettcp)*

Starts the receive loop, and when the NATS server pushes any message, the client calls the relevant subscribe callback and delivers the received message.

This function behaves in a blocking manner for the current execution flow, and internally uses a loop to process each incoming TCP packet.
However, it is actually driven by a cosocket and does not block the Nginx worker.

Specifically, this loop is now concerned with 3 kinds of server messages:

1. `PING`: this loop will automatically reply with a PONG without user intervention. At the same time this means that if the client does not use `start_loop` but instead uses a short conncetion to publish somethings, it must be very fast, otherwise the ping timer on the server-side will close the connection.

2. `MSG`: the subscription callback will be called with a Lua table resulting from the parsing of the current message without headers. Format:

    ```json5
    {
      "subject": "foo.bar", // The exact subject of the received message, useful when subscribing with wildcards and needing to distinguish between sources.
      "reply_to": "bar.foo",
      "payload": "Hello World!"
    }
    ```

3. `HMSG`: the subscription callback will be called with a Lua table resulting from the parsing of the current message with headers. Format:

    ```json5
    {
      "subject": "foo.bar",
      "reply_to": "bar.foo",
      "payload": "Hello World!",
      "headers": {
        "key1": "value1",
        "key2": "value2"
      }
    }
    ```

[Back to TOC](#table-of-contents)
