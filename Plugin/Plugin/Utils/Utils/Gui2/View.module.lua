local Utils = require(script.Parent.Parent);
local Gui = _G[script.Parent];
local Test = Gui.Test;
local Log = Utils.Log;

local ParentDebug = Gui.Log.Parent;
local ReflowDebug = Gui.Log.Reflow;
local Debug = Gui.Log.Debug;

--Not Doing: hierarchy events (ChildAdded, AncestryChanged, etc. should be added).

--[[ @brief Computes a size assuming that sz2 was a UDim2 size sitting inside of a frame of size sz1.
     @example CompositeSize(UDim2.new(.8, -10, .6, -10), UDim2.new(.5, 0, .5, 0)) = UDim2.new(.4, -5, .3, -5).
--]]
function CompositeSize(sz1, sz2)
	return UDim2.new(sz1.X.Scale * sz2.X.Scale, sz1.X.Offset * sz2.X.Scale + sz2.X.Offset, sz1.Y.Scale * sz2.Y.Scale, sz1.Y.Offset * sz2.Y.Scale + sz2.Y.Offset);
end
function GetCoordsFromPlacementCoords(self)
	local pos = self._PlacementPosition + UDim2.new(
		self._PlacementSize.X.Scale * self._Position.X.Scale, self._PlacementSize.X.Offset * self._Position.X.Scale + self._Position.X.Offset,
		self._PlacementSize.Y.Scale * self._Position.Y.Scale, self._PlacementSize.Y.Offset * self._Position.Y.Scale + self._Position.Y.Offset
	);
	local size = CompositeSize(self._PlacementSize, self._Size);
	--[[ The following properties must all be incorporated here.
		View._FillX = true;
		View._FillY = true;
		View._MinimumX = 5;
		View._MinimumY = 5;
		View._Gravity = 1;
		View._Margin = 0;
	--]]
	local minSize = self:_GetMinimumSize();
	ReflowDebug("    Minimum Required Size: %s", minSize);
	local origSize = size;
	ReflowDebug("    Fill X/Y: %s, %s", self._FillX, self._FillY);
	if not self._FillX then
		size = UDim2.new(0, minSize.x, size.Y.Scale, size.Y.Offset);
	end
	if not self._FillY then
		size = UDim2.new(size.X.Scale, size.X.Offset, 0, minSize.y);
	end
	local g = self._Gravity.Value;
	if g then
		if g % 3 == 2 then
			--Central
			pos = pos + UDim2.new(origSize.X.Scale / 2, origSize.X.Offset / 2, 0, 0) + UDim2.new(-size.X.Scale / 2, -size.X.Offset / 2, 0, 0);
		elseif g % 3 == 0 then
			--Right
			pos = pos + UDim2.new(origSize.X.Scale, origSize.X.Offset, 0, 0) + UDim2.new(-size.X.Scale, -size.X.Offset, 0, 0);
		end
		if g / 3 > 2 then
			--Bottom
			pos = pos + UDim2.new(0, 0, origSize.Y.Scale, origSize.Y.Offset) + UDim2.new(0, 0, -size.Y.Scale, -size.Y.Offset);
		elseif g / 3 > 1 then
			--Middle
			pos = pos + UDim2.new(0, 0, origSize.Y.Scale / 2, origSize.Y.Offset / 2) + UDim2.new(0, 0, -size.Y.Scale / 2, -size.Y.Offset / 2);
		end
	end
	if type(self._Margin) == "number" then
		pos = pos + UDim2.new(0, self._Margin, 0, self._Margin);
		size = size + UDim2.new(0, -self._Margin * 2, 0, -self._Margin * 2);
	elseif type(self._Margin) == "table" then
		pos = pos + UDim2.new(0, self._Margin.Left, 0, self._Margin.Top);
		size = size + UDim2.new(0, -self._Margin.Left - self._Margin.Right, 0, -self._Margin.Top - self._Margin.Bottom);
	else
		Log.AssertNonNilAndType("Margin", "number", self._Margin);
	end
	return pos, size;
end

local IS_GUI_TYPE = function(x) return type(x)=='table'; end;

local View = Utils.new("Class", "View");

