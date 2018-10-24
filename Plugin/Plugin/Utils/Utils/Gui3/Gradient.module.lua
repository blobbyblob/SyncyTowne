local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Gradient: ", true);

local Super = Gui.GuiBase2d;
local Gradient = Utils.new("Class", "Gradient", Super);

Gui.Enum:newEnumClass("GradientDirection", "Horizontal", "Vertical");

local GRADIENT_IMAGES = {
	[Gui.Enum.GradientDirection.Horizontal] = "rbxassetid://700063511";
	[Gui.Enum.GradientDirection.Vertical] = "rbxassetid://700063695";
};

Gradient._Frame = false;
Gradient._Direction = Gui.Enum.GradientDirection.Horizontal;
Gradient._Color1 = Color3.fromRGB(153, 218, 255)
Gradient._Color2 = Color3.new(0, .5, .5);

function Gradient.Set:Color1(v)
	self._Color1 = v;
	self._Frame.ImageColor3 = v;
end
function Gradient.Set:Color2(v)
	self._Color2 = v;
	self._Frame.BackgroundColor3 = v;
end
function Gradient.Set:Direction(v)
	v = Gui.Enum.GradientDirection:InterpretEnum("Direction", v);
	self._Direction = v;
	self._Frame.Image = GRADIENT_IMAGES[v];
end
Gradient.Get.Color1 = "_Color1";
Gradient.Get.Color2 = "_Color2";
Gradient.Get.Direction = "_Direction";

function Gradient:_Clone(new)
	new.Color1 = self.Color1;
	new.Color2 = self.Color2;
	new.Direction = self.Direction;
end

function Gradient:_GetRbxHandle()
	return self._Frame;
end

function Gradient.new()
	local self = setmetatable(Super.new(), Gradient.Meta);
	self._Frame = Instance.new("ImageLabel");
	self._Frame.BorderSizePixel = 0;
	self.Color1 = self.Color1;
	self.Color2 = self.Color2;
	self.Direction = self.Direction;
	return self;
end

function Gui.Test.Gradient_Default(sgui)
	local r = Gradient.new();
	r.Parent = sgui;
end

function Gui.Test.Gradient_Basic(sgui)
	local r = Gradient.new();
	r.Parent = sgui;
	r.Color1 = Color3.new(1, 0, 0);
	r.Color2 = Color3.new(0, 1, 0);
	r.Direction = "Vertical";
	r.Size = UDim2.new(0, 200, 0, 200);
	r.Position = UDim2.new(.5, -100, .5, -100);
end

return Gradient;
