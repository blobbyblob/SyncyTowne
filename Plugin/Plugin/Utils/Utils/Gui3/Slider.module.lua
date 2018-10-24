local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);
local _ = Gui.LinearLayout; --We use Enum.Direction from LinearLayout.
local UIS = game:GetService("UserInputService");

local Debug = Utils.new("Log", "Slider: ", false);

local SLIDER_SCHEMA = {
	Handle = {
		Type = "Single";
		LayoutParams = {
			AspectRatio = 0;
			LinearSize = 0;
			Proportion = 0;
		};
		Default = Gui.Create "Rectangle" {
			LayoutParams = {AspectRatio = 0.5; LinearSize = 0;};
			Name = "Handle";
			Color = Utils.Math.HexColor(0xEAEBED);
			ZIndex = 4;
			Name = "DefaultSliderTick";
		};
		ParentName = "_Button";
	};
	Bar = {
		Type = "Single";
		LayoutParams = {
			StopPoint = "Inner"; --Inner, Middle, or Outer.
		};
		Default = Gui.Create "Rectangle" {
			Color = Utils.Math.HexColor(0x007090);
			ZIndex = 2;
			Name = "DefaultSliderBar";
			Size = UDim2.new(1, 0, 0, 2);
			Position = UDim2.new(0, 0, .5, -1);
		};
		ParentName = "_Button";
	};
	Tick = {
		Type = "Many";
		LayoutParams = {
			FormatIndex = function(obj, index, totalIndices) end;
		};
		Default = Gui.Create "Rectangle" {
			Color = Utils.Math.HexColor(0x007090);
			ZIndex = 3;
			Name = "DefaultSliderTick";
		};
		ParentName = "_Button";
	};
	Background = {
		Type = "Single";
		Default = Gui.Create "Rectangle" {
			Color = Utils.Math.HexColor(0x01A7C2);
			ZIndex = 1;
			Name = "DefaultSliderBackground";
		};
		LayoutParams = {};
		ParentName = "_Button";
	};
	DefaultRole = "Background";
};

local Super = Gui.SpecializedLayout;
local Slider = Utils.new("Class", "Slider", Super);

Slider._Value = 0;
Slider._Clamp = function(v) return v; end;
Slider._NextClamp = function(v, behind) return behind and math.floor(v*6-.01)/6 or math.ceil(v*6+.01)/6; end;
Slider._NotchLocations = {};
Slider._Direction = Gui.Enum.Direction.Horizontal;
Slider._Padding = Utils.new("Margin", 0);
Slider._SanitizeInput = true;
Slider._ClampOnDrag = true;

Slider._Button = false;
Slider._TravelPixels = 0;

Slider._LastSize = false;
Slider._LastPos = false;
Slider._NotchLocationsChanged = true;
Slider._BackgroundChanged = true;

function Slider.Set:Value(v)
	if self._SanitizeInput then
		self:_Sanitize(v);
	else
		if self._Value ~= v then
			self._Value = v;
			self:_TriggerReflow();
			self._EventLoader:FireEvent("Changed", "Value");
		end
	end
end
function Slider.Set:Clamp(f)
	self._Clamp = f;
	if self._SanitizeInput then
		self:_Sanitize();
	end
