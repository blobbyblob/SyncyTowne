--[[


Properties:

Methods:

Constructors:
	new(array): creates a multi-set out of an array.

--]]

local Utils = require(script.Parent.Parent);
local Debug = Utils.new("Log", "MultiSet: ", true);

local MultiSet = Utils.new("Class", "MultiSet");

MultiSet._Contents = false;

function MultiSet:__tostring()
	local s = {};
	for obj, multi in pairs(self._Contents) do
		table.insert(s, string.format("%s (%d)", tostring(obj), multi));
	end
	return "{\n" .. table.concat(s, "\n") .. "\n}";
end

function MultiSet:__eq(other)
	--For every element in this set, make sure the other has the same number.
	for object, multiplicity in pairs(self._Contents) do
		if other._Contents[object] ~= multiplicity then
			return false;
		end
	end
	--For every element in the other set, make sure this has at least one.
	for object, multiplicity in pairs(other._Contents) do
		if not self._Contents[object] then
			return false;
		end
	end
	return true;
end

function MultiSet.new(arr)
	local self = setmetatable({}, MultiSet.Meta);
	self._Contents = {};
	for i, v in pairs(arr) do
		self._Contents[v] = (self._Contents[v] or 0) + 1;
	end
	return self;
end

return MultiSet;
