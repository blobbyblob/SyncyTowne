local __help = [[

This object ensures its parent's size doesn't drop below some minimum value.

Properties:
	Size (Vector2) = <0, 0>: the minimum size the parent may have.

]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "MinimumSize: ", true);

local Super = Gui.Modifier;
local MinimumSize = Utils.new("Class", "MinimumSizeModifier", Super);

MinimumSize._Name = "MinimumSize";
MinimumSize.Name = "MinimumSize";
MinimumSize._Size = Vector2.new(0, 0);

function MinimumSize.Set:Size(v)
	self._Size = v;
	if self._Parent and self._Parent._TriggerReflow then
		self._Parent:_TriggerReflow();
	end
end
MinimumSize.Get.Size = "_Size";

function MinimumSize:_ConvertCoordinates(pos, size, origPos, origSize)
	local x = math.max(size.x, self._Size.x);
	local y = math.max(size.y, self._Size.y);
	return pos, Vector2.new(x, y);
end

function MinimumSize:_ConvertMinimumSize(size)
	local x = math.max(size.x, self._Size.x);
	local y = math.max(size.y, self._Size.y);
	return Vector2.new(x, y);
end

function MinimumSize.new()
	local self = setmetatable(Super.new(), MinimumSize.Meta);
	return self;
end

function Gui.Test.MinimumSize_Basic()
	local m = MinimumSize.new();
	m.Size = Vector3.new(100, 100);
	local pos, size = m:_ConvertCoordinates(Vector2.new(50, 50), Vector2.new(100, 100), Vector2.new(50, 50), Vector2.new(100, 100));
	Utils.Log.AssertEqual("Pos", Vector2.new(50, 50), pos);
	Utils.Log.AssertEqual("Size", Vector2.new(100, 100), size);
end

return MinimumSize;
