--[[

A Bars object displays bars across the screen. It can also place text between each bar or below each bar.

Properties:
	BarHeights (array<number>) = {.25, .75, 1, .5}: the height of each bar.
	Labels (array<string>) = {}: the text to display below each bar.
	LabelsBetweenBars (boolean) = false: when true, labels will be placed between bars instead of below.
	LabelHeight (number) = 12: the number of pixels to provide for the label.

Specialized Layout Spec:
	Role "Label": this will be copied for each label below the bar.
	Role "Bar": this will be copied for each bar.

--]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Bars: ", true);

local BARS_SCHEMA = {
	Label = {
		Type = "Many";
		LayoutParams = { SetText = function(obj, text) end };
		Default = Gui.Create "Text" {
			LayoutParams = { SetText = function(obj, text) obj.Text = text; end };
			Gravity = "Center";
			Color = Utils.Math.HexColor(0xFFFFFF);
			StrokeColor = Utils.Math.HexColor(0);
			StrokeTransparency = 0;
		};
		ParentName = "_Frame";
	};
	Bar = {
		Type = "Many";
		LayoutParams = {};
		Default = Gui.Create "Rectangle" {
			Color = Utils.Math.HexColor(0xEEEEEE);
			Gui.Create "Border" {
				Width = 2;
				Color = Utils.Math.HexColor(0);
			};
		};
		ParentName = "_Frame";
	};
};

local Super = Gui.SpecializedLayout;
local Bars = Utils.new("Class", "Bars", Super);

Bars._Frame = false;
Bars._Cxns = false;
Bars._Events = false;

Bars._BarHeights = {.25, .75, 1, .5};
Bars._Labels = {};
Bars._LabelsBetweenBars = false;
Bars._LabelHeight = 14;

function Bars.Set:BarHeights(v)
	self._BarHeights = v;
	self._ChildParameters:SetRoleCount("Bar", #self._BarHeights);
	self._ChildParameters:SetRoleCount("Label", #self._BarHeights + (self._LabelsBetweenBars and 1 or 0));
	self:_TriggerReflow();
end
function Bars.Set:LabelsBetweenBars(v)
	self._LabelsBetweenBars = v;
	self._ChildParameters:SetRoleCount("Bar", #self._BarHeights);
	self._ChildParameters:SetRoleCount("Label", #self._BarHeights + (self._LabelsBetweenBars and 1 or 0));
	self:_TriggerReflow();
end
function Bars.Set:Labels(v)
	self._Labels = v;
	self:_TriggerReflow();
end
function Bars.Set:LabelHeight(v)
	self._LabelHeight = v;
	self:_TriggerReflow();
end
Bars.Get.BarHeights = "_BarHeights";
Bars.Get.LabelsBetweenBars = "_LabelsBetweenBars";
Bars.Get.Labels = "_Labels";
Bars.Get.LabelHeight = "_LabelHeight";

function Bars:_Clone(new)
	new.BarHeights = self.BarHeights;
	new.LabelsBetweenBars = self.LabelsBetweenBars;
	new.Labels = self.Labels;
	new.LabelHeight = self.LabelHeight;
end

function Bars:_GetRbxHandle()
	return self._Frame;
end

function Bars:_Reflow()
	local pos, size = Super._Reflow(self, true);
	local width = self._Frame.AbsoluteSize.x;
	local n = #self._BarHeights;
	local o = 0;
	local p = 1 / n;
	if self._LabelsBetweenBars then
		n = n + 1;
		p = 1 / n;
		o = p / 2;
	end
	for i = 1, #self._BarHeights do
		local left  = math.floor(width * (o + (i - 1) / n));
		local right = math.floor(width * (o + (i - 0) / n));
		local v = self._BarHeights[i];
		local V = 1 - v;
		local bar, barSchema = self._ChildParameters:GetChildOfRole("Bar", i);
		bar._Size = UDim2.new(0, right - left, v, -self._LabelHeight * v);
		bar._Position = UDim2.new(--[[o + (i - 1) * p]]0, left, V, -self._LabelHeight * V);
	end
	for i = 1, n do
		local v = self._Labels[i] or "";
		local label, labelSchema = self._ChildParameters:GetChildOfRole("Label", i);
		label._Size = UDim2.new(p, 0, 0, self._LabelHeight);
		label._Position = UDim2.new((i - 1) * p, 0, 1, -self._LabelHeight);
		labelSchema.SetText(label, v);
	end
end

function Bars.new()
	local self = setmetatable(Super.new(), Bars.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.BackgroundTransparency = 1;
	self._Cxns = Utils.new("ConnectionHolder");
	self._ChildParameters.Schema = BARS_SCHEMA;
	self._ChildParameters:SetRoleCount("Bar", #self._BarHeights);
	self._ChildParameters:SetRoleCount("Label", #self._BarHeights + (self._LabelsBetweenBars and 1 or 0));
	return self;
end

function Gui.Test.Bars_Default(sgui, cgui)
	local r = Bars.new();
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Parent = sgui;
	r.Labels = {"A", "B", "C", "D"};
end

function Gui.Test.Bars_LabelsBetween(sgui, cgui)
	local r = Bars.new();
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Parent = sgui;
	r.LabelsBetweenBars = true;
	r.Labels = {"0", "1", "2", "3", "4"};
end

function Gui.Test.Bars_CustomFeatures(sgui, cgui)
	local b = Utils.new("Benchmarker");
	b:Mark("Constructing");
	local r = Bars.new();
	b:Mark("Configuring");
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Parent = sgui;
	r.Labels = {"A", "B", "C", "D"};
	b:End();
end

return Bars;
