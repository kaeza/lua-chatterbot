
local require, setmetatable, print, pairs, ipairs, table_insert, table_concat,
      os_time =
      require, setmetatable, print, pairs, ipairs, table.insert, table.concat,
      os.time

module "chatterbot.ircbot"

local irc = require("irc")

local marshal = require("marshal")

local bot = { }

local bot_meta = {
	__index = function(self, k)
		local v = bot[k]
		if v == nil then v = self.bot[k] end
		return v
	end,
}

local function check_owner(self, nick, channel)
	if not (self.owner and (self.owner == nick)) then
		self.conn:sendChat(nick, "You are not my owner.")
		return
	end
	return true
end

local function check_admin(self, nick, channel)
	if not (self.owner and (self.owner == nick))
	 or    (self.admins and self.admins[nick]) then
		self.conn:sendChat(nick, "You are neither my owner nor my admin.")
		return
	end
	return true
end

local commands = { }

local function def_command(name, desc, params, func)
	commands[name] = {
		description = desc,
		params = params,
		func = func,
	}
end

def_command("quit", "Disconnect from network.", "",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	self.running = nil
	self.conn:disconnect()
end)

def_command("info", "Show information about me.", "",
function(self, user, channel, params)
	self:print("My owner is %s and my admins are %s. I have %d keys in my database.",
		self.owner or "no one",
		self.admins and table_concat(self.admins, ", ") or "no one",
		#self.known_keys
	)
end)

def_command("save", "Save database.", "",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	local status = self.bot:save_cache() and "Success!" or "An error occurred!"
	self:print(status)
end)

def_command("reload", "Reload database.", "",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	local status = self.bot:load_cache() and "Success!" or "An error occurred!"
	self:print(status)
end)

def_command("admin", "Manage administrators.", "{add|remove} NICKS...",
function(self, user, channel, params)
	if not check_owner(self, user.nick, channel) then return end
	local subcmd, args = params:match("(%S+)%s*(.*)")
	if subcmd then
		if subcmd == "add" then
			if not args then
				self:print("usage: admin add NICKS...")
				return
			end
			if not self.bot.admins then
				self.bot.admins = { }
			end
			for word in args:gmatch("%S+") do
				self.bot.admins[word] = true
			end
		elseif subcmd == "remove" then
			if not args then
				self:print("usage: admin remove NICKS...")
				return
			end
			if self.bot.admins then
				for word in args:gmatch("%S+") do
					self.bot.admins[word] = nil
				end
			end
		end
	else
		self:print("usage: admin {add|remove} NICKS...")
		return
	end
end)

def_command("join", "Join a channel", "CHANNEL",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	local chan = params:match("#.*")
	if chan then self.conn:join(chan) end
end)

def_command("part", "Part a given channel, or the current one.", "[CHANNEL]",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	if params == "" then params = channel end
	local chan = params:match("#.*")
	if chan then self.conn:part(chan) end
end)

def_command("talk", "Generate a phrase, optionally starting from a given key.", "[WORD1 WORD2]",
function(self, user, channel, params)
	local word1, word2 = params:match("(%w+)%s+(%w+)")
	local key
	if word1 and word2 then
		key = word1.." "..word2
		if not (self.bot.known and self.bot.known[key]) then
			self:print("I don't have key `%s' in my database.", key)
			return
		end
	elseif params ~= "" then
		self:print("usage: talk [WORD1 WORD2]")
		return
	end
	self:print(self.bot:think(key))
end)

def_command("ignore", "Ignore a nick.", "NICK",
function(self, user, channel, params)
	if not check_admin(self, user.nick, channel) then return end
	if params == "" then return end
	if not self.ignores then self.ignores = { } end
	self.ignores[params] = true
	self:print("Ignored `%s'.", params)
end)

def_command("unignore", "Unignore a nick.", "NICK",
function(self, user, channel, params)
	if params == "" then return end
	if not check_admin(self, user.nick, channel) then return end
	if not self.ignores then return end
	self.ignores[params] = nil
	self:print("Unignored `%s'.", params)
end)

