--[[

This object is meant to take multiple APIs and fold them together into one table.

This is useful if you have several modules which provide useful functions but you don't
want them to be defined together (e.g., so you can pull out and plug new modules in).

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local LayeredTable = Utils.new("Class", "LayeredTable");

--The chain of API tables to search through.
LayeredTable._ReferenceList = false;

--[[ @brief Indicate that a given API should be used for the lookup.
     @param api The API to use.
     @details If LayeredTable:Method() is called, it will be identical to calling api:Method() with
         regard to the 'self' variable.
--]]
function LayeredTable:Register(api)
	table.insert(self._ReferenceList, api);
end

--[[ @brief Look for the element with the same name.
     @details The underlying tables will be searched sequentially for a table with index i.
         If one is found & it is a function, a variant of the function will be returned which allows
         calling LayeredTable:Method() as if you were calling the underlying table with the colon
         operator. If it is not a function, it will be returned as normal.
     @param i The index to search for.
--]]
function LayeredTable:__index(i)
	for _, v in pairs(self._ReferenceList) do
		local value = v[i];
		if value then
			local f = value;
			if type(value) == 'function' then
				f = function(s, ...)
					if self==s then
						return value(v, ...);
					else
						return value(s, ...);
					end
				end;
			end
			rawset(self, i, f);
		end
	end
	return rawget(self, i);
end

--[[ @brief Respond angrily if the user tries to write an index manually to this object.
--]]
function LayeredTable:__newindex(i, v)
	Log.Error("Indices cannot directly be set for a LayeredTable.");
end

--[[ @return A new LayeredTable with no underlying tables.
--]]
function LayeredTable.new()
	local self = setmetatable({}, LayeredTable.Meta);
	self._ReferenceList = {};
	return self;
end

function LayeredTable.test()
	local t = LayeredTable.new();
	local u;
	u = {
		method = function(self)
			Log.AssertEqual("self", u, self);
		end
	};
	t:Register(u);
	t:method();
end

return LayeredTable;

