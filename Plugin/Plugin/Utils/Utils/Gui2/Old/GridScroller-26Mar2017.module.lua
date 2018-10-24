--[[

GridScroller: a display which generates entries and recycles them as needed. This is a relatively complicated class and should be deeply investigated before using. Sorry.

Properties:
	ScrollDirection: an enum indicating which direction we should scroll (Horizontal or Vertical)
	AnchorLocation: an enum indicating the corner in which our cells start growing.
	Cushion: the number of pixels between distinct grids.
	MaxIndex: the highest grid index.
	InnerMargin: the margin between the scrolling space and the containing frame's walls. This allows for some over-scroll.
	TopIndex: the index which is at the top of the current scroll display.
	Offset: the number of pixels which this GridScroller is offset. This should be positive.
	GetElementProperties: a function which returns three values: GridType, ElementType, and GroupIndex.
	Grid<GridType>: a property table for a given grid. GridType may be any string. A property table may have the following keys defined:
		Cushion: the amount of space (Vector2) to place between grid elements.
		OrthogonalElements: the number of elements to pack across.
		AspectRatio: the aspect ratio of the cells before adding LinearSize.
		LinearSize: a number of pixels to add to each cell along the scrolling direction.
	Create<ElementType>: a function which creates a new element of type ElementType. ElementType may be any string.
	Update<ElementType>: a function(gui, index) which should update a gui to display the data for element i.

Methods:
	

--]]

local lib = script.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);
local Utils = require(lib.Utils);
local View = require(script.Parent.View);
local Gui = _G[script.Parent];
local Test = Gui.Test;

local Debug = Gui.Log.Debug;

local GridScroller = Class.new("GridScroller", View);
local Super = GridScroller.Super;

Gui.Enum.GridScrollerScrollDirection = {Vertical = 0; Horizontal = 1};
Gui.Enum.GridScrollerAnchorLocation = {TopLeft = 0; TopRight = 1; BottomLeft = 2; BottomRight = 3;};
--[[ @brief Returns whether or not a value is a valid enum.
     @param value Any value.
     @param enum The enum holder, e.g. Gui.Enum.GridScrollerAnchorLocation.
     @return True if value is of the enum type.
--]]
local EnumMap = {};
function IsValidEnum(value, enum)
	if not EnumMap[enum] then
		local t = {};
		for i, v in pairs(enum) do
			t[v] = true;
		end
		EnumMap[enum] = t;
	end
	return EnumMap[enum][value];
end

local LayoutDebug = Log.new("GridScroller:\t", false);

local Round = Utils.Round;
local UnloadAll, UnloadRow, LoadRow;

-------------------
-- Properties --
-------------------
--The direction in which the Grid will scroll.
--Not Doing: Implement this.
GridScroller._ScrollDirection = Gui.Enum.GridScrollerScrollDirection.Vertical;
--The corner in which index 1 resides.
GridScroller._AnchorLocation = Gui.Enum.GridScrollerAnchorLocation.TopLeft;
--The amount of spacing to place between distinct grids.
GridScroller._Cushion = 0;
--The lowest and highest possible indices.
GridScroller._MinIndex = 1;
GridScroller._MaxIndex = 0;
--The margin inside the scroll clipping box.
GridScroller._InnerMargin = {left = 0; right = 0; top = 0; bottom = 0;};
--A function which returns the grid type, element type, and group index.
GridScroller._GetElementProperties = function(self, index)
	return "Default", "Default", index;
end
GridScroller._CreateDefault = function(self)
	local v = Gui.new("TextLabel");
	v.Name = "Test";
	return v;
end
GridScroller._UpdateDefault = function(self, element, i)
	element.Text = "Index " .. tostring(i);
	element.Name = "Index " .. tostring(i);
	element._Handle.Name = "Index " .. tostring(i);
end
GridScroller._GridDefault = {
	Cushion = Vector2.new(0, 0);
	OrthogonalElements = 4;
	AspectRatio = 1;
	LinearSize = 0;
};

--When flagged as true, will require all currently loaded elements to be recategorized.
GridScroller._Recategorize = false;
--The contents of the following table indicate which element class(es) need to be deleted and reloaded.
GridScroller._Recreate = {};
--The contents of the following table indicate which element class(es) need to be updated.
GridScroller._Update = {};
--The lowest index which is displayed at the moment.
GridScroller._LowIndex = 1;
--The highest index which is displayed at the moment.
GridScroller._HighIndex = 0;
--The number of pixels offset. A positive number indicates that LowIndex is pushed up off the top partially.
GridScroller._Offset = 0;

--The handle to represent this object.
GridScroller._Handle = false;
--A mapping of index to element type.
GridScroller._ElementTypes = {};
--A mapping of index to grid types.
GridScroller._MapGridTypes = {};
--A mapping of index to grid index.
GridScroller._MapGridIndex = {};
--A mapping of indices to the elements which represent them.
GridScroller._Elements = {};

--A reserve of created elements which are currently unused. Maps element name to an array of spare elements.
GridScroller._UnusedElements = {};

GridScroller._Cxns = false; --! A connection holder object.

function GridScroller.Set:ScrollDirection(v)
	Log.Error(3, "GridScroller.ScrollDirection is not implemented.");
	Log.Assert(IsValidEnum(v, Gui.Enum.GridScrollerScrollDirection), "ScrollDirection must be Horizontal or Vertical");
	if self._ScrollDirection ~= v then
		self._ScrollDirection = v;
		self._SignalReflowPre:Trigger();
	end
end
function GridScroller.Set:AnchorLocation(v)
	Log.Warn("AnchorLocation not implemented");
	Log.Assert(IsValidEnum(v, Gui.Enum.GridScrollerAnchorLocation), "AnchorLocation must be TopLeft, TopRight, BottomLeft, or BottomRight");
	self._AnchorLocation = v;
	self._SignalReflowPre:Trigger();
