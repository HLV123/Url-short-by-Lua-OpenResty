local cjson = require "cjson"
local storage = require "common.storage"

local code = ngx.var.code
if not code or code == "" then
    ngx.status = 400
    ngx.say("Missing code parameter")
    return
end

-- Check if link exists
local links = storage.get_links()
if not links[code] then
    ngx.status = 404
    ngx.say("Link not found")
    return
end

-- Get clicks
local all_clicks = storage.read_json("clicks.json") or {}
local clicks = {}
for _, click in ipairs(all_clicks) do
    if click.code == code then
        clicks[#clicks + 1] = click
    end
end

-- Set CSV headers
ngx.header["Content-Type"] = "text/csv; charset=utf-8"
ngx.header["Content-Disposition"] = 'attachment; filename="clicks_' .. code .. '.csv"'

-- CSV header
ngx.say("code,ip,country,device,ua,referer,time")

-- CSV rows
for _, click in ipairs(clicks) do
    local row = string.format('%s,%s,%s,%s,"%s","%s",%d',
        click.code or "",
        click.ip or "",
        click.country or "",
        click.device or "",
        (click.ua or ""):gsub('"', '""'),
        (click.referer or ""):gsub('"', '""'),
        click.time or 0
    )
    ngx.say(row)
end
