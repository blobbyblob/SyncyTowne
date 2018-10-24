local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

--[[ @brief Returns a function which returns true for the first n operations, false otherwise.
--]]
function WhileLoopLimiter(n, name)
	local i = n;
	return function()
		i = i - 1;
		if i <= 0 then
			Log.Warn("WhileLoopLimiter %s exceeded", name);
		end
		return i > 0;
	end
end

return WhileLoopLimiter;