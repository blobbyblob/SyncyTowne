local __help = [[

An abstract type which helps create restrictions for position/size of objects.

Properties:
	Enabled (boolean) = true: true if this should modify the size/position of
		the parent.
	Order (number) = 1: the order in which this modifier will considered with
		respect to other modifiers.
Methods:
	tuple<pos, size> _ConvertCoordinates(position, size, origPos, origSize):
		converts a position and size given by Vector2 into a position and size
		which observe the limitations of this placement modifier. Position and
		size are the coordinates after having been corrected by modifiers; 
		originalPosition and originalSize are the coordinates before any
		modifier transformations have occurred.
	size _ConvertMinimumSize(size): returns the minimum size required assuming
		this modifier is used.
]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

function IS_GUI_TYPE(v)
	return type(v)=='table' and v:IsA("GuiBase2d");
end

local Debug = Utils.new("Log", "Modifier: ", true);

local Super = Gui.Instance;
local Modifier = Utils.new("Class", "Modifier", Super);

Modifier._Enabled = true;
Modifier._Order = 1;

function Modifier.Set:Enabled(v)
	self._Enabled = v;
	if self._Parent and self._Parent._TriggerReflow then
		self._Parent:_TriggerReflow();
	end
end
function Modifier.Set:Order(v)
	self._Order = v;
	if self._Parent and self._Parent._TriggerReflow then
		self._Parent:_TriggerReflow();
	end
end

Modifier.Get.Enabled = "_Enabled";
Modifier.Get.Order = "_Order";

function Modifier:_ConvertCoordinates(pos, size, origPos, origSize)
	Utils.Log.Error("_ConvertCoordinates not implemented for %s", self.ClassName);
end

function Modifier.new()
	local self = setmetatable(Super.new(), Modifier.Meta);
	return self;
end

return Modifier;
