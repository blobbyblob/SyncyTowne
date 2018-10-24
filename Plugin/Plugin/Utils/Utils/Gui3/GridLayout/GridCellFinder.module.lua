--[[

GridCellFinder will find proper cell locations to fit elements. No ordering is guaranteed.

Create a grid, set properties:
	- AnchorLocation (number): a value from 0 to 3 where 0 is the top left, 1 is top right, 2 is bottom left, and 3 is bottom right.
	- FillDirection (string): a value of "Vertical" or "Horizontal" which indicates whether columns are filled first or rows.
	- MinimumSize (Vector2): a pair of values which indicate the minimum size of the grid.
	- Size (Vector2): a pair of values which indicate the actual size of the grid. This should be called after registering all elements.

	Call methods RegisterKnownLocation(index, x, y, width, height) to indicate that a certain element
must be in a particular location. RegisterUnknownLocation(index, width, height) will indicate a certain
element can be placed anywhere.
	The argument "index" should represent a unique index for each element. This can be any value
except for 'nil', and should be unique among all elements (unless you are intentionally overwriting a
previous registry).

	If the location is known, the x/y coordinates will always represent distance from the origin. For
example, if AnchorLocation is 1 (top right), the coordinate <1, 1> represents the top-right corner.

	When all elements are registered, one can read out grid locations (absolute where <1, 1>
represents the top left) through calls to FetchLocation(index).

*********

Summary
	Properties
		AnchorLocation (number)
		FillDirection (string)
		MinimumSize (Vector2)
		Size (Vector2, read only)
	Methods
		RegisterKnownLocation(index, x, y, width, height)
		RegisterUnknownLocation(index, width, height)
		FetchLocation(index)
--]]

local Utils = require(script.Parent.Parent.Parent);
local Log = Utils.Log;
local Gui = require(script.Parent.Parent);
local Test = Gui.Test;

--[[ PlacementGrid Helper Class
	The following class helps to find open spaces to place elements into a grid. An instance may specify whether the columns or rows should be filled in first. Additionally, it may specify in which corner element (1, 1) is placed.
--]]
PlacementGrid = Utils.new("Class", "PlacementGrid");

--[[ Grid Helper Class
	The following function helps to locate open cell locations where an element may be placed. The class makes the assumption that we grow from top to bottom filling in a row as best as possible before moving to the next one.
--]]
Grid = Utils.new("Class", "Grid"); do
	Grid._Area = false;
	Grid._Height = 0;
	Grid._Width = 1;
	--[[ @brief States that the cells from (x, y) to (x+width-1, y+height-1) are occupied.
	--]]
	function Grid:OccupySpace(x, y, width, height)
		if self._Height < y + (height or 1) - 1 then
			self._Height = y + (height or 1) - 1;
		end
		for i = 0, (width or 1)-1 do
			for j = 0, (height or 1)-1 do
				if self._Area[x+i]==nil then
					self._Area[x+i] = {};
				end
				self._Area[x+i][y+j] = true;
			end
		end
	end
	--[[ @brief Finds the next available space to occupy.
	     @param width The number of consecutive cells across which are needed.
	     @param height The number of consecutive cells down which are needed.
	     @return x The x location of the cell. If width>1, this represents the left-most cell.
	     @return y The y location of the cell. If height>1, this represents the top-most cell.
	--]]
	function Grid:GetSpace(width, height)
		Log.Assert(self._Width >= width, "Not enough width to place element; need %s, got %s", self._Width, width);
		for y = 1, math.huge, 1 do
			for x = 1, self._Width - width + 1 do
				local PositionIsVacant = true;
				for i = 0, width - 1 do
					for j = 0, height - 1 do
						if self._Area[x+i][y+j] then
							PositionIsVacant = false;
							break;
						end
					end
					if not PositionIsVacant then break; end
				end
				if PositionIsVacant then
					return x, y;
				end
			end
		end
	end
	--[[ @brief Returns the necessary height of the grid.
	--]]
	function Grid:GetHeight()
		return self._Height;
	end
	--[[ @brief Create a grid which finds a good position to place a cluster of cells.
	     @param width The width of the grid.
	     @details The height of the grid is as large as it needs to be in order to fit all elements. Elements will fill in a complete row before moving on to the next. For example, if you sequentially call grid:OccupySpace(grid:GetSpace(1, 1)) where grid = Grid.new(5), the resulting grid will look like the following.
	         ___________________
	         |  1  |  2  |  3  |  4  |   5 |
	         |___|___|___|___|___|
	         |  6  |  7  |  8  |  9  | 10 |
	         |___|___|___|___|___|
	--]]
	function Grid.new(width)
		local self = setmetatable({}, Grid.Meta);
		self._Area = {};
		for i = 1, width do
			self._Area[i] = {};
		end
		self._Width = width;
		self._Height = 0;
		return self;
	end
	
	function Test.Grid_Sequence()
		local grid = Grid.new(5);
		Log.AssertEqual("empty height", 0, grid:GetHeight());
		local x, y = grid:GetSpace(1, 1);
		Log.AssertEqual("first cell", Vector2.new(1, 1), Vector2.new(x, y));
		grid:OccupySpace(x, y, 1, 1);
		local x, y = grid:GetSpace(1, 1);
		Log.AssertEqual("second cell", Vector2.new(2, 1), Vector2.new(x, y));
		grid:OccupySpace(x, y, 1, 1);
		grid:OccupySpace(3, 1, 3, 2);
		local x, y = grid:GetSpace(1, 1);
		Log.AssertEqual("third cell", Vector2.new(1, 2), Vector2.new(x, y));
		grid:OccupySpace(x, y, 1, 1);
		local x, y = grid:GetSpace(2, 1);
		Log.AssertEqual("fourth cell", Vector2.new(1, 3), Vector2.new(x, y));
		grid:OccupySpace(x, y, 2, 1);
		Log.AssertEqual("filled height", 3, grid:GetHeight());
	end