end
function GridScroller.Set:Cushion(v)
	Log.AssertNonNilAndType("Cushion", "number", v);
	self._Cushion = v;
	self._SignalReflowPre:Trigger();
end
function TrimExtents(self)
	--Trim at the extremes of the range.
	while self._LowIndex < self._MinIndex and self._LowIndex < self._HighIndex do
		UnloadRow(self, self._LowIndex, 100);
	end
	while self._HighIndex > self._MaxIndex and self._LowIndex < self._HighIndex do
		UnloadRow(self, self._HighIndex, 100);
	end
	--Trim the topmost and bottommost row.
	if self._LowIndex < self._HighIndex then
		UnloadRow(self, self._LowIndex, 100);
	end
	if self._LowIndex < self._HighIndex then
		UnloadRow(self, self._HighIndex, 100);
	end
end
function GridScroller.Set:MaxIndex(v)
	Log.AssertNonNilAndType("Cushion", "number", v);
	local lastMaxIndex = self._MaxIndex;
	self._MaxIndex = v;
	self._SignalReflowPre:Trigger();
	TrimExtents(self);
end
function GridScroller.Set:MinIndex(v)
	Log.AssertNonNilAndType("MinIndex", "number", v);
	local lastMinIndex = self._MinIndex;
	self._MinIndex = v;
	self._SignalReflowPre:Trigger();
	TrimExtents(self);
end
function GridScroller.Set:InnerMargin(v)
	if type(v)=='number' then
		v = {left = v; right = v; top = v; bottom = v;};
	end
	Log.AssertNonNilAndType("InnerMargin", "table", v);
	Log.AssertNonNilAndType("InnerMargin.left", "number", v.left);
	Log.AssertNonNilAndType("InnerMargin.right", "number", v.right);
	Log.AssertNonNilAndType("InnerMargin.top", "number", v.top);
	Log.AssertNonNilAndType("InnerMargin.bottom", "number", v.bottom);
	self._InnerMargin = v;
	self._SignalReflowPre:Trigger();
end
function GridScroller.Set:GetElementProperties(v)
	Log.AssertNonNilAndType("GetElementProperties", "function", v);
	self._GetElementProperties = v;
	self._Recategorize = true;
	self._ReflowPre();
end
function GridScroller:SetGrid(GridName, GridProperties)
	--Verify that GridProperties has no improper properties.
	Log.AssertNonNilAndType("GridProperties", "table", GridProperties);
	Log.AssertNonNilAndType("GridProperties.Cushion", "userdata", GridProperties.Cushion);
	Log.AssertNonNilAndType("GridProperties.OrthogonalElements", "number", GridProperties.OrthogonalElements);
	Log.AssertNonNilAndType("GridProperties.AspectRatio", "number", GridProperties.AspectRatio);
	Log.AssertNonNilAndType("GridProperties.LinearSize", "number", GridProperties.LinearSize);
	--Write it to the current instance.
	local t = Utils.ShallowTableCopy(GridProperties);
	rawset(self, GridName, t);
	if self._ScrollDirection == Gui.Enum.GridScrollerScrollDirection.Horizontal then
		t.Cushion = Vector2.new(t.Cushion.y, t.Cushion.x);
		t.AspectRatio = (t.AspectRatio == 0 and 0 or 1/t.AspectRatio);
	end
end
function GridScroller:SetUpdate(UpdateName, UpdateFunction)
	--Verify that UpdateFunction is in fact a function.
	Log.AssertNonNilAndType(UpdateName:sub(2), "function", UpdateFunction);
	--Write it to the current instance.
	rawset(self, UpdateName, UpdateFunction);
	--Update all existing elements which are of this class.
	self._Update[UpdateName] = true;
end
function GridScroller:SetCreate(CreateName, CreateFunction)
	--Verify that CreateFunction is ok.
	Log.AssertNonNilAndType(CreateName:sub(2), "function", CreateFunction);
	--Write it to the current instance.
	rawset(self, CreateName, CreateFunction);
	--Clean up all elements which are of this class & recreate them.
	self._Recreate[CreateName] = true;
end
function GridScroller.Set:Offset(v)
	Log.AssertNonNilAndType("Scroll", "number", v);
	self._Offset = v;
	self._SignalReflowPre:Trigger();
end

GridScroller.Get.ScrollDirection = "_ScrollDirection";
GridScroller.Get.AnchorLocation = "_AnchorLocation";
GridScroller.Get.Cushion = "_Cushion";
GridScroller.Get.MaxIndex = "_MaxIndex";
GridScroller.Get.InnerMargin = "_InnerMargin";
GridScroller.Get.GetElementProperties = "_GetElementProperties";
function GridScroller:GetGrid(GridName)
	return rawget(self, GridName);
end
function GridScroller:GetUpdate(UpdateName)
	return rawget(self, UpdateName);
end
function GridScroller:GetGrid(CreateName)
	return rawget(self, CreateName);
end
GridScroller.Get.Offset = "_Offset";
GridScroller.Get.TopIndex = "_LowIndex";

function GridScroller:__newindex(i, v)
	--Detect key elements: Create, Update, Grid. Otherwise, just allow writing to the key.
	if i:sub(1, 4) == "Grid" then
		self:SetGrid("_" .. i, v);
	elseif i:sub(1, 6) == "Create" then
		self:SetCreate("_" .. i, v);
	elseif i:sub(1, 6) == "Update" then
		self:SetUpdate("_" .. i, v);
	else
		Log.Warn(3, "Attempting to write to unknown key; %s[%s] = %s", self, i, v);
		rawset(self, i, v);
	end