Gui.Enum:newEnumClass("ViewGravity", "TopLeft", "TopCenter", "TopRight", "CenterLeft", "Center", "CenterRight", "BottomLeft", "BottomCenter", "BottomRight");

local CLONE_PARAMETERS = {"Name", "FillX", "FillY", "MinimumX", "MinimumY", "Gravity", "Margin", "Position", "Size", "Parent"};

------------------------
-- Default Values --
------------------------
View._Name = "View";
View._LayoutParams = false;
--Variables related to positioning. All elements may be positioned even if they don't render.
View._FillX = true;
View._FillY = true;
View._MinimumX = 5;
View._MinimumY = 5;
View._Gravity = Gui.Enum.ViewGravity.TopLeft;
View._Margin = 0;
View._PlacementPosition = UDim2.new(); --Provided by parent instance
View._PlacementSize = UDim2.new(1, 0, 1, 0);
View._Position = UDim2.new(); --Provided by user. This likely should not be changed.
View._Size = UDim2.new(1, 0, 1, 0);
--Variables related to the hierarchy.
View._Children = {};
View._Parent = false;
View._SignalReflowPre = false;
View._Changed = false;
View._AbsoluteSize = Vector2.new();
View._AbsolutePosition = Vector2.new();

-----------------------------
-- Getter Indirections --
-----------------------------
--Indirection for some properties.
View.Get.Name = "_Name";
View.Get.LayoutParams = "_LayoutParams";
View.Get.FillX = "_FillX";
View.Get.FillY = "_FillY";
View.Get.MinimumX = "_MinimumX";
View.Get.MinimumY = "_MinimumY";
View.Get.Gravity = "_Gravity";
View.Get.Margin = "_Margin";
View.Get.Position = "_Position";
View.Get.Size = "_Size";
View.Get.Parent = "_Parent";
--Changed: a read only event which fires when a property is changed.
function View.Get:Changed()
	return self._Changed.Event;
end
function View.Get:AbsoluteSize()
	local pos, size = GetCoordsFromPlacementCoords(self);
	if self.Parent and type(self.Parent)=='table' then
		local parent = self.Parent:_GetChildContainer(self);
		if parent then
			self._AbsolutePosition = parent.AbsolutePosition + parent.AbsoluteSize * Vector2.new(pos.X.Scale, pos.Y.Scale) + Vector2.new(pos.X.Offset, pos.Y.Offset);
			self._AbsoluteSize = parent.AbsoluteSize * Vector2.new(size.X.Scale, size.Y.Scale) + Vector2.new(size.X.Offset, size.Y.Offset);
		end
	end
	return self._AbsoluteSize;
end
function View.Get:AbsolutePosition()
	local pos, size = GetCoordsFromPlacementCoords(self);
	if self.Parent and type(self.Parent)=='table' then
		local parent = self.Parent:_GetChildContainer(self);
		if parent then
			self._AbsolutePosition = parent.AbsolutePosition + parent.AbsoluteSize * Vector2.new(pos.X.Scale, pos.Y.Scale) + Vector2.new(pos.X.Offset, pos.Y.Offset);
			self._AbsoluteSize = parent.AbsoluteSize * Vector2.new(size.X.Scale, size.Y.Scale) + Vector2.new(size.X.Offset, size.Y.Offset);
		end
	end
	return self._AbsolutePosition;
end
function View.Get:Clicked()
	if self:_GetHandle() then
		
	end	
end

--------------------------
-- Setter Functions --
--------------------------
--[[ @brief Sets the Name property.
--]]
function View.Set:Name(name)
	self._Name = name;
	if self:_GetHandle() then
		self:_GetHandle().Name = name;
	end
end
--[[ @brief Sets new layout parameters and reflows the parent.
     @param layoutParams The new layout parameters.
--]]
function View.Set:LayoutParams(layoutParams)
	if self._LayoutParams == layoutParams then
		return;
	end
	Log.AssertNonNilAndType("LayoutParams", "table", layoutParams);
	self._LayoutParams = layoutParams;
	if self._Parent then
		self._Parent:_ReflowPre();
	end
