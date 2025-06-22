local re_match = ngx.re.match
local REGEX_MSG = [[^MSG\s+([^\s]+)\s+([^\s]+)\s+(?:([^\s]+)\s+)?(\d+)]]

local _M = {}


-- MSG <subject> <sid> [reply-to] <#bytes>␍␊[payload]␍␊
function _M.decode(line)
  local m, err = re_match(line, REGEX_MSG, "ijos")
  if not m then
    return nil, "failed to decode message: " .. (err or "unknown error")
  end

  return {
    subject = m[1],
    sid = m[2],
    reply_to = m[3] or nil, -- optional
    size = tonumber(m[4]),
  }
end


return _M
