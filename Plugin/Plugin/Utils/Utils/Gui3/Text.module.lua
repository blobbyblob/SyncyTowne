local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Text: ", false);

local Super = Gui.GuiBase2d;
local Text = Utils.new("Class", "Text", Super);

Text._Frame = false;
Text._Text = "Label";
Text._Color = Color3.fromRGB(0, 0, 0)
Text._Scaled = false;
Text._Transparency = 0;
Text._StrokeColor = Color3.new(1, 1, 1);
Text._Font = Enum.Font.Legacy;
Text._FontSize = 10;
Text._Gravity = Gui.Enum.Gravity.TopLeft;
Text._Wrapped = false;
Text._StrokeTransparency = 1;

local PROPERTIES = {
	{"Text", "_Text", "Text"};
	{"Color", "_Color", "TextColor3"};
	{"Scaled", "_Scaled", "TextScaled"};
	{"Transparency", "_Transparency", "TextTransparency"};
	{"StrokeColor", "_StrokeColor", "TextStrokeColor3"};
	{"Font", "_Font", "Font"};
	{"FontSize", "_FontSize", "TextSize"};
	{"Wrapped", "_Wrapped", "TextWrapped"};
	{"StrokeTransparency", "_StrokeTransparency", "TextStrokeTransparency"};
};
for i, v in pairs(PROPERTIES) do
	local publicName, privateName, underlyingName = unpack(v);
	Text.Set[publicName] = function(self, v)
		Debug("%s.%s = %s; Translating to %s.%s = %s", self, publicName, v, self._Frame, underlyingName, v);
		self[privateName] = v;
		self._Frame[underlyingName] = v;
	end
	Text.Get[publicName] = privateName;
end
function Text.Set:Gravity(v)
	v = Gui.Enum.Gravity:InterpretEnum("Gravity", v);
	self._Gravity = v;
	local x = (v.Value - 1) % 3;
	local y = math.floor((v.Value - 1) / 3);
	self._Frame.TextXAlignment = x==0 and Enum.TextXAlignment.Left or (x==1 and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right);
	self._Frame.TextYAlignment = y==0 and Enum.TextYAlignment.Top or (y==1 and Enum.TextYAlignment.Center or Enum.TextYAlignment.Bottom);
end
Text.Get.Gravity = "_Gravity";

function Text:_Clone(new)
	new.Text = self.Text;
	new.Color = self.Color;
	new.Transparency = self.Transparency;
	new.StrokeColor = self.StrokeColor;
	new.Font = self.Font;
	new.Wrapped = self.Wrapped;
	new.FontSize = self.FontSize;
	new.Scaled = self.Scaled;
	new.StrokeTransparency = self.StrokeTransparency;
	new.Gravity = self.Gravity;
end

function Text:_GetRbxHandle()
	return self._Frame;
end

function Text.new()
	local self = setmetatable(Super.new(), Text.Meta);
	self._Frame = Instance.new("TextLabel");
	self._Frame.BackgroundTransparency = 1;
	self:_Clone(self);
	return self;
end

function Gui.Test.Text_Default(sgui)
	local r = Text.new();
	r.Parent = sgui;
end

function Gui.Test.Text_Basic(sgui)
	local r = Text.new();

	r.Color = Color3.new(1, 1, 1);
	r.Text = "Hello, World!";
	r.Scaled = true;
	r.Transparency = .125;
	r.StrokeColor = Color3.new(.75, 1, 0);
	r.Font = Enum.Font.Code;
--	r.FontSize = 16;
	r.Gravity = Gui.Enum.Gravity.Center;
--	r.Wrapped = false;
	r.StrokeTransparency = 0;

	r.Parent = sgui;
	Utils.Log.AssertEqual("r.Color", Color3.new(1, 1, 1), r.Color);
	Utils.Log.AssertEqual("r.Text", "Hello, World!", r.Text);
	Utils.Log.AssertEqual("r.Transparency", .125, r.Transparency);
	Utils.Log.AssertEqual("r.Color", Color3.new(1, 1, 1), r._Frame.TextColor3);
	Utils.Log.AssertEqual("r.Text", "Hello, World!", r._Frame.Text);
	Utils.Log.AssertEqual("r.Transparency", 0.125, r._Frame.TextTransparency);
end

function Gui.Test.Text_Clone(sgui)
	local r = Text.new();
	r.Text = "a";
	r.Color = Color3.new(1, 0, 0);
	r.Scaled = true;
	r.Gravity = Gui.Enum.Gravity.Left;
	local s = r:Clone();
	s.Gravity = Gui.Enum.Gravity.Right;
	r.Name = "Original";
	r.Parent = sgui;
	s.Name = "Clone";
	s.Parent = sgui;
end

return Text;
