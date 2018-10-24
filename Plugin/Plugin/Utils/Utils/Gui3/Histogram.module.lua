--[[

A Histogram object utilizes the "Bars" object to draw a histogram.

Properties:
	Values (array<number>) = {}: an array of values to collect.
	Bars (number) = 4: the number of bars to display.
	Min (number) = 0: the lowest bucket value to use.
	Max (number) = 100: the highest bucket value to use.
	LabelHeight (number) = 12: the number of pixels to provide for the label.

Specialized Layout Spec:
	Role "Label": this will be copied for each label below the bar.
	Role "Bar": this will be copied for each bar.

--]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Histogram: ", true);

local Super = Gui.Bars;
local Histogram = Utils.new("Class", "Histogram", Super);

Histogram._Values = {};
Histogram._Bars = 4;
Histogram._Min = 0;
Histogram._Max = 100;

Histogram._Recompute = false;

function Histogram.Set:Values(v)
	self._Values = v;
	self._Recompute = true;
	self:_TriggerReflow();
end
function Histogram.Set:Min(v)
	self._Min = v;
	self._Recompute = true;
	self:_TriggerReflow();
end
function Histogram.Set:Max(v)
	self._Max = v;
	self._Recompute = true;
	self:_TriggerReflow();
end
function Histogram.Set:Bars(v)
	self._Bars = v;
	self._Recompute = true;
	self:_TriggerReflow();
end
Histogram.Get.Values = "_Values";
Histogram.Get.Min = "_Min";
Histogram.Get.Max = "_Max";
Histogram.Get.Bars = "_Bars";

function Histogram:_Reflow()
	if self._Recompute then
		self._Recompute = false;
		local bucketRange = (self._Max - self._Min) / self._Bars;
		local min = self._Min - bucketRange;
		local values = self._Values;
		local buckets = {};
		for i = 1, self._Bars do
			buckets[i] = 0;
		end
		for i = 1, #values do
			local v = math.floor((values[i] - min) / bucketRange);
			if v >= 1 and v <= #buckets then
				buckets[v] = buckets[v] + 1;
			end
		end
		local largest = math.max(unpack(buckets));
		if largest > 0 then
			for i = 1, #buckets do
				buckets[i] = buckets[i] / largest;
			end
		end
		self.BarHeights = buckets;
		local labels = {};
		for i = 1, self._Bars + 1 do
			labels[i] = tostring(Utils.Math.Round(min + bucketRange * i, .01));
		end
		self.Labels = labels;
	end
	return Super._Reflow(self);
end

function Histogram:_Clone(new)
	new.Values = self.Values;
	new.Bars = self.Bars;
	new.Min = self.Min;
	new.Max = self.Max;
end

--function Histogram:_AddChild(child)
--	self.Bars:_AddChild(child);
--end
--function Histogram:_RemoveChild(child)
--	self.Bars:_RemoveChild(child);
--end

function Histogram.new()
	local self = setmetatable(Super.new(), Histogram.Meta);
	self.LabelsBetweenBars = true;
	return self;
end

function Gui.Test.Histogram_Example(sgui, cgui)
	local r = Histogram.new();
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Parent = sgui;
	r.Values = {35, 50, 60, 65, 72, 75, 74, 77, 77, 78, 83, 84, 82, 86, 88, 90, 94};
	r.Bars = 10;
end

function Gui.Test.Histogram_Clone(sgui, cgui)
	local r = Histogram.new();
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Values = {35, 50, 60, 65, 72, 75, 74, 77, 77, 78, 83, 84, 82, 86, 88, 90, 94};
	r.Bars = 10;
	r:Clone().Parent = sgui;
end

function Gui.Test.Histogram_Custom(sgui, cgui)
	local r = Histogram.new();
	r.Size = UDim2.new(0, 300, 0, 240);
	r.Position = UDim2.new(.5, -150, .5, -120);
	r.Parent = sgui;
	r.Values = {35, 50, 60, 65, 72, 75, 74, 77, 77, 78, 83, 84, 82, 86, 88, 90, 94};
	r.Bars = 10;
	wait(1);
	local b = Gui.Create "Rectangle" {
		Name = "Friendly Neighborhood Rectangle";
		LayoutParams = {Role = "Bar"};
		Color = Utils.Math.HexColor(0xEE0000);
	};
	b.Parent = r;
end

return Histogram;
