local _M = {}


-- SUB <subject> [queue group] <sid>␍␊
function _M.encode(opts)
  local queue_group = opts and opts.queue_group and (opts.queue_group .. " ") or ""
  return "SUB " .. opts.subject .. " " .. queue_group .. opts.sid
end


return _M
