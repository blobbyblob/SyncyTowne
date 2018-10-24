--[[

A layout which assists with placing elements in a grid. Elements may span multiple cells. This layout has some capacity to resize itself in order to fit many elements.

Properties
	Cushion (Vector2) = <0, 0>: the amount of space to place between tiles.
	ColumnWidths (array<number>) = {0}: the number of pixels to give each column.
	ColumnWeights (array<number>) = {1}: the proportion of additional pixels to give to this element with respect to the total of ColumnWeights.
	ColumnRowWeights (array<number>) = {0}: additional pixels to give to this element with respect to the total of RowWeights. This can be used to guarantee a given aspect ratio for an element.
	RowHeights (array<number>) = {0}: the number of pixels to give each row.
	RowWeights (array<number>) = {1}: the proportion of additional pixels to give to this element with respect to the total of RowWeights.
	RowColumnWeights (array<number>) = {0}: the proportion of additional pixels to give to this row determined by the formula: extra_horizontal_pixels * RowColumnWeights[this row] / Sum(ColumnWeights)
	AnchorLocation (Enum) = Gui.Enum.GridLayoutAnchorLocation.TopLeft: determines in which corner the index (1,1) resides. Values can be TopLeft, TopRight, BottomLeft, BottomRight.
	GrowthDirection (Enum) = Gui.Enum.GridLayoutGrowthDirection.Vertical: When extras space is needed, this is the dimension which will be expanded. Potential values are Vertical and Horizontal.
	MinimumGridDimensions (Vector2) = <1, 1>: the grid dimensions. If extra space is needed, expansion may occur in one dimension.
	AlwaysUseFrame (boolean): if true, the GridLayout will always use a frame instead of just when one is necessary.
	ChildProperties (table) = {}: a table mapping a child object to a table of parameters describing it. The possible parameters are given in the following table.

Child Properties
	X (number) = 0: the column index. A value of zero means it is unspecified.
	Y (number) = 0: the row index. A value of zero means it is unspecified.
	Width (number) = 1: the number of columns the element spans.
	Height (number) = 1: the number of rows the element spans.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local Test = Gui.Test;
local View = require(script.Parent.View);

local Debug = Gui.Log.Debug;

local PlacementGrid = require(script.GridCellFinder);

local GridLayout = Utils.new("Class", "GridLayout", View);

local GridLayoutLog = Log.new("GridLayout:\t", true);

Gui.Enum:newEnumClass("GridLayoutGrowthDirection", "Horizontal", "Vertical");
Gui.Enum:newEnumClass("GridLayoutAnchorLocation", "TopLeft", "TopRight", "BottomLeft", "BottomRight");

--[[ @brief Copy source to dest up to a given length. If source doesn't contain enough elements, the final element will be repeated.
     @param dest The table into which we should copy the elements.
     @param length The length to make dest.
     @param source The table to take the data from.
--]]
function ResizeArrayFromSource(dest, length, source)
	for i = 1, length do
		if source[i] == nil then
			dest[i] = source[#source];
		else
			dest[i] = source[i];
		end
	end
	dest[length+1] = nil;
end

local Sum = Utils.Table.Sum;
local Round = Utils.Math.Round;

GridLayout._Cushion = Vector2.new(0, 0);
GridLayout._ColumnWidths = {0};
GridLayout._ColumnWeights = {1};
GridLayout._ColumnRowWeights = {0};
GridLayout._RowHeights = {0};
GridLayout._RowWeights = {1};
GridLayout._RowColumnWeights = {0};
GridLayout._AnchorLocation = Gui.Enum.GridLayoutAnchorLocation.TopLeft;
GridLayout._GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;
GridLayout._MinimumSize = Vector2.new(1, 1);
GridLayout._Handle = false;
GridLayout._AlwaysUseFrame = false;
GridLayout._ChildLayoutParams = {
	X = 0;
	Y = 0;
	Width = 1;
	Height = 1;
};
GridLayout._FillXAlt = true;
GridLayout._FillYAlt = true;
GridLayout._FillX = true;
GridLayout._FillY = true;

--[[ When these properties are changed, the system should "reflow".
--]]
for i, v in pairs({
		Cushion = "_Cushion";
		ColumnWidths = "_ColumnWidths";
		ColumnWeights = "_ColumnWeights";
		ColumnRowWeights = "_ColumnRowWeights";
		RowHeights = "_RowHeights";
		RowWeights = "_RowWeights";
		RowColumnWeights = "_RowColumnWeights";
		MinimumGridDimensions = "_MinimumSize";
		AlwaysUseFrame = "_AlwaysUseFrame";
	}) do
	GridLayout.Set[i] = function(self, value)
		if self[v] == value then return; end
		self[v] = value;
		self._SignalReflowPre:Trigger();
	end
	GridLayout.Get[i] = v;
end
for externalName, tuple in pairs({
		AnchorLocation = {"_AnchorLocation", Gui.Enum.GridLayoutAnchorLocation};
		GrowthDirection = {"_GrowthDirection", Gui.Enum.GridLayoutGrowthDirection};
	}) do
	local internalName, enumClass = unpack(tuple);
	GridLayout.Set[externalName] = function(self, value)
		value = enumClass:ValidateEnum(value, externalName);
		self[internalName] = value;
		self._SignalReflowPre:Trigger();
	end
	GridLayout.Get[externalName] = internalName;
end

function GridLayout.Set:Name(v)
	self._Name = v;
	if self._Handle then
		self._Handle.Name = v;
	end
end

GridLayout.Set.FillX = "_FillXAlt";
GridLayout.Set.FillY = "_FillYAlt";
GridLayout.Get.FillX = "_FillXAlt";
GridLayout.Get.FillY = "_FillYAlt";

GridLayout.Get.ChildProperties = "_ChildLayoutParams";
function GridLayout.Get:ChildLayoutParams()
	Log.Warn("Key %s deprecated in favor of %s", "ChildLayoutParams", "ChildProperties");
	return self._ChildLayoutParams;
end

--[[ @brief Sets whether or not all children should be parented to a common frame.
     @details The frame does not impact rendering, but does allow the AspectRatio to be maintained when pixel information is unknown (within an extent).
     @param value The new value (true or false) of whether a frame should be used.
--]]
function GridLayout:_EnableHandle(value)
	if value and self._Handle then
		if Sum(self._RowColumnWeights)~=0 then
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXX;
		elseif Sum(self._ColumnRowWeights)~=0 then
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeYY;
		else
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		end
	end
	if value == (not not self._Handle) then return; end
	if value then
		self._Handle = Instance.new("Frame");
		self._Handle.BackgroundTransparency = 1;
		if self._Parent then
			self.ParentNoNotify = self._Parent;
		end
		Gui.ReparentChildren(self);
		if Sum(self._RowColumnWeights)~=0 then
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXX;
		elseif Sum(self._ColumnRowWeights)~=0 then
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeYY;
		else
			self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		end
		self.Name = self.Name;
	else
		self._Handle.Parent = nil;
		self._Handle = nil;
	end
	if self.Parent then
		self.Parent = self.Parent;
	end
	self._SignalReflowPre:Trigger();
end

--[[ @brief Returns a handle for this GridLayout if one is needed/desired.
     @return A frame for this GridLayout, or nil if one is not needed.
--]]
function GridLayout:_GetHandle()
	if self._Handle then
		return self._Handle;
	else
		return nil;
	end
end

--[[ @brief Returns the minimum size which this element needs to render correctly.
     @details The minimum size of a grid is the sum of all its column widths and row heights.
--]]	
function GridLayout:_GetMinimumSize()
	local grid = PlacementGrid.new();
	grid.MinimumSize = self._MinimumSize;
	grid.FillDirection = self._GrowthDirection.Name;
	grid.AnchorLocation = self._AnchorLocation.Value - 1;
	for i, v in pairs(self:GetChildren()) do
		local paramTable = self._ChildLayoutParams[v] or v.LayoutParams or {};
		local x, y, width, height = paramTable.X or 0, paramTable.Y or 0, paramTable.Width or 1, paramTable.Height or 1;
		if x==0 or y==0 then
			grid:RegisterUnknownLocation(v, width, height);
		else
			grid:RegisterKnownLocation(v, x, y, width, height);
		end
	end
	local GridSize = grid.Size;
	local x = Utils.Table.Sum(self._ColumnWidths, GridSize.x);
	local y = Utils.Table.Sum(self._RowHeights, GridSize.y);
	x, y = x + (GridSize.x - 1) * self._Cushion.x, y + (GridSize.y - 1) * self._Cushion.y;
	if type(self._Margin)=='number' then
		x, y = x + self._Margin * 2, y + self._Margin * 2;
	else
		x, y = x + self._Margin.left + self._Margin.right, y + self._Margin.top + self._Margin.bottom;
	end
	return Vector2.new(x, y);
end

--[[ @brief Organizes the parameters and passes them to the Layout function.
	
--]]
function GridLayout:_Reflow(pos, size)
	Gui.Log.Reflow("GridLayout._Reflow(%s, %s, %s) called", self, pos, size);

	local children = {};
	local params = {};
	local grid = PlacementGrid.new();
	grid.MinimumSize = self._MinimumSize;
	grid.FillDirection = self._GrowthDirection;
	grid.AnchorLocation = self._AnchorLocation.Value;
	for i, v in pairs(self:GetChildren()) do
		local paramTable = self._ChildLayoutParams[v] or v.LayoutParams or {};
		local x, y, width, height = paramTable.X or 0, paramTable.Y or 0, paramTable.Width or 1, paramTable.Height or 1;
		if x==0 or y==0 then
			grid:RegisterUnknownLocation(v, width, height);
		else
			grid:RegisterKnownLocation(v, x, y, width, height);
		end
	end
	for i, v in pairs(self:GetChildren()) do
		local paramTable = self._ChildLayoutParams[v] or v.LayoutParams or {};
		local width, height = paramTable.Width or 1, paramTable.Height or 1;
		local pos = grid:FetchLocation(v);
		table.insert(children, {v, pos.x, pos.y, width, height});
	end
	params.GridSize = grid.Size;

	params.ColumnWidths = {};
	params.ColumnWeights = {};
	params.ColumnRowWeights = {};
	params.RowHeights = {};
	params.RowWeights = {};
	params.RowColumnWeights = {};
	ResizeArrayFromSource(params.ColumnWidths, params.GridSize.x, self._ColumnWidths);
	--If FillX = false, Sum(ColumnWeights) should be set to 0.
	ResizeArrayFromSource(params.ColumnWeights, params.GridSize.x, self._FillXAlt and self._ColumnWeights or {0});
	ResizeArrayFromSource(params.ColumnRowWeights, params.GridSize.x, self._FillYAlt and self._ColumnRowWeights or {0});
	ResizeArrayFromSource(params.RowHeights, params.GridSize.y, self._RowHeights);
	--If FillY = false, Sum(RowWeights) should be set to 0.
	ResizeArrayFromSource(params.RowWeights, params.GridSize.y, self._FillYAlt and self._RowWeights or {0});
	ResizeArrayFromSource(params.RowColumnWeights, params.GridSize.y, self._FillXAlt and self._RowColumnWeights or {0});
	params.Cushion = self._Cushion;

	--Under no circumstances may ColumnRowWeights & RowColumnWeights be defined together.
	Log.Assert(Sum(self._ColumnRowWeights)==0 or Sum(self._RowColumnWeights)==0, "ColumnRowWeights and RowColumnWeights may not both be defined.");

	--If ColumnRowWeights is used, Sum(RowWeights) must not be 0.
	Log.Assert(Sum(self._ColumnRowWeights)==0 or Sum(self._RowWeights)~=0, "ColumnRowWeights cannot be defined if RowWeights is not.");
	Log.Assert(Sum(self._RowColumnWeights)==0 or Sum(self._ColumnWeights)~=0, "RowColumnWeights cannot be defined if ColumnWeights is not.");

	--If ColumnRowWeights & ColumnWeights are used, y scale should be 0.
	if Sum(self._ColumnRowWeights)~=0 and Sum(self._ColumnWeights)~=0 and size.Y.Scale~=0 then
		self:_EnableHandle(true);
		self._Handle.Size = size;
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		size = UDim2.new(size.X.Scale, size.X.Offset, 0, self._Handle.AbsoluteSize.y);
		--Update PlacementSize as well.
		self._Handle.Size = self._PlacementSize;
		self._PlacementSize = UDim2.new(self._PlacementSize.X.Scale, self._PlacementSize.X.Offset, 0, self._Handle.AbsoluteSize.y);
		self:_EnableHandle(false);
	end
	if Sum(self._RowColumnWeights)~=0 and Sum(self._RowWeights)~=0 and size.X.Scale~=0 then
		self:_EnableHandle(true);
		self._Handle.Size = size;
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		self._PlacementSize = UDim2.new(0, self._Handle.AbsoluteSize.x, size.Y.Scale, size.Y.Offset);
		size = UDim2.new(0, self._Handle.AbsoluteSize.x, size.Y.Scale, size.Y.Offset);
		--Update PlacementSize as well.
		self._Handle.Size = self._PlacementSize;
		self._PlacementSize = UDim2.new(0, self._Handle.AbsoluteSize.x, self._PlacementSize.Y.Scale, self._PlacementSize.Y.Offset);
		self:_EnableHandle(false);
	end
	Log.Assert(not (Sum(self._ColumnRowWeights)~=0 and Sum(self._ColumnWeights)~=0 and size.Y.Scale~=0), "ColumnRowWeights and ColumnWeights may not both be defined if size has a y scale component.");
	Log.Assert(not (Sum(self._RowColumnWeights)~=0 and Sum(self._RowWeights)~=0 and size.X.Scale~=0), "RowColumnWeights and RowWeights may not both be defined if size has an x scale component.");

	local RelativeYY = size.Y.Scale~=0 and Sum(self._ColumnRowWeights)~=0;
	local RelativeXX = size.X.Scale~=0 and Sum(self._RowColumnWeights)~=0
	local SquareContainerRequired = RelativeYY or RelativeXX;
	local XMiddle = self._Gravity == Gui.Enum.ViewGravity.Center or self._Gravity == Gui.Enum.ViewGravity.TopCenter or self._Gravity == Gui.Enum.ViewGravity.BottomCenter;
	local XRight = self._Gravity == Gui.Enum.ViewGravity.CenterRight or self._Gravity == Gui.Enum.ViewGravity.TopRight or self._Gravity == Gui.Enum.ViewGravity.BottomRight;
	local YMiddle = self._Gravity == Gui.Enum.ViewGravity.Center or self._Gravity == Gui.Enum.ViewGravity.CenterLeft or self._Gravity == Gui.Enum.ViewGravity.CenterRight;
	local YBottom = self._Gravity == Gui.Enum.ViewGravity.BottomLeft or self._Gravity == Gui.Enum.ViewGravity.BottomCenter or self._Gravity == Gui.Enum.ViewGravity.BottomRight;
	--[[ Conditions in which we would want to enable a handle:
			* AlwaysUseFrame is true.
			* Size is given by Scale & ColumnRowWeight/RowColumnWeight is nonzero.
	--]]
	if not SquareContainerRequired then
		if not Sum(params.RowWeights)==0 then
			local AltProportion = Sum(params.ColumnRowWeights) / Sum(params.RowWeights);
			if Sum(params.RowWeights)==0 then
				AltProportion = 0;
			end
			if XMiddle then
				pos = pos + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, 0, 0) - UDim2.new(0, AltProportion*(size.Y.Offset-Sum(params.RowHeights))/2 + Sum(params.ColumnWidths)/2 + params.Cushion.x*(#params.ColumnWidths-1)/2, 0, 0);
			elseif XRight then
				pos = pos + UDim2.new(size.X.Scale, size.X.Offset, 0, 0) - UDim2.new(0, AltProportion*(size.Y.Offset-Sum(params.RowHeights)) + Sum(params.ColumnWidths) + params.Cushion.x*(#params.ColumnWidths-1), 0, 0);
			end
		end
		if not Sum(params.ColumnWeights)==0 then
			local AltProportion = Sum(params.RowColumnWeights) / Sum(params.ColumnWeights);
			if Sum(params.ColumnWeights)==0 then
				AltProportion = 0;
			end
			if YMiddle then
				pos = pos + UDim2.new(0, 0, size.Y.Scale / 2, size.Y.Offset / 2) - UDim2.new(0, 0, 0, AltProportion*(size.X.Offset-Sum(params.ColumnWidths))/2 + Sum(params.RowHeights)/2 + params.Cushion.y*(#params.RowHeights-1)/2);
			elseif YBottom then
				pos = pos + UDim2.new(0, 0, size.Y.Scale, size.Y.Offset) - UDim2.new(0, 0, 0, AltProportion*(size.X.Offset-Sum(params.ColumnWidths)) + Sum(params.RowHeights) + params.Cushion.y*(#params.RowHeights-1));
			end
		end
	end
	if self._AlwaysUseFrame or SquareContainerRequired then
		self:_EnableHandle(true);
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;

		--If Gravity = Right or Bottom and a square container is used, said container should be to the right or below the target space, respectively. The position should be determined by the amount of used space.
			--E.g., Gravity = BottomRight, Sum(ColumnRowWeights) = 3, Sum(RowWeights) = 1, Sum(ColumnWidths) = 45, Sum(RowHeights) = 15, pos = pos + size + UDim2.new(-3, -45, -1, -15).
		if SquareContainerRequired then
			if XRight then
				pos = pos + UDim2.new(size.X.Scale, size.X.Offset, 0, 0);
			elseif XMiddle then
				pos = pos + UDim2.new(size.X.Scale/2, size.X.Offset/2, 0, 0);
			end
			if YMiddle then
				pos = pos + UDim2.new(0, 0, size.Y.Scale/2, size.Y.Offset/2);
			elseif YBottom then
				pos = pos + UDim2.new(0, 0, size.Y.Scale, size.Y.Offset);
			end
			if RelativeYY then
				self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeYY;
				size = UDim2.new(size.Y.Scale, size.Y.Offset, size.Y.Scale, size.Y.Offset);
			elseif RelativeXX then
				self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXX;
				size = UDim2.new(size.X.Scale, size.X.Offset, size.X.Scale, size.X.Offset);
			end
		end
		self._Handle.Position = pos;
		self._Handle.Size = size;
		local size = UDim2.new(1, 0, 1, 0);
		--if pixel counts are known, maintain them. They are quite helpful.
		if self._Handle.Size.X.Scale==0 then
			size = UDim2.new(0, self._Handle.Size.X.Offset, size.Y.Scale, size.Y.Offset);
		end
		if self._Handle.Size.Y.Scale==0 then
			size = UDim2.new(size.X.Scale, size.X.Offset, 0, self._Handle.Size.Y.Offset);
		end
		local pos = UDim2.new();
		if SquareContainerRequired then
			if XRight and RelativeYY then
				pos = pos - UDim2.new(Sum(params.ColumnRowWeights) / Sum(params.RowWeights), Sum(params.ColumnWidths), 0, 0);
			elseif XMiddle and RelativeYY then
				pos = pos - UDim2.new(Sum(params.ColumnRowWeights) / Sum(params.RowWeights) / 2, Sum(params.ColumnWidths) / 2, 0, 0);
			elseif XRight and RelativeXX then
				pos = pos - UDim2.new(1, 0, 0, 0);
			elseif XMiddle and RelativeXX then
				pos = pos - UDim2.new(0.5, 0, 0, 0);
			end
			if YBottom and RelativeXX then
				pos = pos - UDim2.new(0, 0, Sum(params.RowColumnWeights) / Sum(params.ColumnWeights), Sum(params.RowHeights));
			elseif YMiddle and RelativeXX then
				pos = pos - UDim2.new(0, 0, Sum(params.RowColumnWeights) / Sum(params.ColumnWeights) / 2, Sum(params.RowHeights) / 2);
			elseif YBottom and RelativeYY then
				pos = pos - UDim2.new(0, 0, 1, 0);
			elseif YMiddle and RelativeYY then
				pos = pos - UDim2.new(0, 0, 0.5, 0);
			end
		end


		Utils.GridLayout(params, children, pos, size);
	else
		--If we are not supposed to use all the weight we are given, modify the position based the amount of space we need & gravity.
		if Sum(params.ColumnWeights)==0 then
			if XRight then
				pos = pos + UDim2.new(size.X.Scale, size.X.Offset, 0, 0) - UDim2.new(0, Sum(params.ColumnWidths) + params.Cushion.x * (#params.ColumnWidths - 1), 0, 0);
			elseif XMiddle then
				pos = pos + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, 0, 0) - UDim2.new(0, (Sum(params.ColumnWidths) + params.Cushion.x * (#params.ColumnWidths - 1)) / 2, 0, 0);
			end
		end
		if Sum(params.RowWeights)==0 then
			if YBottom then
				pos = pos + UDim2.new(0, 0, size.Y.Scale, size.Y.Offset) - UDim2.new(0, 0, 0, Sum(params.RowHeights) + params.Cushion.y * (#params.RowHeights - 1));
			elseif YMiddle then
				pos = pos + UDim2.new(0, 0, size.Y.Scale / 2, size.Y.Offset / 2) - UDim2.new(0, 0, 0, (Sum(params.RowHeights) + params.Cushion.y * (#params.RowHeights - 1)) / 2);
			end
		end

		self:_EnableHandle(false);
		Utils.GridLayout(params, children, pos, size);
	end
end

--[[ @brief Organizes the parameters and passes them to the Layout function.
	
--]]
function GridLayout:_Reflow(pos, size)
	Gui.Log.Reflow("GridLayout._Reflow(%s, %s, %s) called", self, pos, size);
	GridLayoutLog("GridLayout._Reflow(%s, %s, %s) called", self, pos, size);

	--Sometimes we change pos, size when it is necessary to have exact pixel information.
	--This causes errors elsewhere.
	--Scale might be more trouble than it's worth. Screen sizes don't change very often.

	local children = {};
	local params = {};
	local grid = PlacementGrid.new();
	grid.MinimumSize = self._MinimumSize;
	grid.FillDirection = self._GrowthDirection.Name;
	grid.AnchorLocation = self._AnchorLocation.Value - 1;
	for i, v in pairs(self:GetChildren()) do
		local paramTable = self._ChildLayoutParams[v] or v.LayoutParams or {};
		local x, y, width, height = paramTable.X or 0, paramTable.Y or 0, paramTable.Width or 1, paramTable.Height or 1;
		if x==0 or y==0 then
			grid:RegisterUnknownLocation(v, width, height);
		else
			grid:RegisterKnownLocation(v, x, y, width, height);
		end
	end
	for i, v in pairs(self:GetChildren()) do
		local paramTable = self._ChildLayoutParams[v] or v.LayoutParams or {};
		local width, height = paramTable.Width or 1, paramTable.Height or 1;
		local pos = grid:FetchLocation(v);
		table.insert(children, {v, pos.x, pos.y, width, height});
	end
	params.GridSize = grid.Size;

	params.ColumnWidths = {};
	params.ColumnWeights = {};
	params.ColumnRowWeights = {};
	params.RowHeights = {};
	params.RowWeights = {};
	params.RowColumnWeights = {};
	ResizeArrayFromSource(params.ColumnWidths, params.GridSize.x, self._ColumnWidths);
	--If FillX = false, Sum(ColumnWeights) should be set to 0.
	ResizeArrayFromSource(params.ColumnWeights, params.GridSize.x, self._FillXAlt and self._ColumnWeights or {0});
	ResizeArrayFromSource(params.ColumnRowWeights, params.GridSize.x, self._FillYAlt and self._ColumnRowWeights or {0});
	ResizeArrayFromSource(params.RowHeights, params.GridSize.y, self._RowHeights);
	--If FillY = false, Sum(RowWeights) should be set to 0.
	ResizeArrayFromSource(params.RowWeights, params.GridSize.y, self._FillYAlt and self._RowWeights or {0});
	ResizeArrayFromSource(params.RowColumnWeights, params.GridSize.y, self._FillXAlt and self._RowColumnWeights or {0});
	params.Cushion = self._Cushion;

	--Under no circumstances may ColumnRowWeights & RowColumnWeights be defined together.
	Log.Assert(Sum(self._ColumnRowWeights)==0 or Sum(self._RowColumnWeights)==0, "ColumnRowWeights and RowColumnWeights may not both be defined.");

	--If ColumnRowWeights is used, Sum(RowWeights) must not be 0.
	Log.Assert(Sum(self._ColumnRowWeights)==0 or Sum(self._RowWeights)~=0, "ColumnRowWeights cannot be defined if RowWeights is not.");
	Log.Assert(Sum(self._RowColumnWeights)==0 or Sum(self._ColumnWeights)~=0, "RowColumnWeights cannot be defined if ColumnWeights is not.");

	--If ColumnRowWeights & ColumnWeights are used, y scale should be 0.
	if Sum(self._ColumnRowWeights)~=0 and Sum(self._ColumnWeights)~=0 and size.Y.Scale~=0 then
		self:_EnableHandle(true);
		self._Handle.Size = size;
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		size = UDim2.new(size.X.Scale, size.X.Offset, 0, self._Handle.AbsoluteSize.y);
		--Update PlacementSize as well.
		self._Handle.Size = self._PlacementSize;
		self._PlacementSize = UDim2.new(self._PlacementSize.X.Scale, self._PlacementSize.X.Offset, 0, self._Handle.AbsoluteSize.y);
		self:_EnableHandle(false);
	end
	if Sum(self._RowColumnWeights)~=0 and Sum(self._RowWeights)~=0 and size.X.Scale~=0 then
		self:_EnableHandle(true);
		self._Handle.Size = size;
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		self._PlacementSize = UDim2.new(0, self._Handle.AbsoluteSize.x, size.Y.Scale, size.Y.Offset);
		size = UDim2.new(0, self._Handle.AbsoluteSize.x, size.Y.Scale, size.Y.Offset);
		--Update PlacementSize as well.
		self._Handle.Size = self._PlacementSize;
		self._PlacementSize = UDim2.new(0, self._Handle.AbsoluteSize.x, self._PlacementSize.Y.Scale, self._PlacementSize.Y.Offset);
		self:_EnableHandle(false);
	end
	Log.Assert(not (Sum(self._ColumnRowWeights)~=0 and Sum(self._ColumnWeights)~=0 and size.Y.Scale~=0), "ColumnRowWeights and ColumnWeights may not both be defined if size has a y scale component.");
	Log.Assert(not (Sum(self._RowColumnWeights)~=0 and Sum(self._RowWeights)~=0 and size.X.Scale~=0), "RowColumnWeights and RowWeights may not both be defined if size has an x scale component.");

	local RelativeYY = size.Y.Scale~=0 and Sum(self._ColumnRowWeights)~=0;
	local RelativeXX = size.X.Scale~=0 and Sum(self._RowColumnWeights)~=0
	local SquareContainerRequired = RelativeYY or RelativeXX;
	local XMiddle = self._Gravity == Gui.Enum.ViewGravity.Center or self._Gravity == Gui.Enum.ViewGravity.TopCenter or self._Gravity == Gui.Enum.ViewGravity.BottomCenter;
	local XRight = self._Gravity == Gui.Enum.ViewGravity.CenterRight or self._Gravity == Gui.Enum.ViewGravity.TopRight or self._Gravity == Gui.Enum.ViewGravity.BottomRight;
	local YMiddle = self._Gravity == Gui.Enum.ViewGravity.Center or self._Gravity == Gui.Enum.ViewGravity.CenterLeft or self._Gravity == Gui.Enum.ViewGravity.CenterRight;
	local YBottom = self._Gravity == Gui.Enum.ViewGravity.BottomLeft or self._Gravity == Gui.Enum.ViewGravity.BottomCenter or self._Gravity == Gui.Enum.ViewGravity.BottomRight;
	--[[ Conditions in which we would want to enable a handle:
			* AlwaysUseFrame is true.
			* Size is given by Scale & ColumnRowWeight/RowColumnWeight is nonzero.
	--]]
	if self._AlwaysUseFrame or SquareContainerRequired then
		self:_EnableHandle(true);
		self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXY;

		--If Gravity = Right or Bottom and a square container is used, said container should be to the right or below the target space, respectively. The position should be determined by the amount of used space.
			--E.g., Gravity = BottomRight, Sum(ColumnRowWeights) = 3, Sum(RowWeights) = 1, Sum(ColumnWidths) = 45, Sum(RowHeights) = 15, pos = pos + size + UDim2.new(-3, -45, -1, -15).
		if SquareContainerRequired then
			if XRight then
				pos = pos + UDim2.new(size.X.Scale, size.X.Offset, 0, 0);
			elseif XMiddle then
				pos = pos + UDim2.new(size.X.Scale/2, size.X.Offset/2, 0, 0);
			end
			if YMiddle then
				pos = pos + UDim2.new(0, 0, size.Y.Scale/2, size.Y.Offset/2);
			elseif YBottom then
				pos = pos + UDim2.new(0, 0, size.Y.Scale, size.Y.Offset);
			end
			if RelativeYY then
				self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeYY;
				size = UDim2.new(size.Y.Scale, size.Y.Offset, size.Y.Scale, size.Y.Offset);
			elseif RelativeXX then
				self._Handle.SizeConstraint = Enum.SizeConstraint.RelativeXX;
				size = UDim2.new(size.X.Scale, size.X.Offset, size.X.Scale, size.X.Offset);
			end
		end
		self._Handle.Position = pos;
		self._Handle.Size = size;
		size = UDim2.new(1, 0, 1, 0);
		--if pixel counts are known, maintain them. They are quite helpful.
		if self._Handle.Size.X.Scale==0 then
			size = UDim2.new(0, self._Handle.Size.X.Offset, size.Y.Scale, size.Y.Offset);
		end
		if self._Handle.Size.Y.Scale==0 then
			size = UDim2.new(size.X.Scale, size.X.Offset, 0, self._Handle.Size.Y.Offset);
		end
		pos = UDim2.new();
		if SquareContainerRequired then
			if XRight then
				pos = pos - UDim2.new(size.X.Scale, size.X.Offset, 0, 0);
			elseif XMiddle then
				pos = pos - UDim2.new(size.X.Scale / 2, size.X.Offset / 2, 0, 0);
			end
			if YBottom then
				pos = pos - UDim2.new(0, 0, size.Y.Scale, size.Y.Offset);
			elseif YMiddle then
				pos = pos - UDim2.new(0, 0, size.Y.Scale / 2, size.Y.Offset / 2);
			end
		end
	else
		self:_EnableHandle(false);
	end

	local UtilizedSize = Gui.GridLayoutSize(params, size);
	if XRight then
		pos = pos + UDim2.new(size.X.Scale, size.X.Offset, 0, 0) - UDim2.new(UtilizedSize.X.Scale, UtilizedSize.X.Offset, 0, 0);
	elseif XMiddle then
		pos = pos + UDim2.new(size.X.Scale / 2, size.X.Offset / 2, 0, 0) - UDim2.new(UtilizedSize.X.Scale/2, UtilizedSize.X.Offset/2, 0, 0);
	end
	if YBottom then
		pos = pos + UDim2.new(0, 0, size.Y.Scale, size.Y.Offset) - UDim2.new(0, 0, UtilizedSize.Y.Scale, UtilizedSize.Y.Offset);
	elseif YMiddle then
		pos = pos + UDim2.new(0, 0, size.Y.Scale/2, size.Y.Offset/2) - UDim2.new(0, 0, UtilizedSize.Y.Scale/2, UtilizedSize.Y.Offset/2);
	end

	Utils.GridLayout(params, children, pos, size);
end

--[[ @brief Creates a new GridLayout.
     @return The created GridLayout.
--]]
function GridLayout.new()
	local self = setmetatable(View.new(), GridLayout.Meta);
	self._ChildLayoutParams = Gui.ChildProperties(GridLayout._ChildLayoutParams);
	self._ColumnWidths = {0};
	self._ColumnWeights = {1};
	self._ColumnRowWeights = {0};
	self._RowHeights = {0};
	self._RowWeights = {1};
	self._RowColumnWeights = {0};
	return self;
end

--[[ @brief Tests whether the Handle is properly instantiated in situations where it is needed.
--]]
function Test.GridLayout_Handle()
	local sgui = Instance.new("ScreenGui", game.StarterGui);
	sgui.Name = "GridLayout_Handle";
	local x = Gui.new("GridLayout");
	x.Name = "TestLayout";
	x.Parent = sgui;

	local child = Gui.wrap(Instance.new("Frame"), x);
	child.Name = "Frame0";
	child.Size = UDim2.new(0, 200, 0, 200);
	x.AlwaysUseFrame = false;
	wait();
	Log.AssertEqual("GridLayout's Handle", false, not not x._Handle);
	Log.AssertEqual("child handle's Parent", sgui, child._Handle.Parent);
	x.AlwaysUseFrame = true;
	wait();
	Log.AssertEqual("GridLayout's Handle", true, not not x._Handle);
	Log.AssertEqual("child handle's Parent", x._Handle, child._Handle.Parent);

	for i = 1, 2 do
		local y = Gui.wrap(Instance.new("Frame"), x);
		y.Name = "Frame" .. tostring(i);
		y.Size = UDim2.new(1, 0, 1, 0);
	end
end

--[[ @brief Tests to make sure the grid lays out its elements correctly.
     @details Tests the basic layout, tests adding cushioning between elements, tests
         providing absolute pixel values, and tests maintaining an aspect ratio.
--]]
function Test.GridLayout_Flow()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "GridLayout_Flow";
	local view = Gui.new("View", sgui);
	view.FillX = false;
	view.FillY = false;
	view.MinimumX = 100;
	view.MinimumY = 100;
	local x = Gui.new("GridLayout", view);
	x.MinimumGridDimensions = Vector2.new(4, 4);
	x.Size = UDim2.new(1, 0, 1, 0);
	local y = Gui.new("Frame", x);
	y.LayoutParams = {X=3, Y=2, Width=1, Height=1};
	y.Name = "FlowTest";
	sgui:ForceReflow();
	view:ForceReflow();
	x:ForceReflow();
	y:ForceReflow();
	Log.AssertEqual("Frame position (defined column/row weights)", Vector2.new(50, 25), y.AbsolutePosition);
	Log.AssertEqual("Frame size (defined column/row weights)", Vector2.new(25, 25), y.AbsoluteSize);
	Log.AssertEqual("Frame size", y.AbsoluteSize, y._Handle.AbsoluteSize);
	x.Cushion = Vector2.new(8, 8);
	wait();
	Log.AssertEqual("Frame position (defined column/row weights, cushion)", Vector2.new(54, 27), y.AbsolutePosition);
	Log.AssertEqual("Frame size (defined column/row weights, cushion)", Vector2.new(19, 19), y.AbsoluteSize);
	x.Cushion = Vector2.new(0, 0);
	x.ColumnWidths = {10, 20, 30, 40};
	x.RowHeights = {10, 20, 30, 40};
	wait();
	Log.AssertEqual("Frame position (defined column/row weights/pixels)", Vector2.new(30, 10), y.AbsolutePosition);
	Log.AssertEqual("Frame size (defined column/row weights/pixels)", Vector2.new(30, 20), y.AbsoluteSize);
	x.ColumnWidths = {0};
	x.RowHeights = {0};
	x.RowColumnWeights = {1};
	x.RowWeights = {0};
	x.Size = UDim2.new(0, 400, 0, 500);
	wait();
	Log.AssertEqual("Frame position (defined column weights, row column weights)", UDim2.new(0, 200, 0, 100), y._Handle.Position);
	Log.AssertEqual("Frame size (defined column weights, row column weights)", UDim2.new(0, 100, 0, 100), y._Handle.Size);
	x.Size = UDim2.new(1, 0, 1, 0);
	wait();
	local QuarterScreenWidth = Round(x.AbsoluteSize.x/4);
	local HalfScreenWidth = Round(x.AbsoluteSize.x/2);
	Log.AssertEqual("Frame position (defined column weights, row column weights)", Vector2.new(HalfScreenWidth, QuarterScreenWidth), y.AbsolutePosition);
	Log.AssertEqual("Frame size (defined column weights, row column weights)", Vector2.new(QuarterScreenWidth, QuarterScreenWidth), y.AbsoluteSize);
	--Just make a nice checkerboard to close it out.
	Gui.new("Frame", x).LayoutParams = {X=1, Y=2};
	Gui.new("Frame", x).LayoutParams = {X=1, Y=4};
	Gui.new("Frame", x).LayoutParams = {X=2, Y=1};
	Gui.new("Frame", x).LayoutParams = {X=2, Y=3};
	Gui.new("Frame", x).LayoutParams = {X=3, Y=4};
	Gui.new("Frame", x).LayoutParams = {X=4, Y=1};
	Gui.new("Frame", x).LayoutParams = {X=4, Y=3};
end

--[[ @brief Slowly inserts new elements to fill up rows/columns first. Requires visual inspection.
--]]
function Test.GridLayout_Progression()
	local sg = Instance.new("ScreenGui", game.StarterGui);
	local g = Gui.new("GridLayout", sg);
	g.Size = UDim2.new(0, 300, 0, 300);
	g.MinimumGridDimensions = Vector2.new(4, 4);
	g.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Horizontal;
	for i = 1, 20 do
		local f = Gui.new("Frame", g);
		f._Handle.Size = UDim2.new(0, 0, 0, 0);
		f.BackgroundColor3 = Color3.new(math.random(), math.random(), math.random());
		wait();
	end
	g:ClearAllChildren()
	g.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;
	for i = 1, 20 do
		local f = Gui.new("Frame", g);
		f._Handle.Size = UDim2.new(0, 0, 0, 0);
		f.BackgroundColor3 = Color3.new(math.random(), math.random(), math.random());
		wait();
	end
end

--[[ @brief Tests whether children are properly positioned when gravity is specified.
--]]
function Test.GridLayout_Gravity()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_Gravity";
	local frame = Gui.new("Frame", sgui);
	frame.Name = "Frame";
	frame.MinimumX = 500;
	frame.MinimumY = 100;
	frame.FillX = false;
	frame.FillY = false;
	frame.Gravity = Gui.Enum.ViewGravity.Center;
	local layout = Gui.new("GridLayout", frame);
	layout.Name = "MyGridLayout";
	layout.MinimumGridDimensions = Vector2.new(1, 1);
	layout.RowWeights = {1};
	layout.ColumnRowWeights = {1};
	layout.ColumnWeights = {0};
	layout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Horizontal;
	layout.Margin = 10;
	local elements = {};
	for i = 1, 3 do
		local f = Gui.new("Frame");
		f.Name = "GridElement"..tostring(i);
		f.BackgroundColor3 = Color3.fromHSV((i-1)/5, 1, 1);
		f.Parent = layout;
		table.insert(elements, f);
	end

	--For each gravity, we must:
	--ensure all tiles are approximately square.
	--ensure the left tile is very close to left, the right tile is very close to right, or the middle tile is central.
	layout.Gravity = Gui.Enum.ViewGravity.TopLeft;
	local T = 0;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[1];
	local current = x.AbsolutePosition.x;
	local desired = frame.AbsolutePosition.x + 10;
	Log.AssertAlmostEqual("frame.AbsolutePosition.x+10", desired, 2, current);
	Log.AssertAlmostEqual("y position", frame.AbsolutePosition.y + 10, 1, x.AbsolutePosition.y);

	layout.Gravity = Gui.Enum.ViewGravity.Center;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[2];
	local current = x.AbsolutePosition.x + x.AbsoluteSize.x/2;
	local desired = frame.AbsolutePosition.x + frame.AbsoluteSize.x/2;
	Log.AssertAlmostEqual("elements[2].Position", desired, 2, current);
	Log.AssertEqual("y position", frame.AbsolutePosition.y + 10, x.AbsolutePosition.y);

	layout.Gravity = Gui.Enum.ViewGravity.BottomRight;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[3];
	local current = x.AbsolutePosition.x + x.AbsoluteSize.x;
	local desired = frame.AbsolutePosition.x + frame.AbsoluteSize.x - 10;
	Log.Assert(math.abs(current - desired) < 2, "%s position expected to be %s, got %s", x, desired, current);
	Log.AssertEqual("y position", frame.AbsolutePosition.y + 10, x.AbsolutePosition.y);

	--
	-- Switch to making the parent class more vertical than horizontal.
	--

	frame.MinimumX = 110;
	frame.MinimumY = 500;
	layout.RowWeights = {0};
	layout.RowColumnWeights = {1};
	layout.ColumnWeights = {1};
	layout.ColumnRowWeights = {0};
	layout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;

	layout.Gravity = Gui.Enum.ViewGravity.TopCenter;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[1];
	local current = x.AbsolutePosition.y;
	local desired = frame.AbsolutePosition.y + 10;
	Log.Assert(math.abs(current - desired) < 2, "%s position expected to be %s, got %s", x, desired, current);
	Log.AssertEqual("x position", frame.AbsolutePosition.x + 10, x.AbsolutePosition.x);

	layout.Gravity = Gui.Enum.ViewGravity.CenterRight;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[2];
	local current = x.AbsolutePosition.y + x.AbsoluteSize.y/2;
	local desired = frame.AbsolutePosition.y + frame.AbsoluteSize.y/2;
	Log.Assert(math.abs(current - desired) < 2, "%s's center position expected to be %s, got %s", x, desired, current);
	Log.AssertEqual("x position", frame.AbsolutePosition.x + 10, elements[1].AbsolutePosition.x);

	layout.Gravity = Gui.Enum.ViewGravity.BottomLeft;
	wait(T);
	for _, x in pairs(elements) do
		Log.Assert(math.abs(x.AbsoluteSize.x / x.AbsoluteSize.y - 1) < 0.02, "Aspect ratio for %s expected to be 1; got %s", x, x.AbsoluteSize.x / x.AbsoluteSize.y);
	end
	local x = elements[3];
	local current = x.AbsolutePosition.y + x.AbsoluteSize.y;
	local desired = frame.AbsolutePosition.y + frame.AbsoluteSize.y - 10;
	Log.Assert(math.abs(current - desired) < 2, "%s position expected to be %s, got %s", x, desired, current);
	Log.AssertEqual("x position", frame.AbsolutePosition.x + 10, elements[1].AbsolutePosition.x);



	--Below requires a visual inspection.
--	frame.MinimumX = 500;
--	frame.MinimumY = 100;
--	layout.RowWeights = {1};
--	layout.RowColumnWeights = {0};
--	layout.ColumnWeights = {0};
--	layout.ColumnRowWeights = {1};
--	layout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Horizontal;
--	for i = 1, 9 do
--		layout.Gravity = i;
--		wait(.5);
--	end
--	frame.MinimumX = 100;
--	frame.MinimumY = 500;
--	layout.RowWeights = {0};
--	layout.RowColumnWeights = {1};
--	layout.ColumnWeights = {1};
--	layout.ColumnRowWeights = {0};
--	layout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;
--	for i = 1, 9 do
--		layout.Gravity = i;
--		wait(.5);
--	end
end

--[[ @brief Tests whether children are properly positioned when gravity is specified & pixel information is the only thing used.
--]]
function Test.GridLayout_GravityPixels()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "GridLayout_GravityPixels";
	local frame = Gui.new("Frame", sgui);
	frame.MinimumX = 500;
	frame.MinimumY = 100;
	frame.FillX = false;
	frame.FillY = false;
	frame.Gravity = Gui.Enum.ViewGravity.Center;
	local layout = Gui.new("GridLayout", frame);
	layout.MinimumGridDimensions = Vector2.new(1, 1);
	layout.RowWeights = {0};
	layout.ColumnRowWeights = {0};
	layout.ColumnWeights = {0};
	layout.RowHeights = {20};
	layout.ColumnWidths = {20};
	layout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Horizontal;
	layout.Margin = 10;
	layout.Cushion = Vector2.new(10, 10);
	local elements = {};
	for i = 1, 3 do
		local f = Gui.new("Frame", layout);
		f.BackgroundColor3 = Color3.fromHSV((i-1)/5, 1, 1);
		table.insert(elements, f);
	end
	wait();
	layout.Gravity = Gui.Enum.ViewGravity.BottomLeft;
	Gui.RecursiveRefresh(sgui);
	Log.AssertEqual("Left Border", 10, elements[1].AbsolutePosition.x - frame.AbsolutePosition.x);
	Log.AssertEqual("Bottom Border", frame.AbsolutePosition.y + frame.AbsoluteSize.y - 10, elements[1].AbsolutePosition.y + elements[1].AbsoluteSize.y);
	layout.Gravity = Gui.Enum.ViewGravity.BottomRight;
	Gui.RecursiveRefresh(sgui);
	Log.AssertEqual("Right Border", frame.AbsolutePosition.x + frame.AbsoluteSize.x - 10, elements[3].AbsolutePosition.x + elements[3].AbsoluteSize.x);
	Log.AssertEqual("Bottom Border", frame.AbsolutePosition.y + frame.AbsoluteSize.y - 10, elements[1].AbsolutePosition.y + elements[1].AbsoluteSize.y);
	layout.ColumnWidths = {0};
	layout.RowWeights = {1};
	layout.ColumnRowWeights = {.5};
	Gui.RecursiveRefresh(sgui);
	Log.AssertEqual("Right Border", frame.AbsolutePosition.x + frame.AbsoluteSize.x - 10, elements[3].AbsolutePosition.x + elements[3].AbsoluteSize.x);
	Log.AssertEqual("Bottom Border", frame.AbsolutePosition.y + frame.AbsoluteSize.y - 10, elements[1].AbsolutePosition.y + elements[1].AbsoluteSize.y);
	layout.RowHeights = {0};
	Gui.RecursiveRefresh(sgui);
	Log.AssertEqual("Right Border", frame.AbsolutePosition.x + frame.AbsoluteSize.x - 10, elements[3].AbsolutePosition.x + elements[3].AbsoluteSize.x);
	Log.AssertEqual("Bottom Border", frame.AbsolutePosition.y + frame.AbsoluteSize.y - 10, elements[1].AbsolutePosition.y + elements[1].AbsoluteSize.y);
	Log.AssertEqual("AspectRatio", 0.5, elements[1].AbsoluteSize.x/elements[1].AbsoluteSize.y);
end

return GridLayout;
