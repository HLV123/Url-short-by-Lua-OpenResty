local cjson = require "cjson"
local storage = require "common.storage"
local rate_limit = require "common.rate_limit"
local geo = require "common.geo"

local code = ngx.var.code
if not code or code == "" then
    ngx.status = 404
    ngx.say("Not Found")
    return
end

-- Get link info (cached)
local links = storage.get_links()
if not links[code] then
    ngx.status = 404
    ngx.header["Content-Type"] = "text/html"
    ngx.say([[
    <!DOCTYPE html>
    <html><head><title>404 - Not Found</title>
    <style>body{font-family:Inter,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#F8F9FC;}
    .c{text-align:center}.h{font-size:72px;color:#1B1F3B;font-weight:800}p{color:#6B7280}a{color:#EE6123}</style></head>
    <body><div class="c"><div class="h">404</div><p>Link không tồn tại</p><a href="/">← Về trang chủ</a></div></body></html>
    ]])
    return
end

local link = links[code]

-- Check expiry
if link.expiry and link.expiry ~= cjson.null then
    if ngx.time() > link.expiry then
        ngx.status = 410
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({ error = "Link đã hết hạn." }))
        return
    end
end

-- Rate limit check
local allowed, count = rate_limit.check_redirect(code)
if not allowed then
    ngx.status = 429
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ error = "Rate limit exceeded." }))
    return
end

-- Collect click data (use X-Forwarded-For from ngrok if present)
local xff = ngx.var.http_x_forwarded_for
local ip = xff and xff:match("^([^,]+)") or ngx.var.remote_addr
local ua = ngx.var.http_user_agent or ""
local referer = ngx.var.http_referer or ""

-- Device detection via UA pattern matching
local device = "desktop"
if ua:lower():match("bot") or ua:lower():match("crawler") or ua:lower():match("spider") then
    device = "bot"
elseif ua:lower():match("ipad") or ua:lower():match("tablet") or ua:lower():match("kindle") then
    device = "tablet"
elseif ua:lower():match("iphone") or ua:lower():match("android") or ua:lower():match("mobile") then
    device = "mobile"
end

-- Geo-IP lookup
local country = geo.lookup(ip)

-- Record click directly (timer unreliable on Windows)
local click_record = {
    code = code,
    ip = ip,
    ua = ua,
    device = device,
    referer = referer,
    country = country,
    time = ngx.time()
}

storage.append_click(click_record)
storage.increment_clicks(code)

-- 301 Redirect
ngx.status = 301
ngx.header["Location"] = link.url
ngx.header["Cache-Control"] = "no-cache"
