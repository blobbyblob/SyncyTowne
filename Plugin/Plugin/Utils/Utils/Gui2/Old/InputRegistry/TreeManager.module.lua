--[[

Submit the root, then search for a list of 

--]]

local lib = script.Parent.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);
local Utils = require(lib.Utils);

local Tree = Class.new("TreeManager");

Tree._Root = false;
Tree._Cxns = false;
Tree._DescendantAdded = false;
Tree._DescendantRemoving = false;
Tree._ClassFilter = "Instance";

Tree.Set.ClassFilter = "_ClassFilter";
Tree.Get.ClassFilter = "_ClassFilter";
Tree.Get.DescendantAdded = "_DescendantAdded";
Tree.Get.DescendantRemoving = "_DescendantRemoving";

local function SeekAllOfClass(root, class, t)
	if not t then t = {}; end
	if root:IsA(class) then
		table.insert(t, root);
	end
	for i, v in pairs(root:GetChildren()) do
		SeekAllOfClass(v, class, t);
	end
	return t;
end

function Tree.Set:Root(element)
	if self._Root then
		self._Cxns:Disconnect("DescendantAdded");
		self._Cxns:Disconnect("DescendantRemoving");
		local t = SeekAllOfClass(self._Root, self._ClassFilter);
		for i, v in pairs(t) do
			if v:IsA(self._ClassFilter) then
				self._DescendantRemoving:Fire(v);
			end
		end
	end
	self._Root = element;
	if element then
		self._Cxns.DescendantAdded = element.DescendantAdded:connect(function(child)
			if child:IsA(self._ClassFilter) then
				self._DescendantAdded:Fire(child);
			end
		end)
		self._Cxns.DescendantRemoving = element.DescendantRemoving:connect(function(child)
			if child:IsA(self._ClassFilter) then
				self._DescendantRemoving:Fire(child);
			end
		end)
		local t = SeekAllOfClass(element, self._ClassFilter);
		for i, v in pairs(t) do
			self._DescendantAdded:Fire(v);
		end
	end
end

--[[ @brief Traverses the tree, calling f for each element.
     @details The traversal order is the reverse of GetChildren. The root node will be called last. The function f will only be called for a given instance if the instance passes the class filter.
     @param f The function we call for each element. It should take an instance as its argument, and it should return true if we should stop searching.
     @param recurseCriteria A function which is called for all objects which have children. It should return true if we should descend into those children.
     @return True if the traversal was terminated early; false otherwise.
--]]
function Tree:ReverseTraverse(f, recurseCriteria)
	recurseCriteria = recurseCriteria or function() return true; end;
	--@brief Recurse through the tree.
	--@return false if we should quit iterating. True otherwise.
	local function ReverseTraverse(root)
		local children = root:GetChildren();
		if #children>0 and recurseCriteria(root) then
			for i = #children, 1, -1 do
				if not ReverseTraverse(children[i]) then
					return false;
				end
			end
		end
		if root:IsA(self._ClassFilter) then
			local retval = f(root);
			if retval then
				return false;
			end
		end
		return true;
	end

	return not ReverseTraverse(self._Root);
end

function Tree.new()
	local self = setmetatable({}, Tree.Meta);
	self._Cxns = Utils.newConnectionHolder();
	self._DescendantAdded = Utils.newEvent();
	self._DescendantRemoving = Utils.newEvent();
	return self;
end

return Tree;
