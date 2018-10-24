--[[

When warping a constraint body, every piece has to move, otherwise
we're left with parts that are trying to catch up.

--]]

local Utils = require(script.Parent.Parent);

local RealFunction = Utils.Math.CFrameGroupRelative;

return function(...)
	Utils.Log.Warn("Utils.Misc.CFrameConstraintBody is deprecated in favor of Utils.Math.CFrameGroupRelative");
	RealFunction(...);
end;
