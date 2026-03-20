local cjson = require "cjson"

local code = ngx.var.arg_code
if not code or code == "" then
    ngx.status = 400
    ngx.say("Missing code parameter")
    return
end

-- SSE headers
ngx.header["Content-Type"] = "text/event-stream"
ngx.header["Cache-Control"] = "no-cache"
ngx.header["Connection"] = "keep-alive"
ngx.header["X-Accel-Buffering"] = "no"
ngx.header["Access-Control-Allow-Origin"] = "*"

ngx.flush(true)

-- Read clicks.json directly, retry on failure (Windows file lock)
local DATA_DIR = package.loaded["data_dir"] or os.getenv("DATA_DIR") or "D:/Project/URL-TRACKER/data"
local clicks_path = DATA_DIR .. "/clicks.json"

local function read_clicks()
    for attempt = 1, 3 do
        local f = io.open(clicks_path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            if content and content ~= "" then
                local ok, data = pcall(cjson.decode, content)
                if ok and type(data) == "table" then
                    return data
                end
            end
        end
        if attempt < 3 then
            ngx.sleep(0.05) -- wait 50ms before retry
        end
    end
    return {}
end

local last_count = 0
local timeout = 300
local start_time = ngx.now()
local last_heartbeat = ngx.now()

-- Get initial count so we don't replay old clicks
local all_clicks = read_clicks()
for _, click in ipairs(all_clicks) do
    if click.code == code then
        last_count = last_count + 1
    end
end

while true do
    if ngx.now() - start_time > timeout then
        ngx.say(": timeout")
        ngx.say("")
        ngx.flush(true)
        break
    end

    local clicks = read_clicks()
    local current_count = 0
    local new_clicks = {}

    for _, click in ipairs(clicks) do
        if click.code == code then
            current_count = current_count + 1
            if current_count > last_count then
                new_clicks[#new_clicks + 1] = click
            end
        end
    end

    for _, click in ipairs(new_clicks) do
        local data = cjson.encode({
            ip     = click.ip,
            country = click.country or "??",
            device  = click.device or "desktop",
            time    = click.time,
            referer = click.referer or ""
        })
        ngx.say("data: " .. data)
        ngx.say("")
        ngx.flush(true)
    end

    last_count = current_count

    if ngx.now() - last_heartbeat >= 15 then
        ngx.say(": heartbeat")
        ngx.say("")
        ngx.flush(true)
        last_heartbeat = ngx.now()
    end

    ngx.sleep(1)

    if ngx.worker.exiting() then break end
end