end
function GridScroller:__index(i)
	--Detect key elements: Create, Update, Grid. Otherwise, just allow writing to the key.
	if i:sub(1, 4) == "Grid" then
		return self:GetGrid("_" .. i);
	elseif i:sub(1, 6) == "Create" then
		return self:GetCreate("_" .. i);
	elseif i:sub(1, 6) == "Update" then
		return self:GetUpdate("_" .. i);
	end
end

--[[ @brief Unloads a single element.
     @param self The GridScroller we are working with.
     @param i The index we should load.
     @details Updates self._Elements, self._UnusedElement.
     @return The number of elements that come before this index in a complete row.
     @return The number of elements that come after this index in a complete row.
--]]
local function UnloadElement(self, i)
	LayoutDebug("Unloading index %s", i);
	local ElementType = self._ElementTypes[i];
	local GridData = self._MapGridTypes[i];
	local Cache = self._UnusedElements[ElementType];
	if not Cache then
		LayoutDebug("    Element %s cache doesn't exist. Creating...", ElementType);
		Cache = {};
		self._UnusedElements[ElementType] = Cache;
	end
	local obj = self._Elements[i];
	LayoutDebug("    Reinserting element %s into cache for %s", obj, ElementType);
	table.insert(Cache, obj);
	obj.Parent = nil;
	self._Elements[i] = nil;

	local j = (self._MapGridIndex[i] - 1) % GridData.OrthogonalElements;
	LayoutDebug("Index within row is %s; returning <%s, %s>", j, j, GridData.OrthogonalElements - 1 - j);
	return j, GridData.OrthogonalElements - 1 - j;
end

--[[ @brief Unloads a row of elements.
     @param self The GridScroller for which we are loading.
     @param i Any index within the row.
     @param width The amount of horizontal space this row takes.
     @details This function will update self._LowIndex or self._HighIndex depending on whether the deleted row occurs at the beginning or end of the loaded elements.
         If the row is in the middle, an error will be thrown. Additionally, self._Offset will be updated if the new row occurs before the first element.
--]]
function UnloadRow(self, i, width)
	LayoutDebug("Unloading row containing %s", i);
	local GridData = self._MapGridTypes[i];
	local GroupIndex = self._MapGridIndex[i];
	LayoutDebug("GridIndex: %s", GroupIndex);
	local RowIndex = (i - 1) % GridData.OrthogonalElements + 1;
	LayoutDebug("Index within row: %s", RowIndex);
	local Preceding, Succeeding = RowIndex - 1, GridData.OrthogonalElements - RowIndex;
	local Minimum = math.max(i - Preceding, self._MinIndex, self._LowIndex);
	local Maximum = math.min(i + Succeeding, self._MaxIndex, self._HighIndex);
	--Refine Minimum/Maximum by making sure the indices we are clearing don't cross GridType boundaries.
	for j = i + 1, Maximum do
		if self._MapGridTypes[j] ~= GridData then
			Maximum = j - 1;
		end
	end
	for j = i - 1, Minimum, -1 do
		if self._MapGridTypes[j] ~= GridData then
			Minimum = j + 1;
		end
	end
	--Unload all elements within the range.
	for j = Minimum, Maximum do
		UnloadElement(self, j);
	end
	--Adjust self._Offset if we are trimming from the beginning.
	local Height = (width - (GridData.OrthogonalElements - 1) * GridData.Cushion.x) / GridData.OrthogonalElements
	--Update _LowIndex and _HighIndex based on which side was trimmed.
	if Minimum == self._LowIndex then
		LayoutDebug("    Changing _LowIndex from %s to %s", self._LowIndex, Maximum + 1);
		--Adjust _Offset when we prepend the row to the existing set.
		if self._MapGridTypes[Maximum + 1] ~= self._MapGridTypes[self._LowIndex] then
			--The current row is followed by a different grid type.
			LayoutDebug("    Subtracting %s from self._Cushion (%s + %s)", Height + self._Cushion, Height, self._Cushion);
			self._Offset = self._Offset - (Height + self._Cushion);
		else
			--The current row is followed by the same grid type.
			LayoutDebug("    Subtracting %s from self._Cushion (%s + %s)", Height + GridData.Cushion.y, Height, GridData.Cushion.y);
			self._Offset = self._Offset - (Height + GridData.Cushion.y);
		end
		self._LowIndex = Maximum + 1;
	elseif Maximum == self._HighIndex then
		LayoutDebug("    Changing _HighIndex from %s to %s", self._HighIndex, Minimum - 1);
		self._HighIndex = Minimum - 1;
	else
		Log.Assert(false, "UnloadRow unloaded a row in the middle of the currently loaded elements.");
	end

end

--[[ @brief Unloads all elements so self._LowIndex can be adjusted as desired.
--]]
function UnloadAll(self)
	for i = self._LowIndex, self._HighIndex do
		UnloadRow(self, i, 600);
	end
	self._Offset = 0;
end

--[[ @brief Gets GridType, ElementType, and GridIndex for a given index.
     @param self The GridScroller we are working with.
     @param i The index of the element for which we want data.
     @param ForceRefresh If true, will not take any cached data & will instead perform another call to GetElementProperties.
     @details The tables self._ElementTypes, self._MapGridTypes, and self._MapGridIndex will be updated to have entries for index i.
     @return The element type for index i.
     @return The GridData for index i.
     @return The grid index for global index i.
--]]
local function GetElementData(self, i, ForceRefresh)
	if self._ElementTypes[i] and self._MapGridTypes[i] and self._MapGridIndex[i] and not ForceRefresh then
		return self._ElementTypes[i], self._MapGridTypes[i], self._MapGridIndex[i];
	end

	local GetFunc = self._GetElementProperties;
	local GridName, ElementType, GroupIndex = GetFunc(self, i);
	LayoutDebug("    GetElementProperties(%s, %s) = <%s, %s, %s>", self, i, GridName, ElementType, GroupIndex);
	local GridData = self['_Grid' .. GridName];
	Log.Assert(GridData, "Grid%s property is undefined.", GridName);

	--Update the categorizations for this element.
	self._ElementTypes[i] = ElementType;
	self._MapGridTypes[i] = GridData;
	self._MapGridIndex[i] = GroupIndex or i;

	return ElementType, GridData, GroupIndex or i;
