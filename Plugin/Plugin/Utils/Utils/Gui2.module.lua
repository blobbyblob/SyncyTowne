--[[

For testing, run the following command:
	local lib = game.ReplicatedStorage.lib:Clone(); require(lib.Gui).test();

Better:
require(game.ReplicatedStorage.lib_Source.Utils.SourceManagement:Clone()).RefreshDirectory(game.ReplicatedStorage.lib);
require(game.ReplicatedStorage.lib.Gui).Test();

--]]

local Utils = require(script.Parent);
local Test = Utils.new("TestRegistry");
local Log = Utils.Log;

function Test.BetweenFunction(beforeTest)
	wait(1);
	game.StarterGui:ClearAllChildren();
	local sgui = Instance.new("ScreenGui", game.StarterGui);
	sgui.Name = beforeTest;
	local cgui = Instance.new("ScreenGui", game.CoreGui);
	cgui.Name = beforeTest;
	sgui.AncestryChanged:connect(function()
		if sgui.Parent == nil then
			cgui.Parent = nil;
		end
	end)
	return sgui, cgui;
end

local Gui = {};
Gui.Log = {};
Gui.Test = Test;

Gui.Log.Debug = Log.new("", true);
Gui.Log.Parent = Log.new("Parent:\t", false);
Gui.Log.Reflow = Log.new("Reflow:\t", false);

local RegistryDebug = Log.new("Registry:\t", false);

