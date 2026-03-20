local cjson = require "cjson"
local storage = require "common.storage"
local rate_limit = require "common.rate_limit"

-- Read request body
ngx.req.read_body()
local body = ngx.req.get_body_data()
if not body then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "Missing request body." }))
    return
end

local ok, req = pcall(cjson.decode, body)
if not ok or not req.url then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "Invalid JSON. Required field: url" }))
    return
end

-- Validate URL
local url = req.url
if not url:match("^https?://") then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "URL must start with http:// or https://" }))
    return
end

-- Rate limit check (use real IP behind ngrok)
local xff = ngx.var.http_x_forwarded_for
local ip = xff and xff:match("^([^,]+)") or ngx.var.remote_addr
local allowed, count = rate_limit.check_shorten(ip)
if not allowed then
    ngx.status = 429
    ngx.say(cjson.encode({ error = "Rate limit exceeded. Max 10 links per minute." }))
    return
end

-- Generate or validate code
local code = nil
if req.alias and req.alias ~= "" then
    -- Custom alias validation
    local alias = req.alias
    if not alias:match("^[a-zA-Z0-9_%-]+$") then
        ngx.status = 400
        ngx.say(cjson.encode({ error = "Alias chỉ chấp nhận a-z, A-Z, 0-9, -, _" }))
        return
    end
    if #alias < 3 or #alias > 20 then
        ngx.status = 400
        ngx.say(cjson.encode({ error = "Alias phải từ 3-20 ký tự." }))
        return
    end
    code = alias
else
    -- Generate random 6-char code
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    math.randomseed(ngx.now() * 1000 + ngx.worker.pid())
    local result = {}
    for i = 1, 6 do
        local idx = math.random(1, #chars)
        result[i] = chars:sub(idx, idx)
    end
    code = table.concat(result)
end

-- Check if code already exists
local links = storage.read_json("links.json") or {}
if links[code] then
    ngx.status = 409
    ngx.say(cjson.encode({ error = "Alias '" .. code .. "' already exists." }))
    return
end

-- Save new link
local now = ngx.time()
links[code] = {
    url = url,
    alias = req.alias or cjson.null,
    created = now,
    total_clicks = 0,
    expiry = cjson.null,
    password_hash = cjson.null
}

local write_ok = storage.write_json("links.json", links)
if not write_ok then
    ngx.status = 500
    ngx.say(cjson.encode({ error = "Failed to save link." }))
    return
end

-- Invalidate cache
ngx.shared.url_cache:delete("links")

-- Build short URL (supports ngrok X-Forwarded headers)
local scheme = ngx.var.http_x_forwarded_proto or ngx.var.scheme or "http"
local host = ngx.var.http_x_forwarded_host or ngx.var.http_host or ngx.var.host
local short_url = scheme .. "://" .. host .. "/" .. code

ngx.status = 200
ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode({
    code = code,
    short_url = short_url,
    created = now
}))
