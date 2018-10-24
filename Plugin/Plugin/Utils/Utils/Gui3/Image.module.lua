local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Image: ", true);

local Super = Gui.GuiBase2d;
local Image = Utils.new("Class", "Image", Super);

Image._Frame = false;
Image._Image = "rbxassetid://133293265";
Image._Color = Color3.fromRGB(255, 255, 255)
Image._Transparency = 0;

function Image.Set:Color(v)
	self._Color = v;
	self._Frame.ImageColor3 = v;
end
function Image.Set:Image(v)
	self._Image = v;
	self._Frame.Image = v;
end
function Image.Set:Transparency(v)
	self._Transparency = v;
	self._Frame.ImageTransparency = v;
end
Image.Get.Color = "_Color";
Image.Get.Image = "_Image";
Image.Get.Transparency = "_Transparency";

function Image:_Clone(new)
	new.Color = self.Color;
	new.Image = self.Image;
	new.Transparency = self.Transparency;
end

function Image:_GetRbxHandle()
	return self._Frame;
end

function Image.new()
	local self = setmetatable(Super.new(), Image.Meta);
	self._Frame = Instance.new("ImageLabel");
	self._Frame.BackgroundTransparency = 1;
	self.Color = self.Color;
	self.Image = self.Image;
	self.Transparency = self.Transparency;
	return self;
end

function Gui.Test.Image_Default(sgui)
	local r = Image.new();
	r.Parent = sgui;
end

function Gui.Test.Image_Basic(sgui)
	local r = Image.new();
	r.Parent = sgui;
	r.Color = Color3.new(1, 0, 0);
	r.Image = "rbxassetid://590092584";
	r.Transparency = .5;
	r.Size = UDim2.new(0, 200, 0, 200);
	r.Position = UDim2.new(.5, -100, .5, -100);
	Utils.Log.AssertEqual("r.Color", Color3.new(1, 0, 0), r.Color);
	Utils.Log.AssertEqual("r.Image", "rbxassetid://590092584", r.Image);
	Utils.Log.AssertEqual("r.Transparency", 0.5, r.Transparency);
	Utils.Log.AssertEqual("r.Color", Color3.new(1, 0, 0), r._Frame.ImageColor3);
	Utils.Log.AssertEqual("r.Image", "rbxassetid://590092584", r._Frame.Image);
	Utils.Log.AssertEqual("r.Transparency", 0.5, r._Frame.ImageTransparency);
end

return Image;
