local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "GuiBase2d: ", false);

function IS_GUI_TYPE(v)
	return type(v)=='table';
end

local Super = Gui.Instance;
local GuiBase2d = Utils.new("Class", "GuiBase2d", Super);

--Upon reflowing the object, these variables should be set to the position/size that the object is actually using.
GuiBase2d._AbsolutePosition = Vector2.new();
GuiBase2d._AbsoluteSize = Vector2.new();

--[[
Sometimes a parent does not want its child to take up its entire space. It can assign
a "PlacementPosition" and "PlacementSize" and in that case, a child with a size of
<1, 0, 1, 0> should not go outside of those boundaries (unless extenuating
circumstances occur, e.g., MinimumSize is breached.
--]]
GuiBase2d._PlacementPosition = UDim2.new();
GuiBase2d._PlacementSize = UDim2.new(1, 0, 1, 0);
GuiBase2d._UserPosition = UDim2.new();
GuiBase2d._UserSize = UDim2.new(1, 0, 1, 0);
GuiBase2d._ChildrenOrder = {};
GuiBase2d._ZIndex = 1;
GuiBase2d._FlagReorderChildren = false;
GuiBase2d._LayoutParams = false;
GuiBase2d._Visible = true;

GuiBase2d._TriggerReflow = Utils.new("DelayOperation"); --! A method which triggers the reflowing of this class.
GuiBase2d._ParentSizeChangedCxn = false; --! A connection for the parent's AbsoluteSize changed event.

function GuiBase2d.Set:Name(v)
	Super.Set.Name(self, v);
	if self:_GetRbxHandle() then
		self:_GetRbxHandle().Name = v;
	end
end
function GuiBase2d:_SetParent(parent, triggerEvents)
	Debug("GuiBase2d._SetParent(%s, %s, %s) called", self, parent, triggerEvents);
	Super._SetParent(self, parent, triggerEvents);
	if self._ParentSizeChangedCxn and self._ParentSizeChangedCxn.connected then
		self._ParentSizeChangedCxn:disconnect();
	end
	if typeof(parent) == 'Instance' and parent:IsA("GuiBase2d") then
		Debug("\t%s is a roblox Instance", parent);
		if self._PlacementPosition.X.Scale ~= 0 or self._PlacementPosition.Y.Scale ~= 0 or
		   self._PlacementSize.    X.Scale ~= 0 or self._PlacementSize    .Y.Scale ~= 0 then
			self._TriggerReflow();
		end
		self._ParentSizeChangedCxn = parent:GetPropertyChangedSignal("AbsoluteSize"):connect(function()
			Debug("Parent %s changed AbsoluteSize to %s", parent, parent.AbsoluteSize);
			self._TriggerReflow();
		end)
		if self:_GetRbxHandle() then
			self:_GetRbxHandle().Parent = parent;
		else
			Debug("\tSetting all children.Parent = self");
			for i, v in pairs(self:GetChildren()) do
				Debug("\t\t%s.Parent = %s", v, self);
				v.ParentNoNotify = self;
			end
		end
	elseif parent and parent:IsA("GuiBase2d") then
		Debug("\t%s is a custom gui Instance", parent);
		if self:_GetRbxHandle() then
			self:_GetRbxHandle().Parent = parent:_GetChildContainer(self);
		else
			Debug("\tSetting all children.Parent = self");
			for i, v in pairs(self:GetChildren()) do
				Debug("\t%s.Parent = %s", v, self);
				v.ParentNoNotify = self;
			end
		end
	else
		if self:_GetRbxHandle() then
			self:_GetRbxHandle().Parent = nil;
		else
			Debug("\tSetting all children.Parent = self");
			for i, v in pairs(self:GetChildren()) do
				Debug("\t%s.Parent = %s", v, self);
				v.ParentNoNotify = self;
			end
		end
	end
end

function GuiBase2d:_AdjustAbsolutePosition(delta)
	for i, v in pairs(Utils.Recurse(self)) do
		if v:IsA("GuiBase2d") then
			v._AbsolutePosition = v._AbsolutePosition + delta;
		end
	end
end

function GuiBase2d.Set:_Position(v)
	Debug("%s._PlacementPosition = %s", self, v);
	if v ~= self._PlacementPosition then
		if not self._TriggerReflow.Dirty then
			local handle = self:_GetRbxHandle();
			if handle then
				Debug("Optimized _PlacementPosition Set");
				local delta = v - self._PlacementPosition;
				handle.Position = handle.Position + delta;
				delta = Vector2.new(delta.X.Scale*self._AbsoluteSize.x+delta.X.Offset, delta.Y.Scale*self._AbsoluteSize.y+delta.Y.Offset);
				self:_AdjustAbsolutePosition(delta);
			end
		else
			self:_TriggerReflow();
		end
		self._PlacementPosition = v;
	else
		Debug("No change in position; ignoring");
	end
end
function GuiBase2d.Set:_Size(v)
	Utils.Log.AssertNonNilAndType("_Size", "userdata", v);
	Debug("%s._PlacementSize = %s", self, v);
--	if v ~= self._PlacementSize then
		self._PlacementSize = v;
		if self._UserSize.X.Scale ~= 0 or self._UserSize.Y.Scale ~= 0 then
			self._TriggerReflow();
		end
--	else
--		Debug("No change in size; ignoring");
--	end
end
function GuiBase2d.Set:Position(v)
	Debug("%s.Position = %s", self, v);
	
	if v ~= self._UserPosition then
		if not self._TriggerReflow.Dirty then
			local handle = self:_GetRbxHandle();
			if handle then
				Debug("Optimized _UserPosition Set");
				local delta = v - self._UserPosition;
				handle.Position = handle.Position + delta;
				delta = Vector2.new(delta.X.Scale*self._AbsoluteSize.x+delta.X.Offset, delta.Y.Scale*self._AbsoluteSize.y+delta.Y.Offset);
				self:_AdjustAbsolutePosition(delta);
			end
		else
			self:_TriggerReflow();
		end
		self._UserPosition = v;
		self._EventLoader:FireEvent("Changed", "Position");
	else
		Debug("No change in position; ignoring");
	end
end
function GuiBase2d.Set:Size(v)
	self._UserSize = v;
	self._TriggerReflow();
	self._EventLoader:FireEvent("Changed", "Size");
end
function GuiBase2d.Set:ZIndex(v)
	self._ZIndex = v;
	if self._Parent and typeof(self._Parent) ~= "Instance" then
		self._Parent:_TriggerReflow();
	end
	self._EventLoader:FireEvent("Changed", "ZIndex");
end
function GuiBase2d.Set:LayoutParams(v)
	self._LayoutParams = v;
	--Gui3Task: should we trigger reflow for the parent?
	self._EventLoader:FireEvent("Changed", "LayoutParams");
end
function GuiBase2d.Set:Visible(v)
	self._Visible = v;
	local SetHandleVisibility = true;
	local p = self._Parent;
	while p and type(p)=='table' and not p:_GetRbxHandle() do
		if not p._Visible then
			SetHandleVisibility = false;
		end
		p = p._Parent;
	end
	if SetHandleVisibility then
		local handle = self:_GetRbxHandle();
		if handle then
			handle.Visible = v;
		else
			Utils.Recurse.Map(handle, function(e)
				if not e._Visible then
					--This element is invisible, so its handle is already correctly invisible.
					return true;
				end
				if e:_GetRbxHandle() then
					--This element has a handle, so we should make it visible/invisible based on v.
					e.Visible = v;
					return true;
				end
			end);
		end
	end
	if v then
		self:_TriggerReflow();
	end
	self._EventLoader:FireEvent("Changed", "Visible");
end

--Gui3Task: audit all setters to ensure that the Changed event fires as expected
--Gui3Task: audit all properties to ensure that they get copied over when cloning a type.
--Gui3Task: figure out how tweening should work.

function GuiBase2d.Get:AbsolutePosition()
	self:_ConditionalReflow();
	return self._AbsolutePosition;
end
function GuiBase2d.Get:AbsoluteSize()
	self:_ConditionalReflow();
	return self._AbsoluteSize;
end
GuiBase2d.Get._Position = "_PlacementPosition";
GuiBase2d.Get._Size = "_PlacementSize";
GuiBase2d.Get.Position = "_UserPosition";
GuiBase2d.Get.Size = "_UserSize";
GuiBase2d.Get.ZIndex = "_ZIndex";
GuiBase2d.Get.LayoutParams = "_LayoutParams";

function GuiBase2d:_Clone(new)
--	Utils.Log.Debug("Self: %t", self);
--	Utils.Log.Debug("Self.__Class: %s", self.__Class);
	new._Position = self._Position;
	new._Size = self._Size;
	new.Position = self.Position;
	new.Size = self.Size;
	new.LayoutParams = self._LayoutParams and Utils.Table.ShallowCopy(self._LayoutParams) or nil;
	new.ZIndex = self.ZIndex;
end
function GuiBase2d:_GetRbxHandle()
	return nil;
end
function GuiBase2d:_GetChildContainerRaw(child)
	return self:_GetRbxHandle();
end
function GuiBase2d:_GetChildContainer(child)
	local childContainer = self:_GetChildContainerRaw(child);
	if childContainer then
		return childContainer;
	elseif childContainer == false then
		return nil;
	end
	if self._Parent then
		if type(self._Parent)=='table' then
			return self._Parent:_GetChildContainer(self);
		else
			return self._Parent;
		end
	else
		return nil;
	end
end
function GuiBase2d:_ApplyModifiers(pos, size)
	local modifiers = {};
	--Gui3Task: populate this table only when children are added/removed.
	for i, child in pairs(self._Children) do
		Debug("Checking child %s (class %s)", child, child.ClassName);
		if IS_GUI_TYPE(child) and child:IsAn("Modifier") then
			Debug("  Child is Modifier class");
			table.insert(modifiers, child);
		end
	end
	Utils.Table.StableSort(modifiers, function(a, b) return a._Order < b._Order; end);
	pos = Vector2.new(pos.X.Offset, pos.Y.Offset);
	size = Vector2.new(size.X.Offset, size.Y.Offset);
	local oPos, oSize = pos, size;
	for _, v in pairs(modifiers) do
		if v._Enabled then
			pos, size = v:_ConvertCoordinates(pos, size, oPos, oSize);
		end
	end
	return UDim2.new(0, pos.x, 0, pos.y), UDim2.new(0, size.x, 0, size.y);
end
function GuiBase2d:_Reflow(dontPlaceChildren)
	--If we're invisible, don't bother with the Reflow.
	if not self._Visible then
		return;
	end

	--Halt! If any parents want to do a reflow first, now would be the best time as they might influence the pos/size this object gets.
	local parent = self._Parent;
	while parent and type(parent)=='table' and parent:IsA("GuiBase2d") and not parent._TriggerReflow.Dirty do
		parent = parent._Parent;
	end
	if parent and type(parent)=='table' and parent:IsA("GuiBase2d") then
		parent:_ConditionalReflow();
	end

	--Ok, now we can run _Reflow.
	Debug("GuiBase2d._Reflow(%s) called", self);
	Debug("\tPlacement Coordinates: <%s>, <%s>", self._PlacementPosition, self._PlacementSize);
	Debug("\tUser Coordinates: <%s>, <%s>", self._UserPosition, self._UserSize);
	if not self._Parent or not self._Parent:IsA("GuiBase2d") then
		return UDim2.new(), UDim2.new(1, 0, 1, 0);
	end
	if self._FlagReorderChildren then
		self:_OrderChildrenOnZIndex();
	end
	local pos, size = self._PlacementPosition, self._PlacementSize;
	--Convert pos/size to pixel counts only.
	if pos.X.Scale ~= 0 or pos.Y.Scale ~= 0 or size.X.Scale ~= 0 or size.Y.Scale ~= 0 then
		if not self._Parent then
			return UDim2.new(), UDim2.new();
		end
		local sz = self._Parent.AbsoluteSize;
		pos = UDim2.new(
			0, pos.X.Scale * sz.x + pos.X.Offset,
			0, pos.Y.Scale * sz.y + pos.Y.Offset
		)
		size = UDim2.new(
			0, size.X.Scale * sz.x + size.X.Offset,
			0, size.Y.Scale * sz.y + size.Y.Offset
		)
	end
	pos = pos + UDim2.new(0, size.X.Offset * self._UserPosition.X.Scale + self._UserPosition.X.Offset, 0, size.Y.Offset * self._UserPosition.Y.Scale + self._UserPosition.Y.Offset);
	size = UDim2.new(0, size.X.Offset * self._UserSize.X.Scale + self._UserSize.X.Offset, 0, size.Y.Offset * self._UserSize.Y.Scale + self._UserSize.Y.Offset);
	Debug("\tAbsolute Size: <%s>; Transformed Coordinates: <%s>, <%s>", (self._Parent or {AbsoluteSize=Vector2.new()}).AbsoluteSize, pos, size);

	--Apply all modifiers
	pos, size = self:_ApplyModifiers(pos, size);
	Debug("\tPost-Modified Coordinates: <%s>, <%s>", pos, size);

	--Set absolute size/position.
	self._AbsoluteSize = Vector2.new(size.X.Offset, size.Y.Offset);
	self._AbsolutePosition = self._Parent.AbsolutePosition + Vector2.new(pos.X.Offset, pos.Y.Offset);
	Debug("Assigning %s.AbsolutePosition = %s", self, self._AbsolutePosition);

	--Place the handle at the expected location.
	if self:_GetRbxHandle() then
		self:_GetRbxHandle().Position = pos;
		self:_GetRbxHandle().Size = size;
		if not dontPlaceChildren then
			for i, v in pairs(self:GetChildren()) do
				if v:IsA("GuiBase2d") then
					v._Size = size;
					v._Position = UDim2.new();
					v:_ConditionalReflow();
				end
			end
		end
	else
		if not dontPlaceChildren then
			for i, v in pairs(self:GetChildren()) do
				if v:IsA("GuiBase2d") then
					v._Size = size;
					v._Position = pos;
					v:_ConditionalReflow();
				end
			end
		end
	end

	return pos, size;
end
function GuiBase2d:_ForceReflow()
	self._TriggerReflow();
	self._TriggerReflow:RunIfReady();
end
function GuiBase2d:_QueueReflow()
	self._TriggerReflow();
end
function GuiBase2d:_ConditionalReflow()
	self._TriggerReflow:RunIfReady();
end
function GuiBase2d:_OrderChildrenOnZIndex()
	Debug("GuiBase2d._OrderChildrenOnZIndex(%s) called", self);
	--Sort children based on ZIndex.
	local children = Utils.Table.ArrayCopyOnCondition(self._Children, function(v) return v:IsA("GuiBase2d"); end);
	Utils.Table.StableSort(children, function(a, b) return a._ZIndex < b._ZIndex; end);
	Debug("\tChildren Order: %t", children);
	Debug("\tLast: %t", self._ChildrenOrder);
	Debug("\tInternal: %t", self._Children);
	--Iterate through children and reparent once one out of order one occurs.
	local lastChildren = self._ChildrenOrder;

	--Iterate until the first out-of-order child is found.
	local i = 1;
	while children[i] and (children[i] == lastChildren[i] or children[i] == self._Children[i]) do
		i = i + 1;
	end
	Debug("Reparenting all after %d", i);
	local parents = {};
	for j = #children, i, -1 do
		parents[j] = children[j].Parent;
		children[j].ParentNoNotify = nil;
	end
	for j = i, #children do
		children[j].ParentNoNotify = parents[j];
	end
	self._ChildrenOrder = lastChildren;
	self._FlagReorderChildren = false;
end

function GuiBase2d:_AddChild(child)
	Super._AddChild(self, child);
	self._FlagReorderChildren = true;
	self._TriggerReflow();
end

function GuiBase2d.new()
	local self = setmetatable(Super.new(), GuiBase2d.Meta);
	self._PlacementPosition = UDim2.new();
	self._PlacementSize = UDim2.new(1, 0, 1, 0);
	self._TriggerReflow = Utils.new("DelayOperation");
	self._TriggerReflow.OnTrigger = function()
		local t = {};
		do
			local m = self._Parent;
			while m and type(m) == 'table' do
				table.insert(t, m);
				m = m._Parent;
			end
		end
		for i = #t, 1, -1 do
			if t[i]:IsA("GuiBase2d") then
				t[i]:_ConditionalReflow();
			end
		end
		self:_Reflow()
	end;
	self._TriggerReflow();
	return self;
end

-----------
-- Tests --
-----------

function Gui.Test.GuiBase2d_ReflowOnChanged(sgui, cgui)
	local f = Instance.new("Frame", sgui);
	local g = GuiBase2d.new();
	local n = 0;
	g._TriggerReflow = setmetatable({RunIfReady=function() end}, {__call = function() g:_Reflow(); n = n + 1; end});
	g.Parent = f;
	Utils.Log.Assert(n>0, "_TriggerReflow Call Count expected to exceed 1");
	local m = n;
	f.Size = UDim2.new(0, 20, 0, 20);
	g:_ConditionalReflow();
	Utils.Log.Assert(n>m, "_TriggerReflow Call Count expected to exceed %d", m);
	Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(20, 20), g.AbsoluteSize);
