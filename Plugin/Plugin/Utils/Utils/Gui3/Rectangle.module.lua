local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Rectangle: ", true);

local Super = Gui.GuiBase2d;
local Rectangle = Utils.new("Class", "Rectangle", Super);

Rectangle._Frame = false;
Rectangle._Color = Color3.new(.8, .8, .8);

function Rectangle.Set:Color(v)
	self._Color = v;
	self._Frame.BackgroundColor3 = v;
end
Rectangle.Get.Color = "_Color";

function Rectangle.Set:Name(v)
	Super.Set.Name(self, v);
	self._Frame.Name = v;
end

function Rectangle:_Clone(new)
	new.Color = self.Color;
end

function Rectangle:_GetRbxHandle()
	return self._Frame;
end

function Rectangle.new()
	local self = setmetatable(Super.new(), Rectangle.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.BorderSizePixel = 0;
	self._Frame.BackgroundColor3 = self._Color;
	return self;
end

function Gui.Test.Rectangle_Basic(sgui)
	local r = Rectangle.new();
	r.Parent = sgui;
end

return Rectangle;
