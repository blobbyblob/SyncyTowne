--[[

Wraps a table so it can be read, but not written to.

Constructor:
	new(table): creates a read-only wrapper around 'table'.
Methods:
	pairs(): iterates through all keys in the underlying table.
	ipairs(): iterates through numerical keys in the underlying table.
	next(index): returns the index following the given argument in the underlying table.

__index & __len work as expected.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local TableAssociations = setmetatable({}, {__mode="k"});

local ReadOnlyWrapper = Utils.new("Class", "ReadOnlyWrapper");

function ReadOnlyWrapper:__index(i)
	return TableAssociations[self][i];
end
function ReadOnlyWrapper:__newindex(i, v)
	Log.Error("Cannot write to table %s", TableAssociations[self]);
end
function ReadOnlyWrapper:pairs()
	return pairs(TableAssociations[self]);
end
function ReadOnlyWrapper:ipairs()
	return ipairs(TableAssociations[self]);
end
function ReadOnlyWrapper:next(i)
	return next(TableAssociations[self], i);
end
function ReadOnlyWrapper:__len()
	return #TableAssociations[self];
end

function ReadOnlyWrapper.new(t)
	local self = newproxy(true);
	local mt = getmetatable(self);
	for i, v in pairs(ReadOnlyWrapper.Meta) do
		mt[i] = v;
	end
	TableAssociations[self] = t;
	return self;
end

return ReadOnlyWrapper;


