local cjson = require "cjson"
local _M = {}

local DATA_DIR = package.loaded["data_dir"] or os.getenv("DATA_DIR") or "D:/Project/URL-TRACKER/data"

-- Atomic read JSON file
function _M.read_json(filename)
    local path = DATA_DIR .. "/" .. filename
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(cjson.decode, content)
    if not ok then return nil end
    return data
end

-- Atomic write JSON file (write to tmp, then rename)
function _M.write_json(filename, data)
    local path = DATA_DIR .. "/" .. filename
    local tmp_path = path .. ".tmp"
    local content = cjson.encode(data)

    local f = io.open(tmp_path, "w")
    if not f then
        ngx.log(ngx.ERR, "Cannot open file for writing: " .. tmp_path)
        return false
    end
    f:write(content)
    f:close()

    -- Windows: os.rename fails if destination exists, must remove first
    os.remove(path)

    local ok, err = os.rename(tmp_path, path)
    if not ok then
        ngx.log(ngx.ERR, "Cannot rename file: " .. tmp_path .. " -> " .. path .. ": " .. tostring(err))
        os.remove(tmp_path)
        return false
    end
    return true
end

-- Append to clicks.json array
function _M.append_click(click_record)
    local mutex = ngx.shared.mutex
    local lock_key = "clicks_lock"

    -- Simple spinlock using shared dict
    local max_wait = 50 -- 50 attempts * 10ms = 500ms max
    for i = 1, max_wait do
        local ok = mutex:add(lock_key, true, 2) -- 2s TTL
        if ok then
            -- Got lock
            local clicks = _M.read_json("clicks.json") or {}
            table.insert(clicks, click_record)
            _M.write_json("clicks.json", clicks)
            mutex:delete(lock_key)
            return true
        end
        ngx.sleep(0.01)
    end

    ngx.log(ngx.ERR, "Failed to acquire lock for clicks.json")
    return false
end

-- Update link stats (increment total_clicks)
function _M.increment_clicks(code)
    local mutex = ngx.shared.mutex
    local lock_key = "links_lock"

    for i = 1, 50 do
        local ok = mutex:add(lock_key, true, 2)
        if ok then
            local links = _M.read_json("links.json") or {}
            if links[code] then
                links[code].total_clicks = (links[code].total_clicks or 0) + 1
                _M.write_json("links.json", links)
            end
            mutex:delete(lock_key)
            return true
        end
        ngx.sleep(0.01)
    end
    return false
end

-- Get links with cache
function _M.get_links()
    local cache = ngx.shared.url_cache
    local cached = cache:get("links")
    if cached then
        return cjson.decode(cached)
    end

    local links = _M.read_json("links.json") or {}
    cache:set("links", cjson.encode(links), 5) -- 5s TTL
    return links
end

-- Get clicks with cache
function _M.get_clicks()
    local cache = ngx.shared.stats_cache
    local cached = cache:get("clicks")
    if cached then
        return cjson.decode(cached)
    end

    local clicks = _M.read_json("clicks.json") or {}
    cache:set("clicks", cjson.encode(clicks), 5) -- 5s TTL
    return clicks
end

return _M
