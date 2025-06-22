local cjson = require("cjson.safe")

local _M = {}


-- INFO {"option_name":option_value,...}␍␊
function _M.decode(line)
  return cjson.decode(line:sub(5))
end


return _M
