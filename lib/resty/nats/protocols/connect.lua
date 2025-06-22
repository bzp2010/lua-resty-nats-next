local cjson = require("cjson.safe")

local _M = {}


-- CONNECT {"option_name":option_value,...}␍␊
function _M.encode(opts)
  return "CONNECT " .. cjson.encode(opts)
end


return _M