def_command("forget", "Forget a given key.", "WORD1 WORD2",
function(self, user, channel, params)
	if self.ignores and self.ignores[user.nick] then return end
	if not check_admin(self, user.nick, channel) then return end
	local word1, word2 = params:match("(%w+)%s+(%w+)")
	if word1 and word2 then
		local key = word1.." "..word2
		if self.bot.known and self.bot.known[key] then
			local c = #self.bot.known[key]
			self.bot.known[key] = nil
			self:print("Deleted `%s' from database. Forgot %d values.", key, c)
		else
			self:print("I don't have key `%s' in my database.", key)
		end
	else
		self:print("usage: forget WORD1 WORD2")
	end
end)

local cmds
def_command("help", "Get help on a command, or a list of known commands.", "[COMMAND]",
function(self, user, channel, params)
	params = params:gsub("^%s*(.-)%s*$", "%1")
	if params ~= "" then
		if commands[params] then
			self:print("%s | usage: %s %s",
				commands[params].description,
				params,
				commands[params].params
			)
		else
			self:print("I don't know the command `%s'", cmd)
		end
	else
		if not cmds then
			cmds = { }
			for k in pairs(commands) do
				table_insert(cmds, k)
			end
		end
		self:print("Available commands: %s", table_concat(cmds, ", "))
	end
end)

local function on_command(self, user, channel, message)
	local cmd, params = message:match("(%w+)%s*(.*)")
	if cmd then
		if commands[cmd] then
			commands[cmd].func(self, user, channel, params)
		else
			self:print("I don't know the command `%s'", cmd)
		end
	else
		self:print("hm?")
	end
end

local function on_chat(self, user, channel, message)
	if self.ignores and self.ignores[user.nick] then return end
	if channel == self.nick then
		self.target = {
			usernick = user.nick,
		}
		on_command(self, user, channel, message)
	else
		self.target = {
			usernick = user.nick,
			channel = channel,
		}
		local to, msg = message:match("(%w+)[,:]%s*!(.*)")
		if to and (to == self.nick) then
			on_command(self, user, channel, msg)
		else
			self:feed(message)
		end
	end
	self.target = nil
end

local function bind(method, self)
	return function(...)
		return method(self, ...)
	end
end

function bot:connect(params)

	params = params or { }

	params.host = params.host or "irc.freenode.net"
	params.port = params.port or 6667

	self.conn:hook("OnChat", bind(on_chat, self))

	self.running = true

	return self.conn:connect(params)

end

function bot:join(channel)

	self.conn:join(channel)

end

function bot:print(fmt, ...)
	if not self.target then return end
	local s = fmt:format(...)
	if not self.print_lasttime then
		self.print_lasttime = { }
	end
	if not self.print_lasttime[":global"] then
		self.print_lasttime[":global"] = 0
	end
	local tm = os_time()
	local gdtime = tm - self.print_lasttime[":global"]
	if gdtime < 5 then return end
	self.print_lasttime[":global"] = tm
	--[[if self.target.channel then
		if not self.print_lasttime[self.target.usernick] then
			self.print_lasttime[self.target.usernick] = 0
		end
		local dtime = tm - self.print_lasttime[self.target.usernick]
		if dtime < 3 then
			self.conn:sendChat(self.target.usernick,
				("Don't spam the bot! Wait %d more seconds."):format(dtime + 1)
			)
			return
		end
		self.print_lasttime[self.target.usernick] = tm
		self.conn:sendChat(self.target.channel, self.target.usernick..": "..s)
	else]]
		self.conn:sendChat(self.target.usernick, s)
	--end
end

function new(botinst, params)

	local inst = setmetatable({ }, bot_meta)

	params = params or { }

	params.nick = params.nick or "blarghbot"
	params.username = params.username or params.nick
	params.realname = params.realname or params.nick

	inst.owner = params.owner
	inst.admins = params.admins

	inst.nick = params.nick

	inst.bot = botinst
	inst.conn = irc.new(params)

	inst.conn:hook("OnDisconnect", function()
		print("OnDisconnect: saving cache")
		botinst:save_cache()
	end)

	return inst

end
