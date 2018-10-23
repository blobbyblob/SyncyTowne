--[[

Any hash function should be implemented in here.
	
There is currently only one implementation, and it just returns the length of the string. This is really weak and quite possible to accidentally cause collisions, but it should still capture the majority of differences in script sources.

--]]

local module = {};

function module.Hash(str)
	return tostring(string.len(str));
end

return module;
