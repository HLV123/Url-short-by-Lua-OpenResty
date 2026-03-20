local _M = {}

local geo_cache = ngx.shared.geo_cache
local geo_data = nil -- loaded lazily

-- Convert IP to integer for binary search
function _M.ip_to_int(ip)
    local parts = {}
    for part in ip:gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(part)
    end
    if #parts ~= 4 then return 0 end
    return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
end

-- Load CSV data (lazy load, once)
function _M.load_data()
    if geo_data then return end

    local DATA_DIR = os.getenv("DATA_DIR") or "./data"
    local path = DATA_DIR .. "/ip2location-lite.csv"
    local f = io.open(path, "r")
    if not f then
        ngx.log(ngx.WARN, "IP2Location CSV not found: " .. path)
        geo_data = {}
        return
    end

    geo_data = {}
    local count = 0
    for line in f:lines() do
        -- CSV format: "ip_from","ip_to","country_code","country_name"
        local from_str, to_str, cc = line:match('"(%d+)","(%d+)","([^"]*)"')
        if from_str and to_str and cc and cc ~= "-" then
            count = count + 1
            geo_data[count] = {
                from = tonumber(from_str),
                to = tonumber(to_str),
                cc = cc
            }
        end
    end
    f:close()
    ngx.log(ngx.INFO, "Loaded " .. count .. " geo records")
end

-- Binary search for country code
function _M.lookup(ip)
    -- Check cache first
    local cached = geo_cache:get(ip)
    if cached then return cached end

    _M.load_data()
    if not geo_data or #geo_data == 0 then return "??" end

    local ip_int = _M.ip_to_int(ip)
    if ip_int == 0 then return "??" end

    local lo, hi = 1, #geo_data
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local entry = geo_data[mid]
        if ip_int < entry.from then
            hi = mid - 1
        elseif ip_int > entry.to then
            lo = mid + 1
        else
            -- Cache permanently (static data)
            geo_cache:set(ip, entry.cc)
            return entry.cc
        end
    end

    geo_cache:set(ip, "??")
    return "??"
end

return _M
