local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Border: ", true);

local Super = Gui.GuiBase2d;
local Border = Utils.new("Class", "Border", Super);

Border._Frame = false;
Border._Frame1 = false;
Border._Frame2 = false;
Border._Frame3 = false;
Border._Frame4 = false;
Border._Width = 4;
Border._Color = Color3.fromRGB(255, 255, 255);

function Border.Set:Color(v)
	self._Color = v;
	self._Frame1.BackgroundColor3 = v;
	self._Frame2.BackgroundColor3 = v;
	self._Frame3.BackgroundColor3 = v;
	self._Frame4.BackgroundColor3 = v;
end
function Border.Set:Width(v)
	self._Width = v;
	self._Frame1.Size = UDim2.new(1, -v, 0, v);
	self._Frame2.Size = UDim2.new(0, v, 1, -v);
	self._Frame3.Size = UDim2.new(1, -v, 0, v);
	self._Frame4.Size = UDim2.new(0, v, 1, -v);
	self._Frame1.Position = UDim2.new(0, 0, 0, 0);
	self._Frame2.Position = UDim2.new(1, -v, 0, 0);
	self._Frame3.Position = UDim2.new(0, v, 1, -v);
	self._Frame4.Position = UDim2.new(0, 0, 0, v);
end
Border.Get.Color = "_Color";
Border.Get.Width = "_Width";

function Border:_Clone(new)
	new.Color = self.Color;
	new.Width = self.Width;
end

function Border:_GetRbxHandle()
	return self._Frame;
end

function Border.new()
	local self = setmetatable(Super.new(), Border.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.BackgroundTransparency = 1;
	self._Frame1 = Instance.new("ImageLabel", self._Frame);
	self._Frame1.BorderSizePixel = 0;
	self._Frame2 = Instance.new("ImageLabel", self._Frame);
	self._Frame2.BorderSizePixel = 0;
	self._Frame3 = Instance.new("ImageLabel", self._Frame);
	self._Frame3.BorderSizePixel = 0;
	self._Frame4 = Instance.new("ImageLabel", self._Frame);
	self._Frame4.BorderSizePixel = 0;
	self.Color = self.Color;
	self.Width = self.Width;
	return self;
end

function Gui.Test.Border_Default(sgui)
	local r = Border.new();
	r.Parent = sgui;
end

function Gui.Test.Border_Basic(sgui)
	local r = Border.new();
	r.Position = UDim2.new(0.25, 0, .25, 0);
	r.Size = UDim2.new(.5, 0, .5, 0);
	r.Color = Color3.new(1, 0, 0);
	r.Width = 10;
	r.Parent = sgui;
	Utils.Log.AssertEqual("Frame1.AbsoluteSize.y", 10, r._Frame1.AbsoluteSize.y);
	Utils.Log.AssertEqual("Frame2.AbsoluteSize.x", 10, r._Frame2.AbsoluteSize.x);
	Utils.Log.AssertEqual("Frame3.AbsoluteSize.y", 10, r._Frame3.AbsoluteSize.y);
	Utils.Log.AssertEqual("Frame4.AbsoluteSize.x", 10, r._Frame4.AbsoluteSize.x);
	Utils.Log.AssertEqual("Frame1.Color", Color3.new(1, 0, 0), r._Frame1.BackgroundColor3);
	Utils.Log.AssertEqual("Frame2.Color", Color3.new(1, 0, 0), r._Frame2.BackgroundColor3);
	Utils.Log.AssertEqual("Frame3.Color", Color3.new(1, 0, 0), r._Frame3.BackgroundColor3);
	Utils.Log.AssertEqual("Frame4.Color", Color3.new(1, 0, 0), r._Frame4.BackgroundColor3);
end

return Border;
