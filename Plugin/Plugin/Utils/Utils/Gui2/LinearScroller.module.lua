--[[

LinearScroller: a display which generates entries and recycles them as needed. Entries are identified by index (1 at top or left, increasing down/right). Entries can by identified by a label (any string) which will also specify the desired AspectRatio and AbsoluteSize of the element.

Properties:
	ScrollDirection: an string indicating which direction we should scroll ("Horizontal" or "Vertical")
	Cushion: the number of pixels between elements.
	MinIndex: the lowest grid index.
	MaxIndex: the highest grid index.
	InnerMargin: the margin between the scrolling space and the containing frame's walls. This allows for some over-scroll. Create this with Utils.new("Margin", n).
	TopIndex: the index which is at the top of the current scroll display.
	Offset: the number of pixels which this GridScroller is offset. A positive value means this element is pushed up.
	ElementType GetElementType(int index): a function which returns the ElementType (string) for a given index.

Methods:
	RegisterElementFactory(string ElementType, gui ElementFactory()): registers a factory function which, when called, returns a newly created GUI which can be formatted for elements of type ElementType.
	RegisterElementProperties(string ElementType, table Properties): registers a table of properties for a given ElementType. Properties are:
		AspectRatio: the aspect ratio for this row.
		LinearSize: the number of pixels for this row. This is added after AspectRatio.
	RegisterElementFormat(string ElementType, void ElementFormat(int index, gui element)): formats element for a given index.
--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local View = require(script.Parent.View);
local Gui = _G[script.Parent];
local Test = Gui.Test;

local Debug = Utils.new("Log", "LinearScroller", false);

local LinearScroller = Utils.new("Class", "LinearScroller", View);
local Super = LinearScroller.Super;

Gui.Enum:newEnumClass("LinearScrollerScrollDirection", "Vertical", "Horizontal");

LinearScroller._Handle = false; --! The frame which listens for scroll events & clips the children.
LinearScroller._First = 1; --! The first element which is currently displayed.
LinearScroller._Last = 0; --! The last element which is currently displayed. If this is less than first, then none are displayed.
LinearScroller._Elements = {}; --! A map of [index] --> {gui, ElementType}.
LinearScroller._CurrentRenderedHeight = 0; --! The number of pixels along the scrolling direction of this element which are rendered.

LinearScroller._ScrollDirection = Gui.Enum.LinearScrollerScrollDirection.Vertical;
LinearScroller._Cushion = 4;
LinearScroller._MinIndex = 1;
LinearScroller._MaxIndex = 0;
LinearScroller._TopIndex = 1;
LinearScroller._Offset = 0;
LinearScroller._GetElementType = function(index) return "Default"; end
LinearScroller._InnerMargin = Utils.new("Margin", 4);
LinearScroller._Factories = {Default = function() return Instance.new("TextButton"); end};
LinearScroller._Formatters = {Default = function(index, element) element.Text = "Index: " .. tostring(index); end};
LinearScroller._Properties = {Default = {AspectRatio = 0; LinearSize = 20;}};

local function BasicSetterFactory(property, internalName, type)
	return function(self, v)
		Log.AssertNonNilAndType(property, type, v);
		if self[internalName] ~= v then
			self[internalName] = v;
			self._SignalReflowPre:Trigger();
		end
	end;
end
local function EnumSetterFactory(property, internalName, enum)
	return function(self, v)
		v = enum:ValidateEnum(v);
		if self[internalName] ~= v then
			self[internalName] = v;
			self._SignalReflowPre:Trigger();
		end
	end;
end

LinearScroller.Set.ScrollDirection = EnumSetterFactory("ScrollDirection", "_ScrollDirection", Gui.Enum.LinearScrollerScrollDirection);
LinearScroller.Set.Cushion = BasicSetterFactory("Cushion", "_Cushion", "number");
LinearScroller.Set.MinIndex = BasicSetterFactory("MinIndex", "_MinIndex", "number");
LinearScroller.Set.MaxIndex = BasicSetterFactory("MaxIndex", "_MaxIndex", "number");
LinearScroller.Set.TopIndex = BasicSetterFactory("TopIndex", "_TopIndex", "number");
LinearScroller.Set.Offset = BasicSetterFactory("Offset", "_Offset", "number");
LinearScroller.Set.GetElementType = BasicSetterFactory("GetElementType", "_GetElementType", "function");
function LinearScroller.Set:InnerMargin(v)
	Log.AssertNonNilAndType("InnerMargin", "table", v);
	Log.AssertNonNilAndType("InnerMargin.Left", "number", v.Left);
	Log.AssertNonNilAndType("InnerMargin.Right", "number", v.Right);
	Log.AssertNonNilAndType("InnerMargin.Top", "number", v.Top);
	Log.AssertNonNilAndType("InnerMargin.Bottom", "number", v.Bottom);
	self._InnerMargin = v;
	self._SignalReflowPre:Trigger();
end

LinearScroller.Get.ScrollDirection = "_ScrollDirection";
LinearScroller.Get.Cushion = "_Cushion";
LinearScroller.Get.MinIndex = "_MinIndex";
LinearScroller.Get.MaxIndex = "_MaxIndex";
LinearScroller.Get.TopIndex = "_TopIndex";
LinearScroller.Get.Offset = "_Offset";
LinearScroller.Get.GetElementType = "_GetElementType";
LinearScroller.Get.InnerMargin = "_InnerMargin";


function LinearScroller:RegisterElementFactory(elementType, factory)
	Log.AssertNonNilAndType("ElementType", "string", elementType);
	Log.AssertNonNilAndType("ElementFactory", "function", factory);
	self._Factories[elementType] = factory;
	self._SignalReflowPre:Trigger();
end

function LinearScroller:RegisterElementProperties(elementType, properties)
	Log.AssertNonNilAndType("ElementType", "string", elementType);
	Log.AssertNonNilAndType("Properties", "table", properties);
	Log.AssertNonNilAndType("Properties.AspectRatio", "number", properties.AspectRatio);
	Log.AssertNonNilAndType("Properties.LinearSize", "number", properties.LinearSize);
	self._Properties[elementType] = properties;
	self._SignalReflowPre:Trigger();
end

function LinearScroller:RegisterElementFormat(elementType, formatFn)
	Log.AssertNonNilAndType("ElementType", "string", elementType);
	Log.AssertNonNilAndType("ElementFormat", "function", formatFn);
	self._Formatters[elementType] = formatFn;
	self._SignalReflowPre:Trigger();
end

--[[ @brief Loads an element and returns the amount of linear space is requires.
     @param i The index of the element.
     @return linearSize The amount of space this element takes along the scrolling direction.
--]]
local function LoadElement(self, i, orthogonalSize)
	Debug("LoadElement(%s, %s, %s) called", self, i, orthogonalSize);
	local type = self._GetElementType(i);
	local gui = self._Factories[type]();
	self._Formatters[type](i, gui);
	self._Elements[i] = {gui, type};
	gui.Parent = self._Handle;
	local height = self._Properties[type].LinearSize + self._Properties[type].AspectRatio * orthogonalSize;
	self._CurrentRenderedHeight = self._CurrentRenderedHeight + height + self._Cushion;
	return self._Properties[type].LinearSize + self._Properties[type].AspectRatio * orthogonalSize;
end
local function UnloadElement(self, i, orthogonalSize)
	local type = self._GetElementType(i);
	local height = self._Properties[type].LinearSize + self._Properties[type].AspectRatio * orthogonalSize;
	self._Elements[i][1].Parent = nil;
	self._Elements[i] = nil;
	self._CurrentRenderedHeight = self._CurrentRenderedHeight - height - self._Cushion;
end
--[[ @brief Attempts to load a range of elements.
     @param i The lower end of the range.
     @param j The higher end of the range.
     @param maxSize The maximum size in pixels which we may load.
     @return The last index which we loaded.
--]]
local function LoadRange(self, i, j, maxSize, orthogonalSize)
	Debug("LoadRange(%s, %s, %s, %s, %s) called", self, i, j, maxSize, orthogonalSize);
	for k = i, j do
		maxSize = maxSize - LoadElement(self, k, orthogonalSize) - self._Cushion;
		if maxSize < 0 then
			return k;
		end
	end
	return j;
end
--[[ @brief Unloads a range of elements.
     @param self The LinearScroller we are working with.
     @param i The lower end of the range to unload on.
     @param j The higher end of the range to unload on.
--]]
local function UnloadRange(self, i, j, orthogonalSize)
	Debug("UnloadRange(%s, %s, %s) called", self, i, j);
	for k = i, j do
		UnloadElement(self, k, orthogonalSize);
	end
end
--[[ @brief Loads elements from newFirst to self._First as long as there is enough screen space to fit the range.
     @param self The LinearScroller we are working with.
     @param newFirst The new index we start loading from.
     @param maxSize The maximum number of pixels we may load.
--]]
local function PrefixOrReplaceRange(self, newFirst, maxSize, orthogonalSize)
	Debug("PrefixOrReplaceRange(newFirst = %s, maxSize = %s, orthogonalSize = %s) called", newFirst, maxSize, orthogonalSize);
	local last = LoadRange(self, newFirst, self._First - 1, maxSize, orthogonalSize);
	if last == self._First - 1 then
		self._First = newFirst;
	else
		UnloadRange(self, self._First, self._Last, orthogonalSize);
		self._First = newFirst;
		self._Last = last;
	end
end

local function MeasureElement(self, index, orthogonalSize)
--	Debug("MeasureElement(%s, %s, %s) called", self, index, orthogonalSize);
	local properties;
	if self._Elements[index] then
		properties = self._Properties[self._Elements[index][2]]
	else
		properties = self._Properties[self._GetElementType(index)];
	end
	return properties.LinearSize + properties.AspectRatio * orthogonalSize;
end

local function PlaceAllElements(self, rootPos, orthogonalSize)
	local y = 0;
	for i = self._First, self._Last do
		local gui, type = unpack(self._Elements[i]);
		gui.Position = rootPos + UDim2.new(0, 0, 0, y);
		local elementSize = MeasureElement(self, i, orthogonalSize);
		gui.Size = UDim2.new(0, orthogonalSize, 0, elementSize);
		y = y + elementSize + self._Cushion;
	end
end
local function PlaceAllElementsHorizontal(self, rootPos, orthogonalSize)
	local y = 0;
	for i = self._First, self._Last do
		local gui, type = unpack(self._Elements[i]);
		gui.Position = rootPos + UDim2.new(0, y, 0, 0);
		local elementSize = MeasureElement(self, i, orthogonalSize);
		gui.Size = UDim2.new(0, elementSize, 0, orthogonalSize);
		y = y + elementSize + self._Cushion;
	end
end
function LinearScroller:_Reflow(pos, size)
	local orthoAxis = "x";
	local linearAxis = "y";
	local frontOrthoMargin = self._InnerMargin.Left;
	local backOrthoMargin = self._InnerMargin.Right;
	local frontLinearMargin = self._InnerMargin.Top;
	local backLinearMargin = self._InnerMargin.Bottom;
	if self._ScrollDirection == Gui.Enum.LinearScrollerScrollDirection.Horizontal then
		orthoAxis, linearAxis = linearAxis, orthoAxis;
		frontOrthoMargin, frontLinearMargin = frontLinearMargin, frontOrthoMargin
		backOrthoMargin, backLinearMargin = backLinearMargin, backOrthoMargin;
	end

	self._Handle.Position = pos;
	self._Handle.Size = size;
	local absSize = self._Handle.AbsoluteSize;
--	Debug("Current Range: %s - %s", self._First, self._Last);
--	Debug("New TopIndex: %s", self._TopIndex);
	--Shift TopIndex based on Offset.
	local elementSizeWithCushion = MeasureElement(self, self._TopIndex, absSize[orthoAxis]) + self._Cushion;
	if self._Offset <  -self._Cushion and self._TopIndex > self._MinIndex then
		Debug("Offset Event: went low");
		self._TopIndex = self._TopIndex - 1;
		self._Offset = self._Offset + elementSizeWithCushion;
	elseif self._Offset > frontLinearMargin + elementSizeWithCushion - self._Cushion then
		Debug("Offset Event: went high");
		self._TopIndex = self._TopIndex + 1;
		self._Offset = self._Offset - elementSizeWithCushion;
	end
	if self._TopIndex > self._Last then
		Debug("Index Event: jumped far ahead");
		--Unload the entire range. Then load a new range.
		UnloadRange(self, self._First, self._Last, absSize[orthoAxis]);
		local last = LoadRange(self, self._TopIndex, self._MaxIndex, absSize[linearAxis] + self._Offset, absSize[orthoAxis]);
		self._First = self._TopIndex;
		self._Last = last;
	elseif self._First > self._TopIndex then
		Debug("Index Event: decremented");
		--Load elements from self._TopIndex until self._First-1 or the height of the window is reached, whichever comes first.
		PrefixOrReplaceRange(self, self._TopIndex, absSize[linearAxis] + self._Offset, absSize[orthoAxis])
	else
		if self._TopIndex > self._First then
			Debug("Index Event: incremented");
			--Unload a partial range from _First to _TopIndex-1.
			UnloadRange(self, self._First, self._TopIndex - 1, absSize[orthoAxis]);
			self._First = self._TopIndex;
		end
		--Load elements toward the tail of the list as long as we have space.
		local availableSpace = absSize[linearAxis] + self._Offset - frontLinearMargin + self._Cushion;
		for i = self._First, self._Last do
			availableSpace = availableSpace - MeasureElement(self, i, absSize[orthoAxis]) - self._Cushion;
		end
		if availableSpace > 0 and self._Last < self._MaxIndex then
			Debug("Extra space available; loading elements up to %d", self._MaxIndex);
			local last = LoadRange(self, self._Last + 1, self._MaxIndex, availableSpace, absSize[orthoAxis]);
			self._Last = last;
		elseif availableSpace > backLinearMargin then
			self._Offset = self._Offset - (availableSpace - backLinearMargin);
			Debug("Exceeded end! %d", availableSpace);
		end
	end
	if self._ScrollDirection == Gui.Enum.LinearScrollerScrollDirection.Horizontal then
		PlaceAllElementsHorizontal(self, UDim2.new(0, -self._Offset + frontLinearMargin, 0, frontOrthoMargin), absSize[orthoAxis] - backOrthoMargin - frontOrthoMargin);
	else
		PlaceAllElements(self, UDim2.new(0, frontOrthoMargin, 0, -self._Offset + frontLinearMargin), absSize[orthoAxis] - backOrthoMargin - frontOrthoMargin);
	end
end

function LinearScroller:_GetHandle()
	return self._Handle;
end

function LinearScroller:Clone()
	local obj = Super.Clone(self);
	local PROPERTIES = {
		"ScrollDirection";
		"Cushion";
		"MinIndex";
		"MaxIndex";
		"InnerMargin";
		"TopIndex";
		"Offset";
		"GetElementProperties";
		"_Factories";
		"_Formatters";
		"_Properties";
	};
	for _, v in pairs(PROPERTIES) do
		obj[v] = self[v];
	end
	return obj;
end

function LinearScroller.new()
	local self = setmetatable(Super.new(), LinearScroller.Meta);
	self._Handle = Instance.new("TextButton");
	self._Handle.AutoButtonColor = false;
	self._Handle.Text = "";
	self._Handle.ClipsDescendants = true;
	return self;
end

function Test.LinearScroller_Basic(sgui, cgui)
	local ls = Gui.new("LinearScroller");
	ls.Size = UDim2.new(0.5, 0, 0.5, 0);
	ls.Position = UDim2.new(0.25, 0, 0.25, 0);
	ls.MaxIndex = 30;
	ls.Parent = sgui;
	ls.Cushion = 20;
	local k = 0;
	Utils.Animate.TemporaryOnHeartbeat(function(dt) k=k+dt; ls.Offset = ls.Offset + dt*30; end, 3, true);
	Utils.Animate.TemporaryOnHeartbeat(function(dt) k=k+dt; ls.Offset = ls.Offset + dt*150; end, 3, true);
	Utils.Animate.TemporaryOnHeartbeat(function(dt) k=k+dt; ls.Offset = ls.Offset - dt*150; end, 3, true);
	Utils.Animate.TemporaryOnHeartbeat(function(dt) k=k+dt; ls.Offset = ls.Offset - dt*30; end, 3, true);
end
function Test.LinearScroller_BigMargin(sgui, cgui)
	local ls = Gui.new("LinearScroller");
	ls.Size = UDim2.new(0.5, 0, 0.5, 0);
	ls.Position = UDim2.new(0.25, 0, 0.25, 0);
	ls.MaxIndex = 30;
	ls.InnerMargin = Utils.new("Margin", 40);
	ls.Parent = sgui;
	local elements = {};
	ls:RegisterElementFactory("Default", function(...)
		table.insert(elements, Instance.new("TextLabel"));
		return elements[#elements];
	end);
	ls:RegisterElementFormat("Default", function(index, element)
		element.Text = string.format("%d", index);
	end)
	Utils.Animate.TemporaryOnHeartbeat(function(dt) ls.Offset = ls.Offset + dt*30; end, 3, true);
	Utils.Animate.TemporaryOnHeartbeat(function(dt) ls.Offset = ls.Offset + dt*150; end, 3, true);
	--Validate that the very final element's bottom side is 40 pixels from the edge.
	local foundLast = false;
	for i, v in pairs(elements) do
		if v.Text == "30" then
			local frame = ls:_GetHandle();
			foundLast = true;
			Log.AssertEqual("elements[30] bottom right corner", frame.AbsolutePosition + frame.AbsoluteSize - Vector2.new(40, 40), v.AbsolutePosition + v.AbsoluteSize);
		end
	end
	Log.AssertEqual("Found element 30", true, foundLast);
end

function Test.LinearScroller_Horizontal(sgui)
	local ls = Gui.new("LinearScroller");
	ls.Size = UDim2.new(0.5, 0, 0.5, 0);
	ls.Position = UDim2.new(0.25, 0, 0.25, 0);
	ls.MaxIndex = 30;
	ls.Parent = sgui;
	ls.ScrollDirection = "Horizontal";
	Utils.Animate.TemporaryOnHeartbeat(function(dt) ls.Offset = ls.Offset + dt*30; end, 3, true);
	Utils.Animate.TemporaryOnHeartbeat(function(dt) ls.Offset = ls.Offset + dt*150; end, 3, true);
end

return LinearScroller;
