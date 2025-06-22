local re_match = ngx.re.match
local REGEX_MSG = [[^-ERR\s+'([^']+)']]

local _M = {}


-- -ERR <error message>␍␊
function _M.decode(line)
  local ctx = {}
  local m, err = re_match(line, REGEX_MSG, "ijos", ctx)
  if not m then
    return nil, "failed to decode message: " .. (err or "unknown error")
  end

  return {
    payload = m[1] or "client unknown error",
    pos = ctx.pos,
  }
end


return _M
