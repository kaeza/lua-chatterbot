
local type, tostring, error, pairs, table_insert, table_concat, pcall, setfenv,
      loadstring =
      type, tostring, error, pairs, table.insert, table.concat, pcall, setfenv,
      loadstring

module "marshal"

local function repr(x)
	local t = type(x)
	if x == nil then
		return "nil"
	elseif t == "string" then
		return ("%q"):format(x)
	elseif (t == "number") or (t == "boolean") then
		return tostring(x)
	elseif t == "string" then
		return ("%q"):format(x)
	else
		error(("unsupported type: %s"):format(t))
	end
end

local function do_serialize(t)
	local out = { "{" }
	for k, v in pairs(t) do
		k = repr(k)
		if type(v) == "table" then
			v = do_serialize(v)
		else
			v = repr(v)
		end
		table_insert(out, ("[%s] = %s,"):format(k, v))
	end
	table_insert(out, "}")
	return table_concat(out, " ")
end

function serialize(t)

	return "return "..do_serialize(t)

end

function deserialize(s)
	local f = function() return setfenv(loadstring(s), {})() end
	local ok, t = pcall(f)
	if not ok then return nil, t end
	return t
end

local t = { 0, 1, 2, a=1, b=nil, c={3,4},}
local s = serialize(t)