----------------------
-- Common Functions --
----------------------
do
	function Gui.RecursiveRefresh(obj)
		obj:ForceReflow();
		for i, v in pairs(obj:GetChildren()) do
			Gui.RecursiveRefresh(v);
		end
	end
	function Gui.ReparentChildren(self)
		for _, self in pairs(Utils.Table.ShallowCopy(self:GetChildren())) do
			self.ParentNoNotify = self.Parent;
		end
	end

	local LayoutDebug = Utils.new("Log", "GridLayout: ", false);
	--[[ @brief Lays out children using the parameters of the GridLayout and children. All child parameters are expected to be defined.
	     @param GridParameters A set of parameters which define the grid. These are:
	         - GridSize: The number of cells in each direction.
	         - Cushion: a Vector2 value indicating the amount of space which should be placed between grid divisions.
	         - ColumnWidths: The number of pixels that each column should be given. There must be GridSize.x elements.
	         - ColumnWeights: The weight that each column should be given. This only applies to remaining area after ColumnWidths and ColumnRowWeights are considered. Note that if pixel information is unknown, setting ColumnWeights and ColumnRowWeights to nonzero values results in undefined behavior.
	         - ColumnRowWeights: The weight that each column should be given with respect to the amount of space given to a row of identical weight.
	         - RowHeights
	         - RowWeights
	         - RowColumnWeights
	
	         Note: ColumnWeights is incompatible with ColumnRowWeights if pixel information is unknown. ColumnRowWeights and RowColumnWeights are incompatible.
	     @param children An array of arrays wherein the inner arrays are of the form {Element, X, Y, Width, Height}.
	         - [1] Element: the child which is to have its pos/size set.
	         - [2] X: the x cell location of the element.
	         - [3] Y: The y cell location of the element.
	         - [4] Width: the number of cells which the element should occupy horizontally.
	         - [5] Height: the number of cells which the element should occupy vertically.
	         Note also that overlap will not be checked (two elements may occupy the same cell). If a cell exceeds GridSize, an error will occur.
	    @param pos A starting position for the grid.
	    @param size The size the grid may take up.
	--]]
	function Utils.GridLayout(GridParameters, Children, pos, size)
		LayoutDebug("Utils.GridLayout(%s, %s, %s, %s) called", GridParameters, Children, pos, size);
		LayoutDebug("    GridParameters:");
		LayoutDebug("        GridSize: %s", GridParameters.GridSize);
		LayoutDebug("        Cushion: %s", GridParameters.Cushion);
		LayoutDebug("        ColumnWidths: %t", GridParameters.ColumnWidths);
		LayoutDebug("        ColumnWeights: %t", GridParameters.ColumnWeights);
		LayoutDebug("        ColumnRowWeights: %t", GridParameters.ColumnRowWeights);
		LayoutDebug("        RowHeights: %t", GridParameters.RowHeights);
		LayoutDebug("        RowWeights: %t", GridParameters.RowWeights);
		LayoutDebug("        RowColumnWeights: %t", GridParameters.RowColumnWeights);
		LayoutDebug("    Children:");
		for i, v in pairs(Children) do
			LayoutDebug("        %s: {%s (element), %s (x), %s (y), %s (width), %s (height)}", i, unpack(v));
		end
	
		local gs = GridParameters.GridSize;
		Utils.Table.NormalizeArrayWithSatellite(GridParameters.ColumnWeights, GridParameters.RowColumnWeights);
		Utils.Table.NormalizeArrayWithSatellite(GridParameters.RowWeights, GridParameters.ColumnRowWeights);
		table.insert(GridParameters.ColumnWidths, 1, 0);
		table.insert(GridParameters.ColumnWeights, 1, 0);
		table.insert(GridParameters.ColumnRowWeights, 1, 0);
		table.insert(GridParameters.RowHeights, 1, 0);
		table.insert(GridParameters.RowWeights, 1, 0);
		table.insert(GridParameters.RowColumnWeights, 1, 0);
		Utils.Table.Accumulate(GridParameters.ColumnWidths, gs.x);
		Utils.Table.Accumulate(GridParameters.ColumnWeights, gs.x);
		Utils.Table.Accumulate(GridParameters.ColumnRowWeights, gs.x);
		Utils.Table.Accumulate(GridParameters.RowHeights, gs.y);
		Utils.Table.Accumulate(GridParameters.RowWeights, gs.y);
		Utils.Table.Accumulate(GridParameters.RowColumnWeights, gs.y);
		local ExcessPixelsX = size.X.Offset - GridParameters.ColumnWidths[gs.x+1] - GridParameters.Cushion.x * (gs.x - 1);
		local ExcessPixelsY = size.Y.Offset - GridParameters.RowHeights[gs.y+1] - GridParameters.Cushion.y * (gs.y - 1);
		local TotalRowColumnWeight = GridParameters.RowColumnWeights[gs.y+1];
		local TotalColumnRowWeight = GridParameters.ColumnRowWeights[gs.x+1];
		Log.Assert(TotalRowColumnWeight==0 or TotalColumnRowWeight==0, "Both RowColumnWeight and ColumnRowWeight may not be nonzero");
		Log.Assert(size.Y.Scale==0 or TotalColumnRowWeight==0 or GridParameters.ColumnWeights[gs.x], "Both ColumnRowWeight and ColumnWeight cannot be nonzero unless pixel information is known");
		Log.Assert(size.X.Scale==0 or TotalRowColumnWeight==0 or GridParameters.RowWeights[gs.y], "Both RowColumnWeight and RowWeight cannot be nonzero unless pixel information is known");
		if TotalRowColumnWeight ~= 0 then
			ExcessPixelsY = ExcessPixelsY - TotalRowColumnWeight * ExcessPixelsX;
		else
			ExcessPixelsX = ExcessPixelsX - TotalColumnRowWeight * ExcessPixelsY;
		end
		LayoutDebug("Excess Pixels: (%s, %s)", ExcessPixelsX, ExcessPixelsY);
		for i, v in pairs(Children) do
			local element, x, y, width, height = unpack(v);
			local xf, yf = x + width, y + height;
			local highPos = UDim2.new(
				pos.X.Scale + size.X.Scale * GridParameters.ColumnWeights[xf] + size.Y.Scale * GridParameters.ColumnRowWeights[xf],
				pos.X.Offset + GridParameters.ColumnWidths[xf] + ExcessPixelsX * GridParameters.ColumnWeights[xf] + ExcessPixelsY * GridParameters.ColumnRowWeights[xf] + (xf - 1) * GridParameters.Cushion.x,
	
				pos.Y.Scale +
				size.Y.Scale * GridParameters.RowWeights[yf] +
				size.X.Scale * GridParameters.RowColumnWeights[yf],
	
				pos.Y.Offset + GridParameters.RowHeights[yf] + ExcessPixelsY * GridParameters.RowWeights[yf] + ExcessPixelsX * GridParameters.RowColumnWeights[yf] + (yf - 1) * GridParameters.Cushion.y
			);
			xf, yf = x, y;
			local lowPos = UDim2.new(
				pos.X.Scale + size.X.Scale * GridParameters.ColumnWeights[xf] + size.Y.Scale * GridParameters.ColumnRowWeights[xf],
				pos.X.Offset + GridParameters.ColumnWidths[xf] + ExcessPixelsX * GridParameters.ColumnWeights[xf] + ExcessPixelsY * GridParameters.ColumnRowWeights[xf] + (xf - 1) * GridParameters.Cushion.x,
				pos.Y.Scale + size.Y.Scale * GridParameters.RowWeights[yf] + size.X.Scale * GridParameters.RowColumnWeights[yf],
				pos.Y.Offset + GridParameters.RowHeights[yf] + ExcessPixelsY * GridParameters.RowWeights[yf] + ExcessPixelsX * GridParameters.RowColumnWeights[yf] + (yf - 1) * GridParameters.Cushion.y
			);
			LayoutDebug("Low Pos: %s", lowPos);
			LayoutDebug("High Pos: %s", highPos);
			element:_SetPPos(lowPos);
			element:_SetPSize(highPos - lowPos - UDim2.new(0, GridParameters.Cushion.x, 0, GridParameters.Cushion.y));
		end
	end
	--[[ @brief Returns the amount of space it would require to lay out these elements.
	     @param GridParameters See GridLayout
	     @param size The size we would hypothetically be afforded.
	--]]
	function Gui.GridLayoutSize(GridParameters, size)
		local gs = GridParameters.GridSize;
		local Cushion = GridParameters.Cushion;
		local TotalColumnWeights = Utils.Table.Sum(GridParameters.ColumnWeights, gs.x);
		local TotalRowWeights = Utils.Table.Sum(GridParameters.RowWeights, gs.y);
	
		--Case in which both dimensions should be totally filled.
		if TotalColumnWeights > 0 and TotalRowWeights > 0 then
			return size;
		end
	
		local TotalColumnWidths = Utils.Table.Sum(GridParameters.ColumnWidths, gs.x);
		local TotalRowHeights = Utils.Table.Sum(GridParameters.RowHeights, gs.y);
	
		--Case in which neither dimension should be filled.
		if TotalColumnWeights == 0 and TotalRowWeights == 0 then
			return UDim2.new(0, TotalColumnWidths + Cushion.x * (gs.x - 1), 0, TotalRowHeights + Cushion.y * (gs.y - 1));
		end
	
		--Cases in only one dimension is to be filled.
		if TotalColumnWeights > 0 then
			local ExcessPixels = size.X.Offset - TotalColumnWidths - Cushion.x * (gs.x - 1);
			local SingleWeightSize = UDim.new(size.X.Scale / TotalColumnWeights, ExcessPixels / TotalColumnWeights);
			local TotalRowColumnWeights = Utils.Table.Sum(GridParameters.RowColumnWeights, gs.y);
			return UDim2.new(size.X.Scale, size.X.Offset, SingleWeightSize.Scale * TotalRowColumnWeights, SingleWeightSize.Offset * TotalRowColumnWeights + Cushion.y * (gs.y - 1) + TotalRowHeights);
		else
			local ExcessPixels = size.Y.Offset - TotalRowHeights - Cushion.y * (gs.y - 1);
			local SingleWeightSize = UDim.new(size.X.Scale / TotalRowWeights, ExcessPixels / TotalRowWeights);
			local TotalColumnRowWeights = Utils.Table.Sum(GridParameters.ColumnRowWeights, gs.x);
			return UDim2.new(
				SingleWeightSize.Scale * TotalColumnRowWeights,
				SingleWeightSize.Offset * TotalColumnRowWeights + Cushion.x * (gs.x - 1) + TotalColumnWidths, size.Y.Scale, size.Y.Offset
			);
		end
	end

	---------------------------------------------------------------------------
	-- Helper function for elements with per-child parameters --
	---------------------------------------------------------------------------
	local ChildParameters = Utils.new("Class", "ChildParameters"); do
		ChildParameters._Defaults = false;
		ChildParameters._Parameters = false;
		--[[ @brief Returns a table with all child parameters defined.
		     @details All parameters defined by child.LayoutParams will be given. Any undefined keys will be replaced by a default.
		--]]
		function ChildParameters:__index(child)
			local t = {};
			local s;
			if child and type(child) == 'table' then s = child.LayoutParams; end
			local u = self._Parameters[child];
			for i, v in pairs(self._Defaults) do
				if u and u[i]~=nil then
					t[i] = u[i];
				elseif s and s[i]~=nil then
					t[i] = s[i];
				else
					t[i] = v;
				end
			end
			return t;
		end
		--[[ @brief Defers written child parameters to a different key.
		--]]
		function ChildParameters:__newindex(child, paramTable)
			self._Parameters[child] = paramTable;
		end
		--[[ @brief Returns a table for a child which is writable
		--]]
		function ChildParameters:GetWritableParameters(child)
			self._Parameters[child] = self._Parameters[child] or {};
			return self._Parameters[child];
		end
		--[[ @brief Registers a default value for a given key.
		     @param key The key to register for.
		     @param value The value to register.
		--]]
		function ChildParameters:SetDefault(key, value)
			self._Defaults[key] = value;
		end
		--[[ @brief Instantiates a new ChildParameters object.
		--]]
		function ChildParameters.new()
			return setmetatable({_Defaults = {}, _Parameters = {}}, ChildParameters.Meta);
		end
	end

	--[[ @brief Instantiates a new ChildParameters object and plugs in default values.
	--]]
	function Gui._ChildProperties(defaults)
		Log.Warn("Function Utils._ChildProperties deprecated; use Utils.ChildProperties instead.");
		return Utils.ChildProperties(defaults);
	end

	function Gui.ChildProperties(defaults)
		local self = ChildParameters.new();
		for i, v in pairs(defaults) do
			self:SetDefault(i, v);
		end
		return self;
	end

	----------------------------------------------------------------------------------------------------------
	-- Helper class for elements which distribute their children to underlying elements. --
	----------------------------------------------------------------------------------------------------------
	local ChildPlacements = Utils.new("Class", "ChildPlacements");
	ChildPlacements._ChildMap = false;
	--[[ @brief Registers a child to a parent.
	     @details child.Parent will not equal parent, but child will be a member of parent:GetChildren(). This enables things like Reflowing to work, but the child doesn't appear to have its parent constantly changed (AncestryChanged will not fire). Additionally, if the element was previously parented to another element, it will be removed.
	     @param child Added to element parent.
	     @param parent The element to which parameter child is added.
	--]]
	function ChildPlacements:AddChildTo(child, parent)
		if self._ChildMap[child] == parent then return; end
		if self._ChildMap[child] then
			self._ChildMap[child]:_RemoveChild(child);
		end
		self._ChildMap[child] = parent;
		if self._ChildMap[child] then
			self._ChildMap[child]:_AddChild(child);
		end
	end
	--[[ @brief Remove child from any elements it is a part of.
	     @param child The child to remove.
	--]]
	function ChildPlacements:RemoveChild(child)
		if self._ChildMap[child] then
			self._ChildMap[child]:_RemoveChild(child);
		end
	end
	--[[ @brief Returns the parent of the child (internal representation).
	--]]
	function ChildPlacements:GetChildParent(child)
		return self._ChildMap[child];
	end
	--[[ @brief Instantiate a new ChildPlacements object.
	     @return A new instance of ChildPlacements.
	--]]
	function ChildPlacements.new()
		return setmetatable({_ChildMap = {};}, ChildPlacements.Meta);
	end
	--[[ @brief Instantiates and returns a child placements object.
	--]]
	function Gui.ChildPlacements()
		return ChildPlacements.new();
	end