end
--[[ @brief Sets the FillX property and reflows the element.
     @param fillX The new FillX property (must be boolean).
--]]
function View.Set:FillX(fillX)
	if self._FillX == fillX then
		return;
	end
	Log.AssertNonNilAndType("FillX", "boolean", fillX);
	self._FillX = fillX;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the FillY property and reflows the element.
     @param FillY The new FillY property (must be boolean).
--]]
function View.Set:FillY(fillY)
	if self._FillY == fillY then
		return;
	end
	Log.AssertNonNilAndType("FillY", "boolean", fillY);
	self._FillY = fillY;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the FillX property and reflows the element.
     @param fillX The new FillX property (must be boolean).
--]]
function View.Set:MinimumX(minX)
	if self._MinimumX == minX then
		return;
	end
	Log.AssertNonNilAndType("MinimumX", "number", minX);
	self._MinimumX = minX;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the FillX property and reflows the element.
     @param fillX The new FillX property (must be boolean).
--]]
function View.Set:MinimumY(minY)
	if self._MinimumY == minY then
		return;
	end
	Log.AssertNonNilAndType("MinimumY", "number", minY);
	self._MinimumY = minY;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the FillX property and reflows the element.
     @param fillX The new FillX property (must be boolean).
--]]
function View.Set:Gravity(grav)
	grav = Gui.Enum.ViewGravity:ValidateEnum(grav, "Gravity");
	if self._Gravity == grav then
		return;
	end
	self._Gravity = grav;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the FillX property and reflows the element.
     @param fillX The new FillX property (must be boolean).
--]]
function View.Set:Margin(margin)
	if not margin or (type(margin)~='number' and type(margin)~='table') then
		Log.AssertNonNilAndType("Margin", "number", margin);
	elseif type(margin)=='table' then
		if margin.top then Log.Warn(2, "Margin.top deprecated in favor of Margin.Top"); margin.Top = margin.top; end
		if margin.bottom then Log.Warn(2, "Margin.bottom deprecated in favor of Margin.Bottom"); margin.Bottom = margin.bottom; end
		if margin.right then Log.Warn(2, "Margin.right deprecated in favor of Margin.Right"); margin.Right = margin.right; end
		if margin.left then Log.Warn(2, "Margin.left deprecated in favor of Margin.Left"); margin.Left = margin.left; end
		--If none of them are defined, we have to assume there's an error.
		Log.Assert(margin.Left or margin.Top or margin.Right or margin.Bottom, "Margin.Top, Bottom, Left, and Right should be defined.");
		--Any undefined elements can be defaulted to 0.
		if not margin.Top then margin.Top = 0; end
		if not margin.Bottom then margin.Bottom = 0; end
		if not margin.Left then margin.Left = 0; end
		if not margin.Right then margin.Right = 0; end
		Log.AssertNonNilAndType("Margin.left", "number", margin.Left);
		Log.AssertNonNilAndType("Margin.right", "number", margin.Right);
		Log.AssertNonNilAndType("Margin.top", "number", margin.Top);
		Log.AssertNonNilAndType("Margin.bottom", "number", margin.Bottom);
	end
	self._Margin = margin;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the position of this element.
     @details Translates all top-level handles or children.
--]]
function View.Set:Position(newPos)
	--Terminate early if we aren't changing the position.
	if newPos == self._Position then
		return;
	end
	--We move all elements by this amount
	local translation = newPos - self._Position;
	if self:_GetHandle() and self:_GetHandle():IsA("GuiObject") then
		--If we have a top-level handle, translate it accordingly.
		self:_GetHandle().Position = self:_GetHandle().Position + translation;
	end
	--If children are not placed in a particular handle, then we should translate them as well.
	for i, v in pairs(self:GetChildren()) do
		if not self:_GetChildContainerRaw(v) or not self:_GetChildContainerRaw(v):IsA("GuiObject") then
			v:_SetPPos(v._PlacementPosition + translation);
		end
	end
	self._Position = newPos;
end
--[[ @brief Sets the size property and reflows the element.
--]]
function View.Set:Size(newSize)
	--Terminate early if no changes are made.
	if newSize == self._Size then
		return;
	end
	--We should reflow the current element. This should in turn reflow all children.
	self._Size = newSize;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the parent of this element to either a roblox Instance or another Gui.
     @param parent The new parent.
     @details This function need not be overwritten by children. However, _GetHandle should be overwritten.