end
function Slider.Set:NotchLocations(t)
	self._NotchLocations = t;
	self._NotchLocationsChanged = true;
	self._ChildParameters:SetRoleCount("Tick", #self._NotchLocations);
	self:_TriggerReflow();
end
function Slider.Set:Direction(v)
	self._Direction = v;
	self:_TriggerReflow();
end
function Slider.Set:Padding(v)
	self._Padding = v;
	self:_TriggerReflow();
end
function Slider.Set:SanitizeInput(v)
	self._SanitizeInput = v;
	if self._SanitizeInput then
		self:_Sanitize();
	end
end
Slider.Set.ClampOnDrag = "_ClampOnDrag";
Slider.Set.NextClamp = "_NextClamp";

Slider.Get.Value = "_Value";
Slider.Get.Clamp = "_Clamp";
Slider.Get.NotchLocations = "_NotchLocations";
Slider.Get.Direction = "_Direction";
Slider.Get.Padding = "_Padding";
Slider.Get.SanitizeInput = "_SanitizeInput";
Slider.Get.ClampOnDrag = "_ClampOnDrag";
Slider.Get.NextClamp = "_NextClamp";

function Slider:_Sanitize(v)
	local original = self._Value;
	self._Value = self._Clamp(v or self._Value);
	if self._Value ~= original then
		self:_Reflow();
	end
end
function Slider:_Reflow()
	local pos, size = Super._Reflow(self, true);
	local coordinatesChanged = pos ~= self._LastPos or size ~= self._LastSize;
	self._LastPos = pos;
	self._LastSize = size;

	--Get the background and place it as pos, size.
	if self._BackgroundChanged then
		local bg = self._ChildParameters:GetChildOfRole("Background");
		bg._Size = size;
		bg._Position = pos;
		self._BackgroundChanged = false;
	end

	--Get the handle and determine its width.
	local handle, handleParams = self._ChildParameters:GetChildOfRole("Handle");
	local height = size.Y.Offset - self._Padding.Top - self._Padding.Bottom;
	local width = height * handleParams.AspectRatio + handleParams.LinearSize;

	--Get the amount of travel as total width minus padding minus handle width.
	local travel = size.X.Offset - width - self._Padding.Left - self._Padding.Right;
	width = width + travel * handleParams.Proportion;
	travel = travel * (1 - handleParams.Proportion);
	self._TravelPixels = travel;

	--Place the handle at padding + <travel> * self._Value with width as determined above.
	handle._Size = UDim2.new(0, width, 0, height);
	handle._Position = UDim2.new(0, self._Padding.Left + travel * self._Value, 0, self._Padding.Top);

	--Place the bar at padding plus <handle width>/2 and give it the total travel length of space.
	if coordinatesChanged then
		local bar, barParams = self._ChildParameters:GetChildOfRole("Bar");
		bar._Size = UDim2.new(0, travel, 0, height);
		bar._Position = UDim2.new(0, self._Padding.Left + width/2, 0, self._Padding.Top);
	end

	if self._NotchLocationsChanged or coordinatesChanged then
		self._NotchLocationsChanged = false;
		for i, v in pairs(self._NotchLocations) do
			local obj, params = self._ChildParameters:GetChildOfRole("Tick", i);
			params.FormatIndex(obj, i, #self._NotchLocations);
			obj._Size = UDim2.new(0, 2, 0, height);
			obj._Position = UDim2.new(0, self._Padding.Left + travel * v + width/2-1, 0, self._Padding.Top);
		end
	end

	return pos, size;
end

function Slider:_GetRbxHandle()
	return self._Button:_GetRbxHandle();
end

function Slider.new()
	local self = setmetatable(Super.new(), Slider.Meta);
	local function FlagChange(role)
		if role=="Tick" then
			self._NotchLocationsChanged = true;
		elseif role == "Background" then
			self._BackgroundChanged = true;
		end
		self:_ForceReflow();
	end
	self._ChildParameters.RoleSourceChanged:connect(FlagChange);
	self._ChildParameters.LayoutParamsChanged:connect(FlagChange);
	self._Button = Gui.new("Button");
	self._ChildParameters.Schema = SLIDER_SCHEMA;
	local function ValueAtMousePosition(pos)
		local handle = self._ChildParameters:GetChildOfRole("Handle");
		local absPos = Gui.RealAbsolutePosition(self._Button:_GetRbxHandle());
		local offset = (Vector2.new(pos.x, pos.y)
			- absPos
			- Vector2.new(self._Padding.Left, self._Padding.Top)
			- Vector2.new(handle._Size.X.Offset/2, handle._Size.Y.Offset/2))
			/ Vector2.new(self._TravelPixels, self._TravelPixels);
		return offset.x;
	end
	self._Button.Drag:connect(function(m, x, y)
		local v = ValueAtMousePosition(UIS:GetMouseLocation())
		Debug("Value: %.2f", v);
		if m == "Up" then
			local newValue = self._Clamp(math.clamp(v, 0, 1));
			if self._Value ~= newValue then
				self._Value = newValue;
				self:_ForceReflow();
				self._EventLoader:FireEvent("Changed", "Value");
			end
		elseif m == "Move" then
			local newValue = math.clamp(v, 0, 1);
			if self._ClampOnDrag then
				newValue = self._Clamp(newValue);
			end
			if self._Value ~= newValue then
				self._Value = newValue;
				self:_ForceReflow();
				self._EventLoader:FireEvent("Changed", "Value");
			end
		end
	end)
	self._Button.Scroll:connect(function(delta, x, y)
		Debug("Scroll: %s, <%s, %s>", delta, x, y);
		local n = math.clamp(self._NextClamp(self._Value, delta==-1), 0, 1);
		if self._Value ~= n then
			self._Value = n;
			self:_ForceReflow();
			self._EventLoader:FireEvent("Changed", "Value");
		end
	end);
	self._Button.Click1:connect(function(x, y)
		local handle, handleParams = self._ChildParameters:GetChildOfRole("Handle");
		local lower = handle.AbsolutePosition - self._Button.AbsolutePosition;
		local upper = lower + handle.AbsoluteSize;
		if x >= lower.x and y >= lower.y and x <= upper.x and y <= upper.y then
		else
			local v = ValueAtMousePosition(UIS:GetMouseLocation());
			local n = math.clamp(self._NextClamp(self._Value, v < self._Value), 0, 1);
			if self._Value ~= n then
				self._Value = n;
				self:_ForceReflow();
				self._EventLoader:FireEvent("Changed", "Value");
			end
		end
	end)
	return self;
end

function Gui.Test.Slider_Default(sgui, cgui)
	local r = Gui.new("Rectangle");
	r.Size = UDim2.new(0, 400, 0, 80);
	r.Parent = cgui;
	local s = Slider.new();
	s.Parent = r;
	s.Padding = Utils.new("Margin", 4);
	s.Clamp = function(x) return math.floor(x/.1 + .5)*.1; end
	s.NotchLocations = Utils.Table.RangeInclusive(0, 1, .1);
	s:_ForceReflow();
	s:_OrderChildrenOnZIndex();
	for i = 0, 1, .25 do
		s.Value = i;
		wait(.5);
	end
	s:_OrderChildrenOnZIndex();
end

local LelDefaults = {
	Handle = Gui.Create "Image" {Image = "rbxassetid://73812738"; LayoutParams = {AspectRatio = 1}; Position = UDim2.new(0, 0, 0, -20);};
	Tick = Gui.Create "Image" {Image = "rbxassetid://275614649"; Size = UDim2.new(0, 40, 0, 40); Position = UDim2.new(.5, -20, .5, 0);};
};
function Gui.Test.Slider_NewDefaultSet(sgui, cgui)
	local r = Gui.new("Rectangle");
	r.Size = UDim2.new(0, 400, 0, 80);
	r.Parent = cgui;
	local s = Slider.new();
	s.Parent = r;
	s.Padding = Utils.new("Margin", 4);
	s.Clamp = function(x) return math.floor(x/.1 + .5)*.1; end
	s.NotchLocations = Utils.Table.RangeInclusive(0, 1, .1);
	s:_ForceReflow();
	s:_OrderChildrenOnZIndex();
	wait(1);
	s._ChildParameters.Defaults = LelDefaults;
	s:_ForceReflow();
	s:_OrderChildrenOnZIndex();
end

return Slider;
