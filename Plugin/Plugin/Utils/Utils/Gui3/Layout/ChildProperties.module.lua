local Utils = require(script.Parent.Parent.Parent);
local Debug = Utils.new("Log", "ChildProperties: ", false);

local ChildParameters = Utils.new("Class", "ChildParameters");

ChildParameters._Defaults = false;
ChildParameters._Parameters = false;
ChildParameters._Cache = false;

function ChildParameters.Set:Cache(v)
	Utils.Log.AssertNonNilAndType("Cache", "boolean", v);
	self._Cache = v;
	if not v then
		for i, v in pairs(self) do
			if ChildParameters[i] == nil then
				self[i] = nil;
			end
		end
	end
end
ChildParameters.Get.Cache = "_Cache";

--[[ @brief Returns a table with all child parameters defined.
     @details All parameters defined by child.LayoutParams will be given. Any undefined keys will be replaced by a default.
--]]
function ChildParameters:__index(child)
	Debug("Getting ChildProperties for %s", child);
	local t = {};
	local s;
	if child and type(child) == 'table' then s = child.LayoutParams; end
	local u = self._Parameters[child];
	for i, v in pairs(self._Defaults) do
		if u and u[i]~=nil then
			Debug("Sourcing %s from internal table (%s)", i, u[i]);
			t[i] = u[i];
		elseif s and s[i]~=nil then
			Debug("Sourcing %s from user table (%s)", i, s[i]);
			t[i] = s[i];
		else
			Debug("Sourcing %s from defaults (%s)", i, v);
			t[i] = v;
		end
	end
	if self._Cache then
		rawset(self, child, t);
	end
	return t;
end

--[[ @brief Returns a table for a child which is writable
--]]
function ChildParameters:GetWritableParameters(child)
	self._Parameters[child] = self._Parameters[child] or {};
	return self._Parameters[child];
end

--[[ @brief Registers a default value for a given key.
     @param key The key to register for.
     @param value The value to register.
--]]
function ChildParameters:SetDefault(key, value)
	self._Defaults[key] = value;
end

function ChildParameters:Clone()
	local new = ChildParameters.new()
	for i, v in pairs(self._Defaults) do
		new:SetDefault(i, v);
	end
	for i, v in pairs(self._Parameters) do
		new._Parameters[i] = Utils.Table.ShallowCopy(v);
	end
end

--[[ @brief Instantiates a new ChildParameters object.
--]]
function ChildParameters.new()
	return setmetatable({_Defaults = {}, _Parameters = {}}, ChildParameters.Meta);
end

return ChildParameters;
