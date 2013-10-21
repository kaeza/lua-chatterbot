
package.path = table.concat({
	"./?/init.lua",
	"./?.lua",
	package.path,
}, ";")

package.cpath = table.concat({
	"./lib?.so",
	"./?.dll",
	package.cpath,
}, ";")

local function error(text)
	print("Error: "..text)
	os.exit(1)
end

local chatterbot = require "chatterbot"
local ircbot = require "chatterbot.ircbot"

local config = require "config"
local time = require "time"

local conf = config.new()
local r, e = conf:load("chatterbot.conf")
if not r then
	error("Couldn't load configuration: "..e)
end

local log_file = conf:get("log_file")

local cb = chatterbot.new({logfile=log_file})

cb:load_cache()

local nick = conf:get("nick", "blarghbot")
local owner = conf:get("owner")
local admins = conf:get("admins", "")

local admin_list = { }
for who in admins:gmatch("%S+") do
	admin_list[admin] = true
end

if #admin_list == 0 then admin_list = nil end

local ib = ircbot.new(cb, {
	nick = nick,
	owner = owner,
	admin_list = admin_list
})

local network = conf:get("network") or error("No network specified.")
local port = conf:get_number("port", 6667)

ib:connect({
	host = network,
	port = port,
})

local channels = conf:get("channels") or error("No channels specified.")

for channel in channels:gmatch("%S+") do
	ib:join(channel)
end

math.randomseed(os.time())

while getmetatable(ib.conn) do
	--local ok = pcall(function()
	time.usleep(1000)
	ib.conn:think()
	--end)
	--if not ok then break end
end