end
function Gui.Test.GuiBase2d_SetSize(sgui, cgui)
	local g = GuiBase2d.new();
	local f = Instance.new("Frame");
	g._GetRbxHandle = function() return f; end
	g.Parent = sgui;
	Utils.Log.AssertEqual("frame.Parent", sgui, f.Parent);
	g._Position = UDim2.new(0, 25, 0, 25);
	g._Size = UDim2.new(0, 50, 0, 50);
	g:_ConditionalReflow();
	Utils.Log.AssertEqual("frame.Size", UDim2.new(0, 50, 0, 50), f.Size);
	Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(50, 50), g.AbsoluteSize);
	Utils.Log.AssertEqual("frame.Position", UDim2.new(0, 25, 0, 25), f.Position);
	Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(25, 25), g.AbsolutePosition - sgui.AbsolutePosition);
end
function Gui.Test.GuiBase2d_ReflowCascade(sgui, cgui)
	-------------------------------------------
	-- Part 1: frame --> f (no handle) --> g --
	-------------------------------------------
	do
		local frame = Instance.new("Frame", sgui);
		frame.Position = UDim2.new(0, 150, 0, 150);
		frame.Size = UDim2.new(0, 100, 0, 100);

		local f = GuiBase2d.new();
		f.Parent = frame;

		local g = GuiBase2d.new();
		g.Parent = f;

		f:_ConditionalReflow();
		g:_ConditionalReflow();
		Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(100, 100), g.AbsoluteSize);

		frame.Size = UDim2.new(0, 200, 0, 200);
		f:_ConditionalReflow();
		g:_ConditionalReflow();
		Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(200, 200), g.AbsoluteSize);
	end
	-------------------------------------------
	-- Part 2: frame --> f (w/ handle) --> g --
	-------------------------------------------
	do
		local frame = Instance.new("Frame", sgui);
		frame.Position = UDim2.new(0, 150, 0, 150);
		frame.Size = UDim2.new(0, 100, 0, 100);

		local f = GuiBase2d.new();
		local fFrame = Instance.new("Frame");
		f._GetRbxHandle = function() return fFrame; end
		f.Parent = frame;

		local g = GuiBase2d.new();
		g.Parent = f;

		f:_ConditionalReflow();
		g:_ConditionalReflow();
		Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(100, 100), g.AbsoluteSize);
		frame.Size = UDim2.new(0, 200, 0, 200);
		f:_ConditionalReflow();
		g:_ConditionalReflow();
		Utils.Log.AssertEqual("g.AbsoluteSize", Vector2.new(200, 200), g.AbsoluteSize);
	end
end

function Gui.Test.GuiBase2d_ApplyModifiers(sgui, cgui)
	local g = GuiBase2d.new();
	g.Parent = sgui;
	local m = Gui.new("MinimumSizeModifier");
	m.Size = Vector2.new(100, 100);
	m.Parent = g;
	local pos, size = g:_ApplyModifiers(UDim2.new(0, 40, 0, 40), UDim2.new(0, 50, 0, 50));
	Utils.Log.AssertEqual("Position", UDim2.new(0, 40, 0, 40), pos);
	Utils.Log.AssertEqual("Size", UDim2.new(0, 100, 0, 100), size);
	m.Enabled = false;
	local pos, size = g:_ApplyModifiers(UDim2.new(0, 40, 0, 40), UDim2.new(0, 50, 0, 50));
	Utils.Log.AssertEqual("Position", UDim2.new(0, 40, 0, 40), pos);
	Utils.Log.AssertEqual("Size", UDim2.new(0, 50, 0, 50), size);
end

return GuiBase2d;
