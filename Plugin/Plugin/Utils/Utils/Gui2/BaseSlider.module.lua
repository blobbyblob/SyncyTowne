--[[

A slider which can select values from 0 to 1. Notches can be drawn on the slider and values can be snapped.

This can be used as the backend for more user-friendly sliders.

Properties:
	Value: the numerical value of the slider.
	Clamp: a function which converts numerical values from 0 to 1 to different numerical values from 0 to 1, indicating the values which are permitted.
	NotchLocations: a table of locations at which notches will be drawn.
	SliderAspect: the aspect ratio of the slider object.
	SliderSize: the number of pixels wide the slider is. This is in addition to any aspect ratio format.
	Direction: the direction in which the user drags. This should be of type Gui.Enum.SliderDirection, which has values Horizontal or Vertical.
	Padding: the number of pixels between the edge of the frame & the slider object.
	SanitizeInput: a flag which indicates whether the script interface should Clamp values set through the Value property.

Not Doing: upgrade this so the Frame, Line, Slider, and Notches can be set by adding them as children. Remove the BackgroundColor3 property.
--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local View = require(script.Parent.View);
local Test = Gui.Test;

Gui.Enum:newEnumClass("SliderDirection", "Horizontal", "Vertical");

local Debug = Log.new("BaseSlider:\t", false);

local BaseSlider = Utils.new("Class", "BaseSlider", View);
local Super = BaseSlider.Super;

-------------------
-- Properties --
-------------------
BaseSlider._Frame = false; --TextButton
BaseSlider._Line = false; --Frame
BaseSlider._Slider = false; --Frame
BaseSlider._Notches = false; --array of Frames
BaseSlider._ChildPlacements = false;
BaseSlider._Cxns = false;
BaseSlider._Dragging = false;
BaseSlider._SanitizeInput = true;

BaseSlider._Value = 0;
BaseSlider._Clamp = function(self, n) return n; end;
BaseSlider._NotchLocations = {};
BaseSlider._SliderSize = 20;
BaseSlider._SliderAspect = 0;
BaseSlider._Direction = Gui.Enum.SliderDirection.Horizontal;
BaseSlider._Padding = 5;

-------------------------
-- Getters/Setters --
-------------------------

function BaseSlider.Set:Name(v)
	self._Frame.Name = v;
	self._Line.Name = v .. "_Line";
	self._Slider.Name = v .. "_Slider";
end

function BaseSlider.Set:Value(v)
	Log.AssertNonNilAndType("Value", "number", v);
	v = v > 0 and (v < 1 and v or 1) or 0;
	if self._SanitizeInput then
		v = self._Clamp(self, v);
	end
	if v ~= self._Value then
		self._Value = v;
		self:ForceReflow();
		self._Changed:Fire("Value");
	end
end
BaseSlider.Get.Value = "_Value";

function BaseSlider.Set:Clamp(v)
	Log.AssertNonNilAndType("Clamp", "function", v);
	Log.AssertNonNilAndType("Clamp return value", "number", v(self, 0));
	self._Clamp = v;
end
BaseSlider.Get.Clamp = "_Clamp";

function BaseSlider.Set:NotchLocations(v)
	Log.AssertNonNilAndType("NotchLocations", "table", v);
	for i, v in pairs(v) do
		Log.AssertNonNilAndType(string.format("NotchLocations[%d]", i), "number", v);
		Log.Assert(0 <= v and v <= 1, "NotchLocations[%d] must be in the range 0 to 1; got %s", i, v);
	end
	self._NotchLocations = v;
	--Ensure the number of notches matches the number of notch locations.
	local notches = self._Notches;
	local locations = self._NotchLocations;
	if #notches > #locations then
		for i = #notches, #locations + 1 do
			notches[i]:Destroy();
			table.remove(notches, i);
		end
	elseif #locations > #notches then
		for i = #notches + 1, #locations do
			notches[i] = Gui.new("Frame");
			notches[i].Name = "Notch" .. tostring(i);
			notches[i].BorderSizePixel = 0;
			notches[i].BackgroundColor3 = Color3.new();
			notches[i].ParentNoNotify = self._Frame;
		end
		self._Slider.ParentNoNotify = nil;
		self._Slider.ParentNoNotify = self._Frame;
	end
	self:ForceReflow();
end
BaseSlider.Get.NotchLocations = "_NotchLocations";

function BaseSlider.Set:SliderAspect(v)
	Log.AssertNonNilAndType("SliderAspect", "number", v);
	self._SliderAspect = v;
end
BaseSlider.Get.SliderAspect = "_SliderAspect";

function BaseSlider.Set:SliderSize(v)
	Log.AssertNonNilAndType("SliderSize", "number", v);
	self._SliderSize = v;
end
BaseSlider.Get.SliderSize = "_SliderSize";

function BaseSlider.Set:Direction(v)
	if v~=Gui.Enum.SliderDirection.Horizontal and v~=Gui.Enum.SliderDirection.Vertical then
		Log.AssertNonNilAndType("Direction", "Gui.Enum.SliderDirection", v);
	end
	self._Direction = v;
end
BaseSlider.Get.Direction = "_Direction";

function BaseSlider.Set:Padding(v)
	Log.AssertNonNilAndType("Padding", "number", v);
	self._Padding = v;
end
BaseSlider.Get.Padding = "_Padding";

--BackgroundColor3: the background color of the main window.
function BaseSlider.Set:BackgroundColor3(v)
	self._Frame.BackgroundColor3 = v;
	local h, s, v = Color3.toHSV(v);
	if v < .5 then
		self._Line.BackgroundColor3 = Color3.fromHSV(h, s, 1);
		self._Slider.BackgroundColor3 = Color3.fromHSV(h, s, 1 - (1 - v) * .5);
	else
		self._Line.BackgroundColor3 = Color3.fromHSV(h, s, 0);
		self._Slider.BackgroundColor3 = Color3.fromHSV(h, s, v * .5);
	end
end
function BaseSlider.Get:BackgroundColor3()
	return self._Frame.BackgroundColor3;
end

function BaseSlider.Set:SanitizeInput(v)
	self._SanitizeInput = v;
	if v then
		self.Value = self.Value;
	end
end
BaseSlider.Get.SanitizeInput = "_SanitizeInput";

-----------------------------------------------------------------------------------------------------------------
-- The following functions are routine declarations for a class which wraps another class --
-----------------------------------------------------------------------------------------------------------------

function BaseSlider:_GetHandle()
	return self._Frame:_GetHandle();
end

function BaseSlider.Set:Parent(v)
	self._Frame.ParentNoNotify = v;
	Super.Set.Parent(self, v);
end

function BaseSlider.Set:ParentNoNotify(v)
	self._Frame.ParentNoNotify = v;
	Super.Set.ParentNoNotify(self, v);
end

function BaseSlider:_GetChildContainer(child)
	return self._Frame:_GetChildContainer(child);
end

function BaseSlider:_Reflow(pos, size)
	Gui.Log.Reflow("BaseSlider._Reflow(%s, %s, %s) called", self, pos, size);
	self._Frame:_SetPPos(pos);
	self._Frame:_SetPSize(size);

	--Get the absolute size of the frame.
	self:_GetHandle().Size = size;
	local size = self:_GetHandle().AbsoluteSize;

	--Compute the height/width of the slider.
	local sHeight, sWidth;
	if self._Direction == Gui.Enum.SliderDirection.Horizontal then
		sHeight = size.y - 2*self._Padding;
		sWidth = sHeight * self._SliderAspect + self._SliderSize;
	else
		sWidth = size.x - 2 * self._Padding;
		sHeight = sWidth * self._SliderAspect + self._SliderSize;
	end

	--Compute the line's height/width.
	local lHeight, lWidth;
	if self._Direction == Gui.Enum.SliderDirection.Horizontal then
		lHeight = 1;
		lWidth = size.x - sWidth - self._Padding * 2;
	else
		lHeight = size.y - sHeight - self._Padding * 2;
		lWidth = 1;
	end

	if self._Direction == Gui.Enum.SliderDirection.Horizontal then
		--Set the slider's location/size.
		self._Slider:_SetPPos(UDim2.new(0, self._Padding + lWidth * self._Value, 0, self._Padding));
		self._Slider:_SetPSize(UDim2.new(0, sWidth, 0, sHeight));
		--Set the line's location/size
		self._Line:_SetPPos(UDim2.new(0, self._Padding + sWidth / 2, 0, size.y / 2 - 0.5));
		self._Line:_SetPSize(UDim2.new(0, lWidth, 0, lHeight));
		local Notches = self._Notches;
		local NotchLocations = self._NotchLocations;

		for i = 1, #Notches do
			local notch = Notches[i];
			local location = NotchLocations[i];
			Debug("Placing notch %d (%s) at location %f", i, notch, location);
			local pos = UDim2.new(0, self._Padding + lWidth * location + sWidth/2, 0, self._Padding);
			local size = UDim2.new(0, 1, 0, sHeight);
			Debug("Setting pos: %s; size: %s", pos, size);
			notch:_SetPPos(pos);
			notch:_SetPSize(size);
			notch:ForceReflow();
		end
	else
		--Set the slider's location/size.
		self._Slider:_SetPPos(UDim2.new(0, self._Padding, 0, self._Padding + lHeight * self._Value));
		self._Slider:_SetPSize(UDim2.new(0, sWidth, 0, sHeight));
		--Set the line's location/size
		self._Line:_SetPPos(UDim2.new(0, size.x / 2 - 0.5, 0, self._Padding + sHeight / 2));
		self._Line:_SetPSize(UDim2.new(0, lWidth, 0, lHeight));
		local Notches = self._Notches;
		local NotchLocations = self._NotchLocations;
		for i = 1, #Notches do
			local notch = Notches[i];
			local location = NotchLocations[i];
			notch:_SetPPos(UDim2.new(0, self._Padding, 0, self._Padding + lHeight * location + sHeight/2));
			notch:_SetPSize(UDim2.new(0, sWidth, 0, 1));
		end
	end

	Debug("End of Reflow");
end

function BaseSlider:_AddChild(v)
	self._ChildPlacements:AddChildTo(v, self._Frame);
	Super._AddChild(self, v);
end

function BaseSlider:_RemoveChild(v)
	self._ChildPlacements:RemoveChild(v);
	Super._RemoveChild(self, v);
end

function BaseSlider:ForceReflow()
	Super.ForceReflow(self);
	self._Frame:ForceReflow();
end

-----------------------------------------------------------------
-- The following functions override the superclass --
-----------------------------------------------------------------

function BaseSlider:Destroy()
	self._Cxns:DisconnectAll();
	return Super.Destroy(self);
end

-------------------------------------------------------------------
-- The following functions are specific to BaseSlider --
-------------------------------------------------------------------

function BaseSlider:_MouseButton1Down(x, y)
	self._Dragging = true;
	self:_MouseMoved(x, y);
	self._Cxns.InputChanged = game:GetService("UserInputService").InputChanged:connect(function(input, gameProcessedEvent)
--		Debug("InputChanged(%s, %s) called", Utils.InputObjectToString(input), gameProcessedEvent);
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if input.UserInputState == Enum.UserInputState.Change then
				self:_MouseMoved(input.Position.x, input.Position.y);
			end
		end
	end)
	self._Cxns.InputEnded = game:GetService("UserInputService").InputEnded:connect(function(input, gameProcessedEvent)
--		Debug("InputEnded(%s, %s) called", Utils.InputObjectToString(input), gameProcessedEvent);
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if input.UserInputState == Enum.UserInputState.End then
				self:_MouseButton1Up(input.Position.x, input.Position.y);
			end
		end
	end)
end

function BaseSlider:_MouseMoved(x, y)
	if not self._Dragging then return; end
	local absPos = Utils.RealAbsolutePosition(self._Frame);
	local value;
	if self._Direction == Gui.Enum.SliderDirection.Horizontal then
		value = (x - absPos.x - self._Padding) / (self._Frame.AbsoluteSize.x - self._Padding * 2);
	else
		value = (y - absPos.y - self._Padding) / (self._Frame.AbsoluteSize.y - self._Padding * 2);
	end
	if value < 0 then
		value = 0;
	elseif value > 1 then
		value = 1;
	end
	value = self:_Clamp(value);
	self.Value = value;
end

function BaseSlider:_MouseButton1Up(x, y)
	if x then
		self:_MouseMoved(x, y);
	end
	self._Dragging = false;
	self._Cxns:Disconnect("InputChanged");
	self._Cxns:Disconnect("InputEnded");
end

--Instantiate & return a new NumberInput.
function BaseSlider.new()
	local self = setmetatable(Super.new(), BaseSlider.Meta);
	self._ChildPlacements = Gui.ChildPlacements();

	self._Frame = Gui.new("TextButton");
	self._Frame.Text = "";
	self._Frame.AutoButtonColor = false;
	self._Line = Gui.new("Frame");
	self._Line.ParentNoNotify = self._Frame;
	self._Slider = Gui.new("Frame");
	self._Slider.ParentNoNotify = self._Frame;
	self._Notches = {};
	self._Cxns = Utils.new("ConnectionHolder");
	self._Cxns.MouseButton1Down = self._Frame.MouseButton1Down:connect(function(x, y) print("m1down"); self:_MouseButton1Down(x, y); end);
--	self._Cxns.MouseMoved = self._Frame.MouseMoved:connect(function(x, y) self:_MouseMoved(x, y); end);
--	self._Cxns.MouseButton1Up = self._Frame.MouseButton1Up:connect(function(x, y) self:_MouseButton1Up(x, y); end);
	self._Frame.AncestryChanged:connect(function()
		if not self._Frame:IsDescendantOf(game) then
			self:_MouseButton1Up();
		end
	end)
	self.Value = self.Value;
	self.Name = self.Name;
	return self;
end

------------
-- Tests --
------------

function Test.BaseSlider_Basic(sgui, cgui)
	local view = Gui.new("View", cgui);
	view.Name = "BaseSlider_Basic";
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 400;
	view.MinimumY = 100;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local slider = Gui.new("BaseSlider", view);
	slider.Name = "Slider";
	slider._Slider.BackgroundTransparency = 0.5;
	slider.BackgroundColor3 = Color3.new(1, 0, 0);
	local startTime = tick();
	local RUNTIME = 1;
	while slider.Value ~= 1 do
		slider.Value = math.min(1, math.max(0, (tick() - startTime) / RUNTIME));
		wait();
	end
end
function Test.BaseSlider_Vertical(sgui, cgui)
	local view = Gui.new("View", cgui);
	view.Name = "BaseSlider_Vertical";
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 80;
	view.MinimumY = 400;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local slider = Gui.new("BaseSlider", view);
	slider.Direction = Gui.Enum.SliderDirection.Vertical;
	slider.Name = "Slider";
	slider._Slider.BackgroundTransparency = 0.5;
	slider.BackgroundColor3 = Color3.new(1, 0, 0);
	local startTime = tick();
	local RUNTIME = 1;
	while slider.Value ~= 1 do
		slider.Value = math.min(1, math.max(0, (tick() - startTime) / RUNTIME));
		wait();
	end
end
function Test.BaseSlider_Clamp(sgui, cgui)
	local view = Gui.new("View", cgui);
	view.Name = "BaseSlider_Basic";
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 400;
	view.MinimumY = 100;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local slider = Gui.new("BaseSlider", view);
	slider.Name = "Slider";
	slider._Slider.BackgroundTransparency = 0.5;
	slider.BackgroundColor3 = Color3.new(1, 0, 0);
	slider.Clamp = function(self, n) return math.floor(n/.1 + .5)*.1; end;
	slider.Changed:connect(function(prop)
		Debug("Property Changed (%s); new value: %s", prop, slider[prop]);
	end)
	local startTime = tick();
	local RUNTIME = 1;
	while slider.Value ~= 1 do
		slider.Value = math.min(1, math.max(0, (tick() - startTime) / RUNTIME));
		wait();
	end
end
function Test.BaseSlider_Notches(sgui, cgui)
	local view = Gui.new("View", cgui);
	view.Name = "BaseSlider_Basic";
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 400;
	view.MinimumY = 100;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local slider = Gui.new("BaseSlider", view);
	slider.Name = "Slider";
	slider._Slider.BackgroundTransparency = 0.5;
	slider.BackgroundColor3 = Color3.new(1, 0, 0);
	slider.NotchLocations = {0, .1, .2, .25, .5, 1};
	local startTime = tick();
	local RUNTIME = 1;
	while slider.Value ~= 1 do
		slider.Value = math.min(1, math.max(0, (tick() - startTime) / RUNTIME));
		wait();
	end
end
return BaseSlider;
