local _M = {}


-- UNSUB <sid> [max_msgs]␍␊
function _M.encode(opts)
  local max_msgs = opts.max_msgs and (" " .. opts.max_msgs) or ""
  return "UNSUB " .. opts.sid .. max_msgs
end


return _M
