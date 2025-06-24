package = "lua-resty-nats-next"
version = "main-0"
source = {
   url = "git+https://github.com/bzp2010/lua-resty-nats-next",
   tag = "main"
}
description = {
   homepage = "https://github.com/bzp2010/lua-resty-nats-next",
   license = "Apache License 2.0"
}
build = {
   type = "builtin",
   modules = {
      ["resty.nats.auth"] = "lib/resty/nats/auth.lua",
      ["resty.nats.client"] = "lib/resty/nats/client.lua",
      ["resty.nats.common"] = "lib/resty/nats/common.lua",
      ["resty.nats.protocols.connect"] = "lib/resty/nats/protocols/connect.lua",
      ["resty.nats.protocols.err"] = "lib/resty/nats/protocols/err.lua",
      ["resty.nats.protocols.hmsg"] = "lib/resty/nats/protocols/hmsg.lua",
      ["resty.nats.protocols.info"] = "lib/resty/nats/protocols/info.lua",
      ["resty.nats.protocols.msg"] = "lib/resty/nats/protocols/msg.lua",
      ["resty.nats.protocols.parser"] = "lib/resty/nats/protocols/parser.lua",
      ["resty.nats.protocols.pub"] = "lib/resty/nats/protocols/pub.lua",
      ["resty.nats.protocols.sub"] = "lib/resty/nats/protocols/sub.lua",
      ["resty.nats.protocols.unsub"] = "lib/resty/nats/protocols/unsub.lua",
   }
}
