local _M = {}

-- Rate limit using ngx.shared.DICT
-- Returns true if allowed, false if rate limit exceeded
function _M.check(key, max_requests, window_seconds)
    local limit = ngx.shared.rate_limit
    local current = limit:get(key)

    if not current then
        limit:set(key, 1, window_seconds)
        return true, 1
    end

    if current >= max_requests then
        return false, current
    end

    local new_val = limit:incr(key, 1)
    return true, new_val
end

-- Rate limit for link creation: 10/min per IP
function _M.check_shorten(ip)
    return _M.check("shorten:" .. ip, 10, 60)
end

-- Rate limit for redirect: 1000/hour per short link
function _M.check_redirect(code)
    return _M.check("redirect:" .. code, 1000, 3600)
end

return _M