end

PlacementGrid._Registry = false;
PlacementGrid._Ordering = false;
PlacementGrid._AnchorLocation = 0;
PlacementGrid._FillDirection = "Vertical";
PlacementGrid._Finalized = false;
PlacementGrid._MinimumSize = Vector2.new(1, 1);
PlacementGrid._Size = Vector2.new(1, 1);

--[[ @brief Set the location to be "filled".
     @param index A unique key to prescribe to this object.
     @param x The x location where the cell occupation occurs.
     @param y The y location where the cell occupation occurs.
     @param width The number of cells which are occupied (horizontally).
     @param height The number of cells which are occupied (vertically).
--]]
function PlacementGrid:RegisterKnownLocation(index, x, y, width, height)
	Log.Assert(not self._Finalized, "Attempt to register element after finalization");
	self._Registry[index] = {x, y, width, height};
	table.insert(self._Ordering, index);
end

--[[ @brief Find and fill a location.
     @param index A unique key by which to recognize this object.
     @param width The number of horizontal cells we should find.
     @param height The number of vertical cells we should find.
--]]
function PlacementGrid:RegisterUnknownLocation(index, width, height)
	Log.Assert(not self._Finalized, "Attempt to register element after finalization");
	self._Registry[index] = {0, 0, width, height};
	table.insert(self._Ordering, index);
end

--[[ @brief Returns the (x, y) coordinate where the element represented by index should be placed.
     @param index A unique key by which to recognize this object.
     @return A Vector2 value where the element should be placed. A value of (1, 1) always represents the top-left.
--]]
function PlacementGrid:FetchLocation(index)
	if not self._Finalized then
		self:Finalize();
	end
	local x, y, width, height = unpack(self._Registry[index]);
	
	--Flip x/y across the grid if the anchor location is on the opposite side.
	if self._AnchorLocation % 2 == 1 then
		x = self._Size.x - x + 2 - width;
	end
	if self._AnchorLocation / 2 >= 1 then
		y = self._Size.y - y + 2 - height;
	end
	return Vector2.new(x, y);
end

