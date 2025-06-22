local _M = {}


function _M.new_user_pass(user, pass)
  return {
    user = user or "",
    pass = pass or "",
  }
end


function _M.new_token(token)
  return {
    auth_token = token or "",
  }
end


return _M