--]]
function View.Set:Parent(v)
	Log.Assert(v~=self, "Attempt to set self as Parent");
	if v~=self._Parent then
		--Remove itself from the old parent's children table.
		if self._Parent and IS_GUI_TYPE(self._Parent) then
			self._Parent:_RemoveChild(self);
		end
		--Add itself to the new parent's children table.
		if v and IS_GUI_TYPE(v) then
			v:_AddChild(self);
		end
		self._Parent = v;
	end
	--Make sure the roblox Instance corresponds with the hierarchy.
	if self:_GetHandle() then
		if v==nil or not IS_GUI_TYPE(v) then
			self:_GetHandle().Parent = v;
		else
			self:_GetHandle().Parent = v:_GetChildContainer(self);
		end
	else
		Gui.ReparentChildren(self);
	end
end
--[[ @brief Sets the parent without notifying the new one that a child is added.
--]]
function View.Set:ParentNoNotify(parent)
	self._Parent = parent;
	--Make sure the roblox Instance corresponds with the hierarchy.
	if self:_GetHandle() then
		if parent==nil or not IS_GUI_TYPE(parent) then
			self:_GetHandle().Parent = parent;
		else
			self:_GetHandle().Parent = parent:_GetChildContainer(self);
		end
	else
		for i, v in pairs(self:GetChildren()) do
			v.ParentNoNotify = self;
		end
	end
end

--Not Doing: "Get" methods for common events.

-----------------------------
-- External Functions --
-----------------------------

function View:__index(name)
	return self:FindFirstChild(name);
end
--[[ @brief Allows searching for children by name.
     @param name The name of the child to search for.
     @return The first child with the given name; otherwise, nil
--]]
function View:FindFirstChild(name)
	for i, v in pairs(self:GetChildren()) do
		if v.Name == name then
			return v;
		end
	end
end

--[[ @brief Returns a list of children.
     @return An array of child elements. All will be Gui type.
--]]
function View:GetChildren()
	local s = {};
	for i, v in pairs(self._Children) do
		table.insert(s, v);
	end
	return s;
end
--[[ @brief Removes all children from this element.
--]]
function View:ClearAllChildren()
	for i, v in pairs(Utils.Table.ShallowCopy(self._Children)) do
		v.Parent = nil;
	end
end
--[[ @brief Removes this element from the hierarchy, disconnects all connections, and prevents it from being reinserted.
--]]
function View:Destroy()
	self.Parent = nil;
	for i, v in pairs(self:GetChildren()) do
		v:Destroy();
	end
end
--[[ @brief Makes a copy of this element.
     @details Properties will be copied over and children will be recursively cloned & added to the newly created element. The element will be parented to nil.
     @return The newly created element.
--]]
function View:Clone()
	local new = Gui.new(self.ClassName);
	for i, v in pairs(CLONE_PARAMETERS) do
		new[v] = self[v];
	end
	for i, v in pairs(self:GetChildren()) do
		v:Clone().Parent = new;
	end
	return new;
end

function View:IsDescendantOf(x)
	if IS_GUI_TYPE(x) then
		self = self.Parent;
		while self and self~=x do
			self = self.Parent;
		end
		return not not self;
	else
		local bestHandle = self:_GetHandle();
		if bestHandle then
			return bestHandle:IsDescendantOf(x);
		end
		if not bestHandle and self.Parent then
			bestHandle = self.Parent:_GetChildContainer(self);
		end
		return bestHandle and (bestHandle==x or bestHandle:IsDescendantOf(x));
	end
end
function View:IsAncestorOf(x)
	if IS_GUI_TYPE(x) then
		return x:IsDescendantOf(self);
	else
		local handle = self:_GetHandle() or (self.Parent and self.Parent:_GetChildContainer(self));
		return handle and handle:IsAncestorOf(x);
	end
end

--[[ @brief Returns a string representing this element. For diagnostics only.
--]]
function View:__tostring()
	return self._Name;
end
--[[ @brief Cause this element to reposition itself & its children.
     @details Reflows often occur on a delay when properties are changed. This may result in a flickering effect. Calling this function after changing properties will force an immediate reflow & prevent flickering.
--]]
function View:ForceReflow()
	self._SignalReflowPre:Run();
