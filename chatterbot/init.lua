
local setmetatable, table_insert, table_concat, math_random, ipairs, require,
      io_open, print, pairs, os_date =
      setmetatable, table.insert, table.concat, math.random, ipairs, require,
      io.open, print, pairs, os.date

module "chatterbot"

local marshal = require "marshal"

local bot = { }

local bot_meta = { __index=bot }

local function find(tbl, item)
	for i, v in ipairs(tbl) do
		if v == item then return i end
	end
end

function bot:feed(text)
	self:log("Feeding; Source: %q", text)
	local words = { }
	for word in text:gmatch("%w+") do
		table_insert(words, word:lower())
	end
	local i = 1
	while i <= #words - 2 do
		local k = words[i].." "..words[i+1]
		local w = words[i+2]
		local t = self.known[k]
		if not t then
			t = { }
			self.known[k] = t
			table_insert(self.known_keys, k)
			self:log("Inserted key %q.", k)
		end
		if not find(t, w) then
			table_insert(self.known[k], w)
			self:log("Inserted value %q to key %q.", w, k)
		end
		i = i + 1
	end
	self:log("Inserted %d words.", #words)
end

local function randitem(list)
	return list[math_random(1, #list)]
end

function bot:think(key)
	if #self.known_keys == 0 then return end
	local words = { }
	if key then
		key = key:lower()
	else
		key = randitem(self.known_keys)
	end
	table_insert(words, key)
	while self.known[key] do
		local list = self.known[key]
		local word = randitem(list)
		table_insert(words, word)
		local key_word2 = key:match("%w+ (%w+)")
		key = key_word2.." "..word
		if #words >= 10 then break end
	end
	return table_concat(words, " ")
end

local function exists(filename)
	local f = io_open(filename)
	if f then
		f:close()
	end
	return f ~= nil
end

function bot:save_cache(filename, backup)
	filename = filename or "cache.txt"
	backup = backup or filename..".bak"
	if exists(filename) then
		local n = 1
		while exists(backup) do
			local s = ("%03d"):format(n)
			backup = backup:sub(1, -2):gsub("(.*)%..*", "%1."..s)
			n = n + 1
		end
		self:log("Saving cache backup from %q to %q.", filename, backup)
		local fb = io_open(backup, "w")
		if not fb then
			self:log("Warning: Cannot save backup. Aborting cache save.")
			return
		end
		local ff = io_open(filename)
		fb:write(ff:read("*a"))
		ff:close()
		fb:close()
	end
	self:log("Saving cache to %q.")
	local cache = marshal.serialize(self.known)
	if not cache then
		self:log("Error serializing cache.")
		return
	end
	local f = io_open(filename, "wt")
	if not f then
		self:log("Error opening cache for writing: "..e)
		return
	end
	local r = f:write(cache)
	if not r then
		self:log("Error writing cache.")
	end
	f:close()
	return r
end

function bot:load_cache(file)
	filename = filename or "cache.txt"
	self:log("Loading cache from %q", filename)
	local f, e = io_open(filename)
	if not f then
		self:log("Error opening cache for reading: "..e)
		return
	end
	local cache = marshal.deserialize(f:read("*a"))
	f:close()
	if not cache then
		self:log("Error deserializing cache.")
		return
	end
	self.known = cache
	self.known_keys = { }
	for k, v in pairs(cache) do
		self:log("Inserting key %q", k)
		table_insert(self.known_keys, k)
	end
	self:log("Loaded OK!")
	return true
end

function bot:log(fmt, ...)
	local s = fmt:format(...)
	if self.logfile then
		self.logfile:write(s)
		self.logfile:write("\n")
	end
	print(s)
end

function new(params)
	params = params or { }
	local inst = setmetatable({
		known = { },
		known_keys = { },
	}, bot_meta)
	if params.logfile then
		inst.logfile = io_open(params.logfile, "at")
		inst:log("=== Log started at %s ===", os_date())
	end
	return inst
end