end

------------------------------------
-- Gui Registry/Instantiator --
------------------------------------
local ClassMap = {};
function Gui.Register(class)
	Log.AssertNonNilAndType("class.new", "function", class.new);
	local name = tostring(class);
	Log.AssertNonNilAndType("tostring(class)", "string", name);
	if name:sub(1, 7)=='table: ' then
		--If tostring() was undefined, the class name will be quite difficult to use.
		Log.Warn(2, "className is given as tostring(class) = %s; are you sure this is what you want?", name);
	end
	RegistryDebug("Registering class %s", name);
	ClassMap[name] = class.new;
end
function Gui.new(name, parent)
	RegistryDebug("Gui.new(%s, %s) called", name, parent);
	Log.Assert(ClassMap[name]~=nil, "type %s does not exist.", name);
	local v = ClassMap[name]();
	Log.Assert(v, "Constructor for %s did not return a value.", name);
	if parent then
		v.Parent = parent;
	end
	return v;
end
--[[ @brief Returns an instance of the gui library which wraps this instance of the roblox library.
--]]
function Gui.wrap(instance, parent)
	RegistryDebug("Gui.wrap(%s, %s) called", instance, parent);
	local v = ClassMap.Wrapper(instance);
	RegistryDebug("ClassMap.Wrapper(%s) = %s", instance, v);
	if parent then
		Log.Warn("Second argument 'parent' to Gui.wrap is deprecated");
		v.Parent = parent;
	end
	return v;
end

Gui.register = Gui.Register;
Gui.Enum = Utils.new("EnumContainer");

----------------------------------------------
-- Run all Contained ModuleScripts --
----------------------------------------------
_G[script] = Gui;
local SPECIAL_SCRIPTS = {InputRegistry = true};
for i, v in pairs(script:GetChildren()) do
	if not SPECIAL_SCRIPTS[v.Name] then
		RegistryDebug("Attempting to require %s", v.Name);
		if v:IsA("ModuleScript") then
			local obj = require(v);
			if obj then
				Gui.Register(obj);
			end
		end
	end
end

return Gui;