end

--[[ @brief Loads a single element.
     @param self The GridScroller we are working with.
     @param i The index we should load.
     @details Updates self._ElementTypes, self._MapGridTypes, self._MapGridIndex, self._Elements, self._UnusedElement.
     @return The number of elements that come before this index in a complete row.
     @return The number of elements that come after this index in a complete row.
--]]
local function LoadElement(self, i)
	LayoutDebug("Loading index %s", i);

	local ElementType, GridData, GridIndex = GetElementData(self, i, true);

	--Get or create a new element to represent this.
	local Element;
	local Cache = self._UnusedElements[ElementType];
	if not Cache then
		LayoutDebug("    Element %s cache doesn't exist. Creating...", ElementType);
		Cache = {};
		self._UnusedElements[ElementType] = Cache;
	end
	if #Cache > 0 then
		LayoutDebug("    Element cache contains %s elements.", #Cache);
		Element = Cache[#Cache];
		table.remove(Cache, #Cache);
	else
		LayoutDebug("    Element cache is empty. Creating new...");
		local CreationFunction = self['_Create' .. ElementType];
		Log.Assert(CreationFunction, "Create%s property is undefined.", ElementType);
		Element = CreationFunction(self);
		Log.Assert(Element, "Create%s function returns no value.", ElementType);
		LayoutDebug("    Create%s(%s) = %s", self, Element);
	end
	self._Elements[i] = Element;
	self['_Update' .. ElementType](self, self._Elements[i], i);
	self._Elements[i].Parent = self:_GetHandle();

	local j = (self._MapGridIndex[i] - 1) % GridData.OrthogonalElements + 1;
	LayoutDebug("Index within row is %s; returning <%s, %s>", j, j - 1, GridData.OrthogonalElements - j);
	return j - 1, GridData.OrthogonalElements - j;
end

--[[ @brief Loads a row of elements.
     @param self The GridScroller for which we are loading.
     @param i Any index within the row.
     @param width The amount of horizontal space this row takes.
     @details This function will update self._LowIndex or self._HighIndex depending on whether the new row occurs before or after the loaded elements.
         If i is between self._LowIndex or self._HighIndex, nothing will happen. Additionally, self._Offset will be updated if the new row occurs before the first element.
         Additionally, this function will update self._ElementTypes, self._MapGridTypes, and self._MapGridIndex with the results for all indices in the row.
     @return The number of pixels this row takes up.
--]]
function LoadRow(self, i, width)
	if self._LowIndex <= i and i <= self._HighIndex then
		LayoutDebug("Ignoring request to load %s; already loaded", i);
		return 0;
	elseif i < self._MinIndex or i > self._MaxIndex then
		LayoutDebug("Ignoring request to load %s; outside of valid range %s - %s", i, self._MinIndex, self._MaxIndex);
		return 0;
	end
	LayoutDebug("Loading row containing index %s", i);
	local Preceding, Following = LoadElement(self, i);
	local Minimum = math.max(i - Preceding, self._MinIndex);
	local Maximum = math.min(i + Following, self._MaxIndex);
	if self._LowIndex > self._HighIndex then
	elseif i > self._HighIndex then
		Minimum = math.max(Minimum, self._HighIndex + 1);
	elseif i < self._LowIndex then
		Maximum = math.min(self._LowIndex - 1, Maximum);
	end
	LayoutDebug("Loading elements from %s to %s excluding %s", Minimum, Maximum, i);
	LayoutDebug("    Step pattern: for j = %s, %s, 1 do", i + 1, Maximum);
	LayoutDebug("    Step pattern: for j = %s, %s, -1 do", i - 1, Minimum);
	for j = i + 1, Maximum do
		LoadElement(self, j);
		if self._MapGridTypes[i] ~= self._MapGridTypes[j] then
			--We were too hasty! We loaded too many additional items.
			UnloadElement(self, j);
			break; 
		end
	end
	for j = i - 1, Minimum, -1 do
		LoadElement(self, j);
		if self._MapGridTypes[i] ~= self._MapGridTypes[j] then
			UnloadElement(self, j);
			break;
		end
	end

	--Figure out the height of the row we just loaded. Did it come before _LowIndex? If so, add it to _Offset. Include the cushion.
	local GridData = self._MapGridTypes[i];
	local Height = (width - (GridData.OrthogonalElements - 1) * GridData.Cushion.x) / GridData.OrthogonalElements
	if self._LowIndex > self._HighIndex then
		LayoutDebug("Updating self._LowIndex = %s", Minimum);
		LayoutDebug("Updating self._HighIndex = %s", Maximum);
		self._LowIndex = Minimum;
		self._HighIndex = Maximum;
	end
	if Minimum < self._LowIndex then
		LayoutDebug("Updating self._LowIndex = %s", Minimum);
		--Adjust _Offset when we prepend the row to the existing set.
		if self._MapGridTypes[Minimum] ~= self._MapGridTypes[self._LowIndex] then
			--The current row is followed by a different grid type.
			LayoutDebug("Adding %s to self._Offset (%s + %s)", Height + self._Cushion, Height, self._Cushion);
			self._Offset = self._Offset + Height + self._Cushion;
		else
			--The current row is followed by the same grid type.
			LayoutDebug("Adding %s to self._Offset (%s + %s)", Height + GridData.Cushion.y, Height, GridData.Cushion.y);
			self._Offset = self._Offset + Height + GridData.Cushion.y;
		end
		self._LowIndex = Minimum;
	end
	if Maximum > self._HighIndex then
		LayoutDebug("Updating self._HighIndex = %s", Maximum);
		self._HighIndex = Maximum;
	end
end

--[[ @brief Returns the dimensions (Width x Height) of a given element (neglecting all cushions).
     @param self The GridScroller we are working with.
     @param index The index we are querying.
     @param width The amount of horizontal space we are working with.
     @return The width of the element.
     @return The height of the element.
--]]
local function ElementSize(self, index, width)
	Log.Assert(1 <= index and index <= self._MaxIndex, "Attempt to query size of element out of range.");
	local GridData = self._MapGridTypes[index];
	if not GridData then
		local GetFunc = self._GetElementProperties;
		local GridName, ElementType, GroupIndex = GetFunc(self, index);
		LayoutDebug("    GetElementProperties(%s, %s) = <%s, %s, %s>", self, index, GridName, ElementType, GroupIndex);
		local GridData = self['_Grid' .. GridName];
		Log.Assert(GridData, "Grid%s property is undefined.", GridName);
	
		--Update the categorizations for this element.
		self._ElementTypes[index] = ElementType;
		self._MapGridTypes[index] = GridData;
		self._MapGridIndex[index] = GroupIndex or index;
	end
	local Width = (width - GridData.Cushion.x * (GridData.OrthogonalElements - 1)) / GridData.OrthogonalElements;
	local Height = GridData.LinearSize;
	if GridData.AspectRatio ~= 0 then
		Height = Height + Width / GridData.AspectRatio;
	end
	return Width, Height;
end

--[[ @brief Seeks out a complete row.
     @param self The GridScroller we are working with.
     @param index An index within the row.
     @param seekdirection A value of "up", "down", or "both". If index is at the beginning of the row, use "up". If it is at the end, use "down". If its location is unknown, use "both".
     @return The first index of the row.
     @return The final index of the row.
     @return The GridData for the row.
--]]
local function SeekCompleteRow(self, index, seekdirection)
	local LowIndex, HighIndex;
	local _, GridData, GridIndex;
	if seekdirection == 'down' then
		HighIndex = index;
		_, GridData, GridIndex = GetElementData(self, HighIndex);
		local RowIndex = (GridIndex - 1) % GridData.OrthogonalElements + 1;
		LowIndex = index - RowIndex + 1;
		for i = HighIndex - 1, LowIndex, -1 do
			local _, GridDataCurrent = GetElementData(self, i);
			if GridData ~= GridDataCurrent then
				LowIndex = i + 1;
				break;
			end
		end
	elseif seekdirection == 'both' then
		_, GridData, GridIndex = GetElementData(self, index);
		local RowIndex = (GridIndex - 1) % GridData.OrthogonalElements + 1;
		LowIndex = index - RowIndex + 1;
		HighIndex = index + GridData.OrthogonalElements - RowIndex;
		HighIndex = math.min(self._MaxIndex, HighIndex);
		--Seek up until a grid type mismatch is found.
		for i = index + 1, HighIndex do
			local _, GridDataCurrent = GetElementData(self, i);
			if GridData ~= GridDataCurrent then
				HighIndex = i - 1;
				break;
			end
		end
		--Seek down until a grid type mismatch is found.
		for i = index - 1, LowIndex, -1 do
			local _, GridDataCurrent = GetElementData(self, i);
			if GridData ~= GridDataCurrent then
				LowIndex = i + 1;
				break;
			end
		end
	else
		LowIndex = index;
		_, GridData, GridIndex = GetElementData(self, index);
		local RowIndex = (GridIndex - 1) % GridData.OrthogonalElements + 1;
		HighIndex = index + GridData.OrthogonalElements - RowIndex;
		HighIndex = math.min(self._MaxIndex, HighIndex);
		for i = LowIndex, HighIndex do
			local _, GridDataCurrent = GetElementData(self, i);
			if GridData ~= GridDataCurrent then
				HighIndex = i - 1;
				break;
			end
		end
	end
	return LowIndex, HighIndex, GridData;
end

--[[ @brief Fills in row information into a table. The keys which will be filled are shown in GetRowData.
     @param self The GridScroller we are working with.
     @param LowIndex The lowest index within the row.
     @param HighIndex The highest index within the row.
     @param GridData The table with grid parameters representing the elements in this row.
     @param Width The number of orthogonal pixels we have to work with.
     @note The Y entry will not be filled.
--]]
local function GetSingleRowData(self, LowIndex, HighIndex, GridData, Width)
	local Row = {};
	for i = LowIndex, HighIndex do
		table.insert(Row, self._Elements[i]);
	end
	Row.GridData = GridData;
	Row.n = HighIndex - LowIndex + 1;
	Row.LowIndex = LowIndex;
	Row.HighIndex = HighIndex;
	Row.Width = (Width - (GridData.OrthogonalElements - 1) * GridData.Cushion.x) / GridData.OrthogonalElements;
	Row.Height = GridData.LinearSize;
	if GridData.AspectRatio ~= 0 then
		Row.Height = Row.Height + Row.Width / GridData.AspectRatio;
	end
	if self._MaxIndex >= HighIndex + 1 then
		local _, GridDataNext = GetElementData(self, HighIndex + 1);
		if GridDataNext == GridData then
			Row.Cushion = GridData.Cushion.y;
		else
			Row.Cushion = self._Cushion;
		end
	else
		Row.Cushion = 0;
	end
	return Row;
end

--[[ @brief Collects elements into rows starting with self._LowIndex.
     @param self The GridScroller we are working with.
     @param StartingLinearPosition The original y position we are working with.
     @param Width The orthogonal space we are working with.
     @return An array of dictionaries. The dictionaries' numeric keys correspond to elements. String keys correspond to the following:
         GridData: the shared GridData self._MapGridTypes[i] for all elements in this row.
         n: the number of elements in this row.
         LowIndex: the lowest index in the row.
         HighIndex: the highest index in the row.
         Height: the height of each element in this row.
         Width: the width of each element in this row.
         Cushion: the amount of space which follows this row.
         Y: the position of the row along the linear axis.
--]]
local function GetRowData(self, StartingLinearPosition, Width)
	local Rows = {};
	if self._MaxIndex == 0 then return Rows; end
	Log.Assert(self._LowIndex <= self._MaxIndex, "_LowIndex (%s) exceeds _MaxIndex (%s) for obj %s", self._LowIndex, self._MaxIndex, self);
	local LowIndex, HighIndex, GridData = self._LowIndex, self._LowIndex - 1;
	local k = Utils.WhileLoopLimiter(20, "GetRowData");
	while HighIndex < self._HighIndex and k() do
		LowIndex, HighIndex, GridData = SeekCompleteRow(self, HighIndex + 1, 'up');
		local Row = GetSingleRowData(self, LowIndex, HighIndex, GridData, Width);
		Row.Y = StartingLinearPosition;
		StartingLinearPosition = StartingLinearPosition + Row.Height + Row.Cushion;
		table.insert(Rows, Row);
	end
	return Rows;
end

--[[ @brief Starting from the first index within the Rows table, will seek backward until a complete row is found, then add it to the list of rows.
     @param self The GridScroller we are working with.
     @param Rows A table of rows obtained from GetRowData.
     @param Width The amount of orthogonal space in pixels.
     @details The input object Rows will be modified with an extra element inserted at the beginning.
--]]
function PrependRow(self, Rows, Width)
	local NextRow = Rows[1];
	--Terminate earlier if no data exists before this row.
	if NextRow.LowIndex == 1 then return; end
	local LowIndex, HighIndex, GridData = SeekCompleteRow(self, NextRow.LowIndex - 1, 'down');
	local CurrentRow = GetSingleRowData(self, LowIndex, HighIndex, GridData, Width);
	CurrentRow.Y = NextRow.Y - CurrentRow.Cushion - CurrentRow.Height;
	table.insert(Rows, 1, CurrentRow);
end

local function PostpendRow(self, Rows, Width)
	local LastRow = Rows[#Rows];
	--Terminate early if no data exists after this row.
	if LastRow.HighIndex == self._MaxIndex then return; end
	local LowIndex, HighIndex, GridData = SeekCompleteRow(self, LastRow.HighIndex + 1, 'up');
	local CurrentRow = GetSingleRowData(self, LowIndex, HighIndex, GridData, Width);
	CurrentRow.Y = LastRow.Y + LastRow.Height + LastRow.Cushion;
	table.insert(Rows, CurrentRow);
end

function GridScroller:_Reflow(pos, size)
	--Place the handle. Convert size to use pixels only. Modify it based on the InnerMargin.
	self._Handle.Position = pos;
	self._Handle.Size = size;
	pos = UDim2.new(0, self._InnerMargin.left, 0, self._InnerMargin.top);
	size = UDim2.new(0, self._Handle.AbsoluteSize.x - self._InnerMargin.left - self._InnerMargin.right, 0, self._Handle.AbsoluteSize.y - self._InnerMargin.top - self._InnerMargin.bottom);

	--Ensure at least one row is loaded.
	if self._HighIndex < self._LowIndex then
		LoadRow(self, self._LowIndex <= self._MaxIndex and self._LowIndex or 1, size.X.Offset);
		self._Offset = 0;
	end

	--Group all loaded elements into rows.
	local Rows = GetRowData(self, -self._Offset, size.X.Offset);
	LayoutDebug("Reporting Row Information");
	for i, v in pairs(Rows) do
		LayoutDebug("    Row %s", i);
		LayoutDebug("        GridData: %s", v.GridData);
		LayoutDebug("        n: %s", v.n);
		LayoutDebug("        LowIndex: %s", v.LowIndex);
		LayoutDebug("        HighIndex: %s", v.HighIndex);
		LayoutDebug("        Height: %s", v.Height);
		LayoutDebug("        Width: %s", v.Width);
		LayoutDebug("        Cushion: %s", v.Cushion);
		LayoutDebug("        Y: %s", v.Y);
		LayoutDebug("        Elements:");
		for j, u in ipairs(v) do
			LayoutDebug("            %s", u);
		end
	end

	if #Rows == 0 then
		return;
	end

	--If the last row + its height rests below size.Y.Offset, a new row may be loaded.
	local k = Utils.WhileLoopLimiter(10, "LoadAtEnd");
	while Rows[#Rows].Y + Rows[#Rows].Height < size.Y.Offset and Rows[#Rows].HighIndex < self._MaxIndex and k() do
		LayoutDebug("Loading row at end (beginning at index %s)", Rows[#Rows].HighIndex + 1);
		LoadRow(self, Rows[#Rows].HighIndex + 1, size.X.Offset);
		PostpendRow(self, Rows, size.X.Offset);
	end

	--If the very final row rests above the bottom of the box, adjust offset so it rests at the bottom of the box.
	if Rows[#Rows].HighIndex == self._MaxIndex then
		local offset = Rows[#Rows].Y + Rows[#Rows].Height - size.Y.Offset;
		if offset < 0 then
			self._Offset = self._Offset + offset;
			for i, v in pairs(Rows) do
				v.Y = v.Y - offset;
			end
		end
	end

	local k = Utils.WhileLoopLimiter(10, "LoadAtBeginning");
	--If the first row rests at Y>0 & there exist elements before it, load the row.
	while Rows[1].Y > 0 and Rows[1].LowIndex > self._MinIndex and k() do
		LayoutDebug("Loading row at beginning (ending at index %s)", Rows[1].LowIndex - 1);
		LoadRow(self, Rows[1].LowIndex - 1, size.X.Offset);
		PrependRow(self, Rows, size.X.Offset);
	end

	--If the very first row rests below the top of the box, adjust offset so it rests at the top.
	if self._Offset < 0 then
		local offset = self._Offset;
		self._Offset = 0;
		for i, v in pairs(Rows) do
			v.Y = v.Y + offset;
		end
	end

	--If the second row rests at Y<0, the first row may be unloaded.
	local k = Utils.WhileLoopLimiter(10, "UnloadAtBeginning");
	while #Rows > 1 and Rows[2].Y < 0 and k() do
		LayoutDebug("Unloading row at beginning (beginning at index %s)", Rows[1].LowIndex);
		UnloadRow(self, Rows[1].LowIndex, size.X.Offset);
		table.remove(Rows, 1);
	end

	--If the last row rests at Y>size.Y.Offset + max(cushion), the last row may be unloaded.
	local k = Utils.WhileLoopLimiter(10, "UnloadAtEnd");
	while #Rows > 1 and Rows[#Rows].Y > size.Y.Offset + Rows[#Rows-1].Cushion and k() do
		LayoutDebug("Unloading row at end (beginning at index %s)", Rows[#Rows].LowIndex);
		UnloadRow(self, Rows[#Rows].LowIndex, size.X.Offset);
		table.remove(Rows, #Rows);
	end

	for RowIndex, Row in pairs(Rows) do
		for i, element in ipairs(Row) do
			element:_SetPPos(pos + UDim2.new(0, (i - 1) * (Row.Width + Row.GridData.Cushion.x), 0, Row.Y));
			element:_SetPSize(UDim2.new(0, Row.Width, 0, Row.Height));
		end
	end

end

--[[ @brief Set which index is at the top of the list.
--]]
function GridScroller.Set:TopIndex(v)
	Log.AssertNonNilAndType("TopIndex", "number", v);
	--Possible cases:
	--	v << self._LowIndex: unload all rows & set marker down at v.
	--	v < self._LowIndex: load all rows between v and the old LowIndex.
	--	v = self._LowIndex: no change.
	--	v > self._LowIndex: Unload all rows prior to v.
	--	v > self._HighIndex: unload all rows & set marker at v.
	if (v < self._LowIndex - (self._HighIndex - self._LowIndex)) or (v > self._HighIndex) then
		UnloadAll(self);
		self._LowIndex = v;
		self._HighIndex = v - 1;
	elseif v < self._LowIndex then
		for i = v, self._LowIndex - 1 do
			LoadRow(self, i, 600);
			self._Offset = 0;
		end
	elseif v > self._LowIndex then
		for i = self._LowIndex, v - 1 do
			UnloadRow(self, i, 600);
		end
		LoadRow(self, v, 600);
		self._Offset = 0;
	end
	self._SignalReflowPre:Trigger();
end

--[[ @brief Force the GridScroller to reflow, then repeat for all contained elements.
--]]
function GridScroller:ForceReflow()
	Super.ForceReflow(self);
	for i, v in pairs(self._Elements) do
		v:ForceReflow();
	end
end

function GridScroller.new()
	local self = Super.new();
	setmetatable(self, GridScroller.Meta);
	self._Recreate = {};
	self._Update = {};
	self._Handle = Instance.new("TextButton");
	self._Handle.Text = "";
	self._Handle.AutoButtonColor = false;
	self._Handle.BorderSizePixel = 0;
	self._Handle.ClipsDescendants = true;
	self._ElementTypes = {};
	self._MapGridTypes = {};
	self._MapGridIndex = {};
	self._Elements = {};
	self._UnusedElements = {};
	self._Cxns = Utils.newConnectionHolder();
	self._Cxns.MouseWheelForward = self._Handle.MouseWheelForward:connect(function()
		self.Offset = self.Offset + 10;
	end)
	self._Cxns.MouseWheelBackward = self._Handle.MouseWheelBackward:connect(function()
		self.Offset = self.Offset - 10;
	end)
	return self;
end

function Test.GridScroller_UserInput(_, sgui)
	local x = Gui.new("GridScroller");
	x.Size = UDim2.new(0.5, 0, 0.5, 0);
	x.Position = UDim2.new(0.25, 0, 0.25, 0);
	x.MinIndex = -40;
	x.MaxIndex = 40;
	x.Cushion = 4;
	x.Margin = 4;
	function x.UpdateDefault(self, element, index)
		element.Text = "Index " .. tostring(index);
		element.Name = element.Text;
		element.BackgroundColor3 = Color3.fromHSV(((index - 1) % 6) / 6, 1, 1)
		if index%6==5 then
			element.TextColor3 = Color3.new(1, 1, 1);
		else
			element.TextColor3 = Color3.new(0, 0, 0);
		end
	end
	x.Parent = sgui;
end

function Test.GridScroller_MinIndex(sgui)
	local x = Gui.new("GridScroller");
	function x.UpdateDefault(self, element, index)
		element.Text = "Index " .. tostring(index);
		element.Name = element.Text;
		element.BackgroundColor3 = Color3.fromHSV(((index - 1) % 6) / 6, 1, 1)
		if index%6==5 then
			element.TextColor3 = Color3.new(1, 1, 1);
		else
			element.TextColor3 = Color3.new(0, 0, 0);
		end
	end
	x.Size = UDim2.new(0.5, 0, 0.5, 0);
	x.Position = UDim2.new(0.25, 0, 0.25, 0);
	x.MinIndex = -20;
	x.MaxIndex = 20;
	x.Cushion = 4;
	x.Margin = 4;
	x.Parent = sgui;
	for i = 0, 30 do
		x.Offset = x.Offset - 5;
		wait();
	end
end

function Test.GridScroller_Basic_Visual(sgui)
	local gs = Gui.new("GridScroller", sgui);
	gs.Gravity = Gui.Enum.ViewGravity.Center;
	gs.FillX = false;
	gs.FillY = false;
	gs.MinimumX = 300;
	gs.MinimumY = 300;
	gs.Cushion = 10;
	gs.GridDefault = {
		Cushion = Vector2.new(4, 4);
		OrthogonalElements = 5;
		AspectRatio = 1;
		LinearSize = 0;
	};
	function gs.UpdateDefault(self, element, index)
		element.Text = "Index " .. tostring(index);
		element.Name = element.Text;
		element.BackgroundColor3 = Color3.fromHSV(((index - 1) % 6) / 6, 1, 1)
		if index%6==5 then
			element.TextColor3 = Color3.new(1, 1, 1);
		else
			element.TextColor3 = Color3.new(0, 0, 0);
		end
	end
	gs.InnerMargin = 0;
	gs.MaxIndex = 10;
	for i = 0, 30 do
		gs.Offset = gs.Offset + 3;
		wait();
		Log.AssertEqual("Offset", 0, gs.Offset);
	end
	gs.MaxIndex = 30;
	for i = 0, 30 do
		gs.Offset = gs.Offset + 3;
		wait();
	end
	gs.MaxIndex = 50;
	wait();
	for i = 0, 30 do
		gs.Offset = gs.Offset + 3;
		wait();
	end
end

function Test.GridScroller_IncreasingMaxIndex_Visual()
	local sgui = Instance.new("ScreenGui", game.StarterGui);
	sgui.Name = "GridScroller_Basic";
	local gs = Gui.new("GridScroller", sgui);
	gs.Gravity = Gui.Enum.ViewGravity.Center;
	gs.FillX = false;
	gs.FillY = false;
	gs.MinimumX = 300;
	gs.MinimumY = 300;
	gs.GridDefault = {
		Cushion = Vector2.new(4, 4);
		OrthogonalElements = 5;
		AspectRatio = 1;
		LinearSize = 0;
	};
	function gs.UpdateDefault(self, element, index)
		element.Text = "Index " .. tostring(index);
		element.Name = element.Text;
		element.BackgroundColor3 = Color3.fromHSV((index % 6) / 6, 1, 1)
	end
	gs.MaxIndex = 8;
	wait(.1);
	for i = 9, 30 do
		gs.MaxIndex = i;
		gs:ForceReflow();
		wait(.1);
	end
	wait(.1);
	gs.Offset = 20;
end

function Test.GridScroller_HastyOffset()
	local sgui = Instance.new("ScreenGui", game.StarterGui);
	sgui.Name = "GridScroller_Basic";
	local gs = Gui.new("GridScroller", sgui);
	gs.Gravity = Gui.Enum.ViewGravity.Center;
	gs.FillX = false;
	gs.FillY = false;
	gs.MinimumX = 300;
	gs.MinimumY = 300;
	gs.GridDefault = {
		Cushion = Vector2.new(4, 4);
		OrthogonalElements = 5;
		AspectRatio = 1;
		LinearSize = 0;
	};
	function gs.UpdateDefault(self, element, index)
		element.Text = "Index " .. tostring(index);
		element.Name = element.Text;
		element.BackgroundColor3 = Color3.fromHSV((index % 6) / 6, 1, 1)
	end
	gs.MaxIndex = 8;
	gs.Offset = 20;
	wait();
	Log.AssertEqual("Offset", 0, gs.Offset);
	gs.MaxIndex = 30;
	gs.Offset = 20;
	wait();
	Log.AssertEqual("Offset", 20, gs.Offset);
end

--function Test.GridScroller_Horizontal()
--	local sgui = Instance.new("ScreenGui", game.StarterGui);
--	sgui.Name = "GridScroller_Basic";
--	local gs = Gui.new("GridScroller", sgui);
--	gs.ScrollDirection = Gui.Enum.GridScrollerScrollDirection.Horizontal;
--	gs.Gravity = Gui.Enum.ViewGravity.Center;
--	gs.FillX = false;
--	gs.FillY = false;
--	gs.MinimumX = 300;
--	gs.MinimumY = 300;
--	gs.Cushion = 10;
--	gs.GridDefault = {
--		Cushion = Vector2.new(4, 4);
--		OrthogonalElements = 5;
--		AspectRatio = 1;
--		LinearSize = 0;
--	};
--	function gs.UpdateDefault(self, element, index)
--		element.Text = "Index " .. tostring(index);
--		element.Name = element.Text;
--		element.BackgroundColor3 = Color3.fromHSV(((index - 1) % 6) / 6, 1, 1)
--		if index%6==5 then
--			element.TextColor3 = Color3.new(1, 1, 1);
--		else
--			element.TextColor3 = Color3.new(0, 0, 0);
--		end
--	end
--	gs.InnerMargin = 0;
--	gs.MaxIndex = 10;
--	for i = 0, 30 do
--		gs.Offset = gs.Offset + 3;
--		wait();
--		Log.AssertEqual("Offset", 0, gs.Offset);
--	end
--	gs.MaxIndex = 30;
--	for i = 0, 30 do
--		gs.Offset = gs.Offset + 3;
--		wait();
--	end
--	gs.MaxIndex = 50;
--	wait();
--	for i = 0, 30 do
--		gs.Offset = gs.Offset + 3;
--		wait();
--	end
--end

return GridScroller;