end

-----------------------------
-- Internal Functions --
-----------------------------
--[[ @brief Returns the top-level handle for this element.
     @details This function is not meant to be recursive. If a handle does not exist for this element, return nil.
     @return The top-level handle for this element.
--]]
function View:_GetHandle()
	return self._Handle;
end
--[[ @brief Returns the container which children of this element should be placed in, or nil if none exists.
--]]
function View:_GetChildContainerRaw(child)
	return self:_GetHandle();
end
--[[ @brief Return the container which children of this element should be placed in.
     @details If no child container exists, this function should recursively traverse up.
     @param child Indicates which child we are looking to place.
--]]
function View:_GetChildContainer(child)
	local v = self:_GetChildContainerRaw(child);
	if v then
		return v;
	end
	if self._Parent then
		if IS_GUI_TYPE(self._Parent) then
			return self._Parent:_GetChildContainer(self);
		else
			return self._Parent;
		end
	end
end
--[[ @brief Sets the placement position for this element.
     @details The placement position refers to the raw UDim2 which the element should begin at. For example, a LinearLayout will set its children's placement position (and size) so they don't overlap.
     @param pos The position for this element to be placed.
--]]
function View:_SetPPos(pos)
	ReflowDebug("View._SetPPos(%s, %s) called", self, pos);
	if self._PlacementPosition ~= pos then
		if self:_GetHandle() then
			self:_GetHandle().Position = self:_GetHandle().Position - self._PlacementPosition + pos;
		else
			self._SignalReflowPre:Trigger();
		end
		self._PlacementPosition = pos;
	end
end
--[[ @brief Sets the placement size for this element.
     @details The placement size represents the size of the actual roblox Instance before modifications.
--]]
function View:_SetPSize(size)
	ReflowDebug("View._SetPSize(%s, %s) called", self, size);
	if self._PlacementSize ~= size then
		self._PlacementSize = size;
		self._SignalReflowPre:Trigger();
	end
end
--[[ @brief Reflows the element using its state variables.
     @details The general shape which the element will create is determined by FillX, FillY, Gravity, Margin, Position, and Size. Additionally, the minimum size may be considered. This function will typically end with a call to _Reflow(pos, size) which should be overwritten by classes which need complex layout code.
--]]
function View:_ReflowPre()
	ReflowDebug("View._ReflowPre(%s) called", self);
	ReflowDebug("    Raw Position/Size: (%s), (%s)", self._PlacementPosition, self._PlacementSize);
	ReflowDebug("    User Position/Size: (%s), (%s)", self._Position, self._Size);
	local pos, size = GetCoordsFromPlacementCoords(self);
	ReflowDebug("    Transformed Pos/Size: (%s), (%s)", pos, size);
	local parent;
	if self._Parent then
		if type(self.Parent)=='table' then
			parent = self._Parent:_GetChildContainer(self);
		elseif self._Parent:IsA("GuiObject") then
			parent = self._Parent;
		end
	end
	if parent then
		self._AbsolutePosition = parent.AbsoluteSize * Vector2.new(pos.X.Scale, pos.Y.Scale) + Vector2.new(pos.X.Offset, pos.Y.Offset);
		self._AbsoluteSize = parent.AbsoluteSize * Vector2.new(size.X.Scale, size.Y.Scale) + Vector2.new(size.X.Offset, size.Y.Offset);
		pos = UDim2.new(0, self._AbsolutePosition.x, 0, self._AbsolutePosition.y);
		size = UDim2.new(0, self._AbsoluteSize.x, 0, self._AbsoluteSize.y);
	end
	ReflowDebug("    Pixeled Pos/Size: (%s), (%s)", pos, size);
	self:_Reflow(pos, size);
