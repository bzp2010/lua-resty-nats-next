local re_match = ngx.re.match
local REGEX_HMSG = [[^HMSG\s+([^\s]+)\s+([^\s]+)\s+(?:([^\s]+)\s+)?(\d+)\s+(\d+)]]

local _M = {}


-- HMSG <subject> <sid> [reply-to] <#header bytes> <#total bytes>␍␊[headers]␍␊␍␊[payload]␍␊
function _M.decode(line)
  local m, err = re_match(line, REGEX_HMSG, "ijos")
  if not m then
    return nil, "failed to decode headers-message: " .. (err or "unknown error")
  end

  local headers_size = tonumber(m[4])
  return {
    subject = m[1],
    sid = m[2],
    reply_to = m[3] or nil, -- optional
    headers_size = headers_size,
    size = tonumber(m[5]) - headers_size,
  }
end

function _M.decode_headers(headers)
  local headers_table = {}

  local m, err = re_match(headers, [[^NATS/1\.0\r\n]], "jo")
  if not m then
    return nil, "invalid header block: " .. (err or "unknown error")
  end

  local iter, err = ngx.re.gmatch(headers, [[^\s*([^\s:]+)\s*:\s*(.*?)\r?$]], "joUm")
  if not iter then
    return nil, "header parsing error: " .. (err or "unknown")
  end

  for mm in iter do
    local key, val = mm[1], mm[2]
    if key and val then
      headers_table[key] = val
    end
  end

  return headers_table
end


return _M
