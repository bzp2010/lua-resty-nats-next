local _M = {}


-- PUB <subject> [reply-to] <#bytes>␍␊[payload]␍␊
function _M.encode(opts)
  local reply_to = opts.reply_to and (opts.reply_to .. " ") or ""
  local payload_size = opts.payload and #opts.payload or 0
  return "PUB " .. opts.subject .. " " .. reply_to .. payload_size .. "\r\n" .. (opts.payload or "")
end


return _M
