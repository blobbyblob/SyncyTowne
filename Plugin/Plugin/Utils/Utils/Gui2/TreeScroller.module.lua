--[[

A TreeScroller displays a hierarchy of items. It maintains its own notion of folding/unfolding and a hierarchy.
It will create a vertical list of entries which, if they have children, can be unfolded revealing their children.
Children are indented in relation to their parent.

Properties:
	Root: an object to serve as the root of the hierarchy.
	QueryChildren(obj): a function which returns the children of obj.
	FormatEntry(obj, entry): requests that the user format "entry". It will have two children: "Icon", an ImageLabel, and "Label", a TextLabel.
	ShowRoot: a boolean which, when true, indicates that the root object will be shown.

Methods:
	SetFolded(obj, isFolded): sets whether obj is folded. false means the children will be shown.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local View = require(script.Parent.View);
local Gui = _G[script.Parent];
local Test = Gui.Test;

local Debug = Log.new("TreeScroller", true);

local TreeScroller = Utils.new("Class", "TreeScroller", View);
local Super = TreeScroller.Super;

-------------------
-- Properties --
-------------------
TreeScroller._GridScroller = false; --! A backing GridScroller object.
TreeScroller._UnfoldedMap = false; --! A map of obj --> true if they should be unfolded.
TreeScroller._Cxns = false; --! A ConnectionHolder.
TreeScroller._ChildPlacements = false; --! A helper object for a Gui wrapper class.
TreeScroller._IndexMap = {}; --! A map of index --> obj where [1] = Root
TreeScroller._DepthMap = {}; --! A map of [obj] --> depth where [Root] = 1.

--TreeScroller._Hierarchy = false; --! A list of indices which indicate how to get from the root to the current top-most element in the list.
--TreeScroller._Children = false; --! A place to cache the results of GetChildren.
--[[ Navigating Hierarchy
	The topmost element in the list can be found by doing the following:

	local element = root;
	for _, index in pairs(self._Hierarchy) do
		element = self._Children[element][index];
	end
--]]

TreeScroller._Root = false; --! The topmost element in the hierarchy.
TreeScroller._IsRootShown = false; --! Indicates whether the topmost element should be shown.
TreeScroller._QueryChildren = function(obj) return obj:GetChildren(); end; --! A function which returns the children of obj.
TreeScroller._FormatEntry = function(obj, entry) entry.Text = obj.Name; end; --! A function which configures 'entry' to display properly.

TreeScroller.Set.Root = "_Root";
TreeScroller.Set.QueryChildren = "_QueryChildren";
TreeScroller.Set.FormatEntry = "_FormatEntry";
TreeScroller.Set.ShowRoot = "_IsRootShown";
TreeScroller.Get.Root = "_Root";
TreeScroller.Get.QueryChildren = "_QueryChildren";
TreeScroller.Get.FormatEntry = "_FormatEntry";
TreeScroller.Get.ShowRoot = "_IsRootShown";

----------------
-- Methods --
----------------
function TreeScroller:Destroy()
	self._GridScroller:Destroy();
	Super.Destroy(self);
end

function TreeScroller:SetFolded(obj, isFolded)
	--Not Doing: implement this.
	self._UnfoldedMap[obj] = not isFolded;
end

function TreeScroller:_OpenElement(obj)
	--Connect to obj.ChildAdded and obj.ChildRemoved.
	
	--Locate the obj in the hierarchy.
	
end

function TreeScroller:_Update()
	Debug("TreeScroller._Update(%s) called", self);
	--Count the total number of indices in the hierarchy:
	local function GetCount(r, k, depth)
		self._IndexMap[k] = r;
		self._DepthMap[r] = depth;
		local i = 1;
		local children = self._QueryChildren(r);
		for _, v in ipairs(children) do
			i = i + GetCount(v, k + i, depth + 1);
		end
		return i;
	end
	local count = GetCount(self._Root, 1, 1);
	Debug("Count: %s", count);
	Debug("IndexMap: %t", self._IndexMap);

	--Set the underlying grid scroller's MaxIndex.
	self._GridScroller.MaxIndex = count;
	self._GridScroller.MinIndex = 1;
end

----------------------------------------------
-- Required functions for wrapping --
----------------------------------------------

function TreeScroller.Set:Parent(v)
	self._GridScroller.ParentNoNotify = v;
	if v then
		self:_Update();
	end
	Super.Set.Parent(self, v);
end
function TreeScroller.Set:ParentNoNotify(v)
	self._GridScroller.ParentNoNotify = v;
	if v then
		self:_Update();
	end
	Super.Set.ParentNoNotify(self, v);
end

function TreeScroller:_GetHandle()
	return self._GridScroller:_GetHandle();
end

function TreeScroller:_GetChildContainerRaw(child)
	return self._GridScroller:_GetChildContainerRaw(child);
end
function TreeScroller:_GetChildContainer(child)
	return self._GridScroller:_GetChildContainer(child);
end

function TreeScroller:_AddChild(child)
	self._ChildPlacements:AddChildTo(child, self._GridScroller);
	Super._AddChild(self, child);
end
function TreeScroller:_RemoveChild(child)
	self._ChildPlacements:RemoveChild(child);
	Super._RemoveChild(self, child);
end

function TreeScroller:_ForceReflow()
	Super._ForceReflow(self);
	self._GridScroller:_ForceReflow();
end
function TreeScroller:_Reflow(pos, size)
	self._GridScroller:_SetPPos(pos);
	self._GridScroller:_SetPSize(size);
end

function TreeScroller:Clone()
	local new = Super.Clone(self);
	new.Values = self.Values;
	return new;
end

function TreeScroller.new()
	local self = setmetatable(Super.new(), TreeScroller.Meta);
	self._ChildPlacements = Gui.ChildPlacements();
	self._GridScroller = Gui.new("GridScroller");
	self._Cxns = Utils.new("ConnectionHolder");
--	self._UnfoldedMap = {};
	self._IndexMap = {};
	self._DepthMap = {};
	self._GridScroller.GridDefault = {
		OrthogonalElements = 1;
		Cushion = Vector3.new(4, 4);
		LinearSize = 20;
		AspectRatio = 0;
	};
	function self._GridScroller.UpdateDefault(gs, gui, index)
		local obj = self._IndexMap[index];
		local indent = (self._DepthMap[obj] - 1) * 15;
		gui.Size = UDim2.new(1, -indent, 1, 0);
		gui.Position = UDim2.new(0, indent, 0, 0);
		self._FormatEntry(obj, gui);
	end
	function self._GridScroller:CreateDefault()
		local x = Gui.new("TextButton");
		x.Name = "TreeElement";
		local y = Gui.new("TextLabel", x);
		y.Name = "Label";
		y.Size = UDim2.new(1, -30, 1, 0);
		y.Position = UDim2.new(0, 30, 0, 0);
		local z = Gui.new("ImageLabel", x);
		z.Name = "Icon";
		z.Size = UDim2.new(0, 20, 0, 20);
		z.Position = UDim2.new();
		return x;
	end
	return self;
end

if true then
--[[ @brief Create a small hierarchy and attempt to render it.
--]]
function Test.TreeScroller_Simple(sgui, sgui)
	local ts = Gui.new("TreeScroller");
	ts.Root = {
		Name = "a";
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
		{Name = "e";};
		{	Name = "f";
			{Name = "g";};
		};
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
		{	Name = "b";
			{Name = "c";};
			{Name = "d";};
		};
	};
	function ts.QueryChildren(obj)
		return obj;
	end
	function ts.FormatEntry(obj, entry)
		Debug("FormatEntry(%s, %s) called", obj, entry);
		entry.Label.Text = obj.Name;
		entry.BorderSizePixel = 1;
	end
	ts.Size = UDim2.new(0.5, 0, 0.5, 0);
	ts.Position = UDim2.new(0.25, 0, 0.25, 0);
	ts.Parent = sgui;
end

end

return TreeScroller;
