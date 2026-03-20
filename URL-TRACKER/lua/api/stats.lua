local cjson = require "cjson"
local storage = require "common.storage"

local code = ngx.var.code
if not code or code == "" then
    ngx.status = 400
    ngx.say(cjson.encode({ error = "Missing code parameter." }))
    return
end

-- Check stats cache
local cache = ngx.shared.stats_cache
local cache_key = "stats:" .. code
local cached = cache:get(cache_key)
if cached then
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cached)
    return
end

-- Get link info
local links = storage.get_links()
if not links[code] then
    ngx.status = 404
    ngx.say(cjson.encode({ error = "Link not found." }))
    return
end

local link = links[code]

-- Get all clicks for this code
local all_clicks = storage.get_clicks()
local clicks = {}
for _, click in ipairs(all_clicks) do
    if click.code == code then
        clicks[#clicks + 1] = click
    end
end

-- Calculate stats
local total_clicks = #clicks
local unique_ips = {}
local unique_count = 0
local clicks_by_hour = {}
for i = 0, 23 do clicks_by_hour[i] = 0 end
local country_map = {}
local device_map = { mobile = 0, desktop = 0, tablet = 0, bot = 0 }
local referer_map = {}

for _, click in ipairs(clicks) do
    -- Unique IPs
    if not unique_ips[click.ip] then
        unique_ips[click.ip] = true
        unique_count = unique_count + 1
    end

    -- Clicks by hour
    local hour = tonumber(os.date("%H", click.time)) or 0
    clicks_by_hour[hour] = (clicks_by_hour[hour] or 0) + 1

    -- Countries
    local country = click.country or "??"
    country_map[country] = (country_map[country] or 0) + 1

    -- Devices
    local device = click.device or "desktop"
    device_map[device] = (device_map[device] or 0) + 1

    -- Referers
    local referer = click.referer or "direct"
    if referer == "" then referer = "direct" end
    -- Extract domain
    local domain = referer:match("https?://([^/]+)")
    if not domain then domain = referer end
    referer_map[domain] = (referer_map[domain] or 0) + 1
end

-- Convert clicks_by_hour to array
local hours_array = {}
for i = 0, 23 do
    hours_array[i + 1] = clicks_by_hour[i] or 0
end

-- Sort and build top countries
local countries_list = {}
for country, count in pairs(country_map) do
    countries_list[#countries_list + 1] = { country = country, clicks = count }
end
table.sort(countries_list, function(a, b) return a.clicks > b.clicks end)
-- Keep top 5
local top_countries = {}
for i = 1, math.min(5, #countries_list) do
    top_countries[i] = countries_list[i]
end

-- Sort and build top referers
local referers_list = {}
for referer, count in pairs(referer_map) do
    referers_list[#referers_list + 1] = { referer = referer, clicks = count }
end
table.sort(referers_list, function(a, b) return a.clicks > b.clicks end)
local top_referers = {}
for i = 1, math.min(5, #referers_list) do
    top_referers[i] = referers_list[i]
end

local result = {
    code = code,
    url = link.url,
    created = link.created,
    total_clicks = total_clicks,
    unique_ips = unique_count,
    clicks_by_hour = hours_array,
    top_countries = top_countries,
    device_breakdown = device_map,
    top_referers = top_referers
}

local json_result = cjson.encode(result)

-- Cache for 5 seconds
cache:set(cache_key, json_result, 5)

ngx.header["Content-Type"] = "application/json"
ngx.say(json_result)
