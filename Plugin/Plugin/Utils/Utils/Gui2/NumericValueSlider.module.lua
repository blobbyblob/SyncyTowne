local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local View = require(script.Parent.View);
local Gui = _G[script.Parent];
local Test = Gui.Test;

local Debug = Gui.Log.Debug;

local NumericValueSlider = Utils.new("Class", "NumericValueSlider", View);
local Super = NumericValueSlider.Super;

-------------------
-- Properties --
-------------------
NumericValueSlider._Values = {0, 1};
NumericValueSlider._Value = 0;

NumericValueSlider._ValueMap = {};
NumericValueSlider._BaseSlider = false;
NumericValueSlider._ChangedCxn = false;
NumericValueSlider._ChildPlacements = false;

function NumericValueSlider.Set:Values(v)
	Log.AssertNonNilAndType("Values", "table", v);
	Log.Assert(#v >= 2, "NumericValueSlider.Values must contain at least 2 numbers.");
	--1. Guarantee v is in order.
	local t = Utils.Table.ShallowCopy(v);
	table.sort(t);
	self._Values = t;
	--2. Normalize all numbers (largest value is 1, lowest is 0).
	local s = Utils.Table.ShallowCopy(t);
	local min, max = s[1], s[#s];
	--3. Map new values to original values.
	self._ValueMap = {};
	for i, v in pairs(s) do
		local newValue = (v - min) / (max - min);
		self._ValueMap[newValue] = v;
		s[i] = newValue;
	end
	--4. Update BaseSlider so it recognizes the new notches.
	self._BaseSlider.NotchLocations = s;

	for i, v in pairs(self._BaseSlider._Notches) do
		v.BackgroundColor3 = Color3.new(1, 1, 1);
	end

	--Fire Changed
	self._Changed:Fire("Values");
end
NumericValueSlider.Get.Values = "_Values";

function NumericValueSlider.Set:Value(v)
	local nl = self._Values;
	local modified = (v - nl[1]) / (nl[#nl] - nl[1]);
	self._BaseSlider.Value = modified;
end
NumericValueSlider.Get.Value = "_Value";

----------------
-- Methods --
----------------
function NumericValueSlider:Destroy()
	self._BaseSlider:Destroy();
	self._ChangedCxn:disconnect();
	Super.Destroy(self);
end

----------------------------------------------
-- Required functions for wrapping --
----------------------------------------------

function NumericValueSlider.Set:Parent(v)
	self._BaseSlider.ParentNoNotify = v;
	Super.Set.Parent(self, v);
end
function NumericValueSlider.Set:ParentNoNotify(v)
	self._BaseSlider.ParentNoNotify = v;
	Super.Set.ParentNoNotify(self, v);
end

function NumericValueSlider:_GetHandle()
	return self._BaseSlider:_GetHandle();
end

function NumericValueSlider:_GetChildContainerRaw(child)
	return self._BaseSlider:_GetChildContainerRaw(child);
end
function NumericValueSlider:_GetChildContainer(child)
	return self._BaseSlider:_GetChildContainer(child);
end

function NumericValueSlider:_AddChild(child)
	self._ChildPlacements:AddChildTo(child, self._BaseSlider);
	Super._AddChild(self, child);
end
function NumericValueSlider:_RemoveChild(child)
	self._ChildPlacements:RemoveChild(child);
	Super._RemoveChild(self, child);
end

function NumericValueSlider:_ForceReflow()
	Super._ForceReflow(self);
	self._BaseSlider:_ForceReflow();
end
function NumericValueSlider:_Reflow(pos, size)
	self._BaseSlider:_SetPPos(pos);
	self._BaseSlider:_SetPSize(size);
end

function NumericValueSlider:Clone()
	local new = Super.Clone(self);
	new.Values = self.Values;
	return new;
end

function NumericValueSlider.new()
	local self = setmetatable(Super.new(), NumericValueSlider.Meta);
	self._ChildPlacements = Gui.ChildPlacements();
	self._BaseSlider = Gui.new("BaseSlider");
	self._BaseSlider.NotchLocations = self._Values;
	self._BaseSlider.BackgroundColor3 = Color3.new(1, 1, 1);
	self._BaseSlider._Frame.BackgroundColor3 = Color3.new(.1, .1, .1);
	self._BaseSlider._Frame.BorderSizePixel = 1;
	self._BaseSlider._Frame.BorderColor3 = Color3.new(1, 1, 1);
	self._BaseSlider._Slider.BackgroundColor3 = Color3.new(0, 0, 0);
	self._BaseSlider._Slider.BackgroundTransparency = 0;
	self._BaseSlider._Slider.Margin = 1;
	self._BaseSlider._Slider.BorderSizePixel = 1;
	self._BaseSlider._Slider.BorderColor3 = Color3.new(1, 1, 1);
	self._BaseSlider._Line.BackgroundColor3 = Color3.new(1, 1, 1);
	self._ChangedCxn = self._BaseSlider.Changed:connect(function(prop)
		if prop=="Value" then
			self._Value = self._ValueMap[self._BaseSlider.Value];
			self._Changed:Fire("Value");
		end
	end)
	function self._BaseSlider.Clamp(baseSlider, n)
		local nl = baseSlider.NotchLocations;
		local i = 1;
		while nl[i] and n > nl[i] do
			i = i + 1;
		end
		if not nl[i] then
			return nl[#nl];
		elseif i==1 then
			return nl[1];
		else
			local j = i - 1;
			if n - nl[j] > nl[i] - n then
				return nl[i];
			else
				return nl[j];
			end
		end
	end
	return self;
end

function Test.NumericValueSlider_Basic(sgui, cgui)
	local view = Gui.new("View", cgui);
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 400;
	view.MinimumY = 60;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local slider = Gui.new("NumericValueSlider", view);
	slider.Name = "Slider";
	slider.Values = {0, 1, 2, 4, 8};
	slider.Changed:connect(function(prop)
		Debug("slider.Changed(%s) called; Value: %s", prop, slider.Value);
	end)
	local startTime = tick();
	local RUNTIME, MIN, MAX = 1, 0, 8;
	while tick() - startTime < RUNTIME do
		slider.Value = MIN + (MAX - MIN) * math.min(1, math.max(0, (tick() - startTime) / RUNTIME));
		wait();
	end
end

return NumericValueSlider;
