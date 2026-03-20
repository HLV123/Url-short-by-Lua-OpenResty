local cjson = require "cjson"
local storage = require "common.storage"

local links = storage.get_links()

ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode(links or {}))