end
--[[ @brief Place this element at a given position/size, and call recursively for all children.
     @details This function is meant to be overwritten for elements which have particular flow logic, e.g., LinearLayout, GridLayout, etc.
         This function should call _SetPPos and _SetPSize for all children.
     @param pos The position to place this element at.
     @param size The size to make the element.
--]]
function View:_Reflow(pos, size)
	ReflowDebug("View._Reflow(%s, %s, %s) called", self, pos, size);
	local v = self:_GetHandle();
	if v then
		v.Position = pos;
		v.Size = size;
	end
	for i, v in pairs(self:GetChildren()) do
		if self:_GetChildContainerRaw(v) then
			v:_SetPPos(UDim2.new(0, 0, 0, 0));
			v:_SetPSize(UDim2.new(1, 0, 1, 0));
		else
			v:_SetPPos(pos);
			v:_SetPSize(size);
		end
	end
end
--[[ @brief Returns the minimum required size for this element.
--]]
function View:_GetMinimumSize()
	local x, y = self._MinimumX, self._MinimumY;
	for i, v in pairs(self:GetChildren()) do
		local min = v:_GetMinimumSize();
		if min.x > x then x = min.x; end
		if min.y > y then y = min.y; end
	end
	if type(self._Margin)=='number' then
		x, y = x + self._Margin * 2, y + self._Margin * 2;
	else
		x, y = x + self._Margin.Left + self._Margin.Right, y + self._Margin.Top + self._Margin.Bottom;
	end
	return Vector2.new(x, y);
end
--[[ @brief Add an element as a child to this element.
     @details This method is responsible for maintaining the _Children table, calling ChildAdded/DescendantAdded, and reflowing.
--]]
function View:_AddChild(child)
	ParentDebug("View._AddChild(%s, %s) called", self, child);
	table.insert(self._Children, child);
	--Not Doing: call ChildAdded/DescendantAdded
	self._SignalReflowPre:Trigger();
end
--[[ @brief Remove an element from this class.
     @details This method is responsible for maintaining the _Children table, calling ChildAdded/DescendantAdded, and reflowing.
--]]
function View:_RemoveChild(child)
	ParentDebug("View._RemoveChild(%s, %s) called", self, child);
	local t = self._Children;
	for i = #t, 1, -1 do
		if t[i]==child then
			--Not Doing: call ChildRemoved/DescendantRemoved.
			table.remove(t, i);
		end
	end
	self._SignalReflowPre:Trigger();
end
--[[ @brief Returns a rectangle which bounds this object & all its childrens in absolute coordinates.
     @return TopLeft: a Vector2 representing the top left corner of the bounding rectangle.
     @return BottomRight: a Vector2 representing the bottom right corner of the bounding rectangle.
--]]
function View:_GetBounds()
	local x1, y1, x2, y2;
	local absPos, absSize = self.AbsolutePosition, self.AbsoluteSize;
	x1 = absPos.x;
	y1 = absPos.y;
	x2 = x1 + absSize.x;
	y2 = y1 + absSize.y;
	for i, v in pairs(self:GetChildren()) do
		local topLeft, bottomRight = v:_GetBounds();
		if topLeft.x < x1 then x1 = topLeft.x; end
		if topLeft.y < y1 then y1 = topLeft.y; end
		if bottomRight.x > x2 then x2 = bottomRight.x; end
		if bottomRight.y > y2 then y2 = bottomRight.y; end
	end
end

--[[ @brief Instantiates a new View object.
     @return A new view object.
--]]
function View.new()
	local self = setmetatable({_Children = {}}, View.Meta);
	self._SignalReflowPre = Utils.new("DelayOperation", "ViewReflow");
	self._SignalReflowPre.CanSignalOnTrigger = false;
	self._SignalReflowPre.OnTrigger = function()
		self:_ReflowPre();
	end;
	self._Changed = Utils.new("Event");
	return self;
end

function Test.View_Basic()
	local sgui = Gui.new("ScreenGui");
	sgui.Name = "View_Basic";
	local view = Gui.new("View", sgui);
	view.Size = UDim2.new(0.3, 0, 0.3, 0);
	view.Position = UDim2.new(.35, 0, .35, 0);
	sgui.Parent = game.StarterGui;
	wait();
	Log.AssertAlmostEqual("view.AbsoluteSize", sgui.AbsoluteSize*.3, 1, view.AbsoluteSize);
	Log.AssertAlmostEqual("view.AbsolutePosition", sgui.AbsoluteSize*.35, 1, view.AbsolutePosition);
end

return View;