--[[ @brief Determines the locations where all registered elements should go. This process is irreversible. After calling this function, no new elements can be registered.
--]]
function PlacementGrid:Finalize()
	Log.Assert(not self._Finalized, "PlacementGrid already finalized");
	self._Finalized = true;
	--if self._MinimumSize doesn't encompass all elements with explicit locations, update it.
	for i, v in pairs(self._Registry) do
		if v[2]~=0 then
			local x, y, width, height = unpack(v);
			if x+width-1 > self._MinimumSize.x or y+height-1 > self._MinimumSize.y then
				self._MinimumSize = Vector2.new(math.max(self._MinimumSize.x, x+width-1), math.max(self._MinimumSize.y, y+height-1));
			end
		end
	end
	local grid = Grid.new(self._FillDirection == "Vertical" and self._MinimumSize.x or self._MinimumSize.y);
	--Run through and block out all elements whose location is known.
	for i, v in pairs(self._Registry) do
		if v[2]~=0 then
			local x, y, width, height = unpack(v);
			if self._FillDirection ~= "Vertical" then
				width, height = height, width;
				x, y = y, x;
			end
			grid:OccupySpace(x, y, width, height);
		end
	end
	--Run through again and place all elements whose location is unknown.
	for j, i in pairs(self._Ordering) do
		local v= self._Registry[i];
		if v[1]==0 then
			local _, _, width, height = unpack(v);
			if self._FillDirection ~= "Vertical" then
				width, height = height, width;
			end
			local x, y = grid:GetSpace(width, height);
			grid:OccupySpace(x, y, width, height);
			if self._FillDirection ~= "Vertical" then
				x, y = y, x;
			end
			v[1], v[2] = x, y;
		end
	end
	--Get the size of the grid.
	if self._FillDirection=="Vertical" then
		self._Size = Vector2.new(self._MinimumSize.x, math.max(self._MinimumSize.y, grid:GetHeight()));
	else
		self._Size = Vector2.new(math.max(self._MinimumSize.x, grid:GetHeight()), self._MinimumSize.y);
	end
end

PlacementGrid.Get.MinimumSize = "_MinimumSize";
PlacementGrid.Get.FillDirection = "_FillDirection";
PlacementGrid.Get.AnchorLocation = "_AnchorLocation";
function PlacementGrid.Get:Size()
	if not self._Finalized then self:Finalize(); end
	return self._Size;
end
function PlacementGrid.Set:MinimumSize(v)
	Log.Assert(not self._Finalized, "attempt to set MinimumSize after finalizing grid");
	Log.AssertNonNilAndType("MinimumSize", "userdata", v);
	self._MinimumSize = v;
end
function PlacementGrid.Set:FillDirection(v)
	Log.Assert(not self._Finalized, "attempt to set FillDirection after finalizing grid");
	self._FillDirection = v;
end
function PlacementGrid.Set:AnchorLocation(v)
	Log.Assert(not self._Finalized, "attempt to set AnchorLocation after finalizing grid");
	self._AnchorLocation = v;
end

function PlacementGrid.new()
	return setmetatable({_Registry = {}; _Ordering = {}}, PlacementGrid.Meta);
end

function Test.PlacementGrid()
	local grid = PlacementGrid.new();
	grid.MinimumSize = Vector2.new(1, 2);
	grid.FillDirection = "Horizontal";
	grid.AnchorLocation = 3;
	grid:RegisterKnownLocation("x", 2, 1, 1, 1);
	for i = 1, 4 do
		grid:RegisterUnknownLocation(i, 1, 1);
	end
	Log.AssertEqual("grid size", Vector2.new(3, 2), grid.Size);
	Log.AssertEqual("cell x location", Vector2.new(2, 2), grid:FetchLocation('x'));
	Log.AssertEqual("cell 1 location", Vector2.new(3, 2), grid:FetchLocation(1));
	Log.AssertEqual("cell 2 location", Vector2.new(3, 1), grid:FetchLocation(2));
	Log.AssertEqual("cell 3 location", Vector2.new(2, 1), grid:FetchLocation(3));
	Log.AssertEqual("cell 4 location", Vector2.new(1, 2), grid:FetchLocation(4));
end
function Test.PlacementGrid_LargeCells()
	local grid = PlacementGrid.new();
	grid.FillDirection = "Vertical";
	grid.AnchorLocation = 1; --Top-right
	grid.MinimumSize = Vector2.new(2, 2);

	grid:RegisterKnownLocation("x", 1, 1, 1, 2);
	grid:RegisterUnknownLocation("y", 2, 2);
	
	Log.AssertEqual("grid size", Vector2.new(2, 4), grid.Size);
	Log.AssertEqual("cell x location", Vector2.new(2, 1), grid:FetchLocation('x'));
	Log.AssertEqual("cell y location", Vector2.new(1, 3), grid:FetchLocation('y'));
end

return PlacementGrid;