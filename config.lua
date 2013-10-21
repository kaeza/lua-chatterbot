
local setmetatable, tostring, tonumber, io_open, pairs, print =
      setmetatable, tostring, tonumber, io.open, pairs, print

module "config"

local conf = { }
local conf_meta = { __index=conf }

function conf:set(name, v)
	if v == nil then
		self._vars[name] = nil
	else
		self._vars[name] = tostring(v)
	end
end

function conf:set_number(name, v)
	v = tonumber(v)
	if not v then return end
	self:set(name, v)
end

function conf:set_bool(name, v)
	self:set(name, v and "true" or "false")
end

function conf:get(name, def)
	if not (self.vars and  self._vars[name]) then return def end
	local v = self._vars[name]
	if v == "" then return def end
	return v
end

function conf:get_number(name, def)
	local v self:get(name)
	return v and tonumber(v) or def
end

local is_true = {
	["true"] = true, ["t"]  = true, ["1"]       = true, ["y"] = true,
	["yes"]  = true, ["on"] = true, ["enabled"] = true,
}

local is_false = {
	["false"] = true, ["f"]   = true, ["0"]        = true, ["n"] = true,
	["no"]    = true, ["off"] = true, ["disabled"] = true,
}

function conf:get_bool(name, def)
	local v = self:get(name)
	if not v then return def end
	v = v:lower()
	if is_true[v] then
		return true
	elseif is_false[v] then
		return false
	else
		return def
	end
end

function conf:save(filename)
	local f, e = io_open(filename, "wt")
	if not f then return false, e end
	for k, v in pairs(self._vars) do
		f:write(("%s = %s\n"):format(k, v))
	end
	f:close()
	return true
end

function conf:load(filename)
	local f, e = io_open(filename, "rt")
	if not f then return false, e end
	for line in f:lines() do
		line = line:gsub("^%s+", "")
		if line:sub(1, 1) ~= "#" then
			local k, v = line:match("([^=]+)=(.*)")
			if k and v then
				k = k:gsub("^%s*(.-)%s*$", "%1")
				v = v:gsub("^%s*", "")
				print(("Adding key=%q, value=%q"):format(k, v))
				self._vars[k] = v
			end
		end
	end
	f:close()
	return true
end

function conf:clear()
	self._vars = { }
end

function conf:vars()
	
end

function new()
	local inst = setmetatable({ }, conf_meta)
	inst._vars = { }
	return inst
end
