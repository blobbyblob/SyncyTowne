local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "SliceFrame: ", true);

local Super = Gui.GuiBase2d;
local SliceFrame = Utils.new("Class", "SliceFrame", Super);

SliceFrame._Frame = false;
SliceFrame._Image = "rbxassetid://330349492";
SliceFrame._Color = Color3.fromRGB(255, 255, 255)
SliceFrame._Transparency = 0;
SliceFrame._SliceCenter = Rect.new(Vector2.new(4, 4), Vector2.new(6, 6));

function SliceFrame.Set:Color(v)
	self._Color = v;
	self._Frame.ImageColor3 = v;
end
function SliceFrame.Set:Image(v)
	self._Image = v;
	self._Frame.Image = v;
end
function SliceFrame.Set:Transparency(v)
	self._Transparency = v;
	self._Frame.ImageTransparency = v;
end
function SliceFrame.Set:SliceCenter(v)
	self._SliceCenter = v;
	self._Frame.SliceCenter = v;
end
SliceFrame.Get.Color = "_Color";
SliceFrame.Get.Image = "_Image";
SliceFrame.Get.Transparency = "_Transparency";
SliceFrame.Get.SliceCenter = "_SliceCenter";

function SliceFrame:_Clone(new)
	new.Color = self.Color;
	new.Image = self.Image;
	new.Transparency = self.Transparency;
	new.SliceCenter = self.SliceCenter;
end

function SliceFrame:_GetRbxHandle()
	return self._Frame;
end

function SliceFrame.new()
	local self = setmetatable(Super.new(), SliceFrame.Meta);
	self._Frame = Instance.new("ImageLabel");
	self._Frame.BackgroundTransparency = 1;
	self._Frame.ScaleType = Enum.ScaleType.Slice;
	self.Color = self.Color;
	self.Image = self.Image;
	self.Transparency = self.Transparency;
	self.SliceCenter = self.SliceCenter;
	return self;
end

function Gui.Test.SliceFrame_Default(sgui)
	local r = SliceFrame.new();
	r.Parent = sgui;
end

function Gui.Test.SliceFrame_Basic(sgui)
	local g = Utils.Gui.new("Rectangle");
	g.Size = UDim2.new(0, 200, 0, 200);
	g.Position = UDim2.new(.5, -100, .5, -100);
	g.Parent = sgui;
	g.Color = Color3.fromRGB(128, 255, 64);
	local r = SliceFrame.new();
	r.Parent = g;
	r.Color = Color3.fromRGB(240, 240, 240);
	r.Image = "rbxassetid://330349492";
	r.SliceCenter = Rect.new(Vector2.new(4, 4), Vector2.new(6, 6));
	r.Transparency = .125;
	Utils.Log.AssertEqual("r.Color", Color3.fromRGB(240, 240, 240), r.Color);
	Utils.Log.AssertEqual("r.Image", "rbxassetid://330349492", r.Image);
	Utils.Log.AssertEqual("r.SliceCenter", Rect.new(Vector2.new(4, 4), Vector2.new(6, 6)), r.SliceCenter);
	Utils.Log.AssertEqual("r.Transparency", 0.125, r.Transparency);

	Utils.Log.AssertEqual("r.Color", Color3.fromRGB(240, 240, 240), r._Frame.ImageColor3);
	Utils.Log.AssertEqual("r.Image", "rbxassetid://330349492", r._Frame.Image);
	Utils.Log.AssertEqual("r.SliceCenter", Rect.new(Vector2.new(4, 4), Vector2.new(6, 6)), r._Frame.SliceCenter);
	Utils.Log.AssertEqual("r.Transparency", 0.125, r._Frame.ImageTransparency);
end

return SliceFrame;
