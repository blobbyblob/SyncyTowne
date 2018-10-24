local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Instance: ", false);

local EventLoaderBuilder = Utils.new("EventLoaderBuilder");
EventLoaderBuilder.Events = {"Changed", "ChildAdded", "ChildRemoved", "AncestryChanged", "DescendantAdded", "DescendantRemoving"};
EventLoaderBuilder.EventConstructor = Utils.new.Event;

local ChangedEventLoaderBuilder = Utils.new("EventLoaderBuilder");
ChangedEventLoaderBuilder.EventConstructor = Utils.new.Event;

local RawInstance = Instance; --The ROBLOX instance class.

--Once an instance is parented to this, any attempts to reparent it will be met with an error.
local LOCKED_PARENT;

function IS_GUI_TYPE(v)
	return type(v)=='table';
end

-- AncestryChangedWatchlist is a helper construct for the AncestryChanged event. Turns out, this is a really expensive event to listen on. I went through great effort to optimize it. Fortunately, it's not very popular.
local AncestryChangedWatchlist = setmetatable({}, {__mode='k'});
--[[ @brief Indicates that when an object's parent is changed, an event should fire.
     @details This event will ripple up the parent chain until a non-Instance or "nil" is found.
     @param event The event which fires.
     @param object The object we watch on.
--]]
local function AddEventToWatchlist(event, object)
	Debug("AddEventToWatchlist(%s, %s) called", event, object);
	if object and IS_GUI_TYPE(object) then
		if not AncestryChangedWatchlist[object] then
			AncestryChangedWatchlist[object] = {};
		end
		AncestryChangedWatchlist[object][event] = true;
		return AddEventToWatchlist(event, object._Parent);
	end
end
--[[ @brief Indicate that an object is no longer a trigger for a set of events.
     @param events A map of events.
     @param object An object from which we remove events as triggers.
     @details This function will ripple up the parent chain.
--]]
local function RemoveEventsFromWatchlist(events, object)
	Debug("RemoveEventsFromWatchlist(%t, %s) called", events, object);
	if object and IS_GUI_TYPE(object) then
		if AncestryChangedWatchlist[object] then
			for event in pairs(events) do
				AncestryChangedWatchlist[object][event] = nil;
			end
		end
		return RemoveEventsFromWatchlist(events, object._Parent);
	end
end
--[[ @brief Indicate that an object should become a trigger for a set of events.
     @param events A map of events [BindableEvent] -> true.
     @param object An object which we should watch on for Parent changes.
     @details This function will ripple up the parent chain.
--]]
local function AddEventsToWatchlist(events, object)
	Debug("AddEventsToWatchlist(%t, %s) called", events, object);
	if object and IS_GUI_TYPE(object) then
		if not AncestryChangedWatchlist[object] then
			AncestryChangedWatchlist[object] = {};
		end
		for event in pairs(events) do
			AncestryChangedWatchlist[object][event] = true;
		end
		return AddEventsToWatchlist(events, object._Parent);
	end
end
--[[ @brief Gets the map of events which should fire when object's parent is changed.
     @param object The object whose watchlist we should check.
--]]
local function GetObjectWatchlist(object)
	return AncestryChangedWatchlist[object];
end

local Instance = Utils.new("Class", "Instance");

Instance._Name = "Instance";
Instance._Parent = false; --! The parent of this element.
Instance._ParentWasNotified = true; --! True if the parent was notified that it has this element as its child. This will dictate whether we notify the parent upon removing the child.
Instance._EventLoader = false; --! An EventLoader for most events.
Instance._ChangedEventLoader = false; --! An EventLoader for all changed events.
Instance._Children = false; --! A list of children.
Instance.Archivable = true;

Instance.Get.Name = "_Name";
function Instance.Set:Name(name)
	self._Name = name;
	self._EventLoader:FireEvent("Changed", "Name");
end
function Instance:_SetParent(parent, triggerEvents)
	Debug("%s.Parent = %s%s", self, parent, not triggerEvents and " (no notify)" or "");
	local fireChildRemoved, fireChildAdded;
	--Kill the link from (old parent) --> this
	if self._Parent and IS_GUI_TYPE(self._Parent) then
		self._Parent:_RemoveChild(self)
		if self._ParentWasNotified then
			fireChildRemoved = self._Parent;
			local p = self._Parent;
			while p and IS_GUI_TYPE(p) do
				p._EventLoader:FireEvent("DescendantRemoving", self);
				if p._ParentWasNotified then
					p = p._Parent;
				else
					p = nil;
				end
			end
		end
		if GetObjectWatchlist(self) then
			RemoveEventsFromWatchlist(GetObjectWatchlist(self), self._Parent);
		end
	end
	--Error check: if you can follow the parent up until it reaches "self", we're about to do something awful.
	local p = parent; while p and p ~= self and IS_GUI_TYPE(p) do p = p._Parent; end
	if p == self then
		Utils.Log.Error("Circular hierarchy detected; attempted to set %s.Parent = %s", self, parent);
	end
	--Create a link from this --> (new parent) & kill link from (old parent) --> this simultaneously.
	self._Parent = parent;
	self._ParentWasNotified = triggerEvents;
	--Create a link from (new parent) --> this.
	if self._Parent and IS_GUI_TYPE(self._Parent) then
		self._Parent:_AddChild(self);
		if self._ParentWasNotified then
			fireChildAdded = self._Parent;
			local p = self._Parent;
			while p and IS_GUI_TYPE(p) do
				p._EventLoader:FireEvent("DescendantAdded", self);
				if p._ParentWasNotified then
					p = p._Parent;
				else
					p = nil;
				end
			end
		end
		if GetObjectWatchlist(self) then
			AddEventsToWatchlist(GetObjectWatchlist(self), self._Parent);
		end
	end

	--fireChildRemoved/Added will only be non-nil if the parent they refer to is a "Gui" type (from this library) and they were/are not set with ParentNoNotify.
	if fireChildRemoved then
		fireChildRemoved._EventLoader:FireEvent("ChildRemoved", self);
	end
	if fireChildAdded then
		fireChildAdded._EventLoader:FireEvent("ChildAdded", self);
	end
	self._EventLoader:FireEvent("Changed", "Parent");
	if GetObjectWatchlist(self) then
		for event in pairs(GetObjectWatchlist(self)) do
			event:Fire(self, self._Parent);
		end
	end
end
Instance.Get.Parent = "_Parent";
function Instance.Set:Parent(parent)
	self:_SetParent(parent, true);
end
function Instance.Set:ParentNoNotify(parent)
	self:_SetParent(parent, false);
end
EventLoaderBuilder:PopulateGetters(Instance.Get, "_EventLoader");

function Instance:_RemoveChild(child)
	for i, v in pairs(self._Children) do
		if v==child then
			table.remove(self._Children, i);
			return;
		end
	end
	Utils.Log.Error("Attempted to remove invalid child %s from parent %s", child, self);
end

function Instance:_AddChild(child)
	table.insert(self._Children, child);
end

function Instance:__tostring()
	return self._Name == "" and self.ClassName or self._Name;
end

---------------------------------------------
-- Methods implementing base roblox methods.

function Instance:ClearAllChildren()
	for i = #self._Children, 1, -1 do
		self._Children[i].Parent = nil;
	end
end
function Instance:Clone()
	--Create a new instance of the current class, then invoke the _Clone method for each class between the current and Instance.
	local class = self.__Class;
	local v = class.new();

	local cloneFunctions = {};
	while class do
		if class._Clone ~= nil and cloneFunctions[#cloneFunctions] ~= class._Clone then
			table.insert(cloneFunctions, class._Clone);
		end
		if class == Instance then break; end
		class = class.Super;
	end
	Debug("cloneFunctions: %t", cloneFunctions);
	for i = #cloneFunctions, 1, -1 do
		cloneFunctions[i](self, v);
	end
	return v;
end
function Instance:_Clone(new)
	new.Name = self.Name;
	for i, v in pairs(self._Children) do
		Debug("Child %s has Archivable = %s", v, v.Archivable);
		if v.Archivable then
			v:Clone().Parent = new;
		end
	end
end
function Instance:Destroy()
	self.Parent = LOCKED_PARENT;
	for eventName, event in self._EventLoader:pairs() do
		Debug("event: %s (%s) = %t", event, typeof(event), event);
		event:Destroy();
	end
end
function Instance:FindFirstChild(name, recurse)
	for i, v in pairs(self._Children) do
		if v.Name == name then
			return v;
		elseif recurse then
			local v = v:FindFirstChild(name, recurse);
			if v then
				return v;
			end
		end
	end
end
function Instance:__index(name)
	local child = self:FindFirstChild(name);
	if not child then
		Utils.Log.Error(3, "%s is not a valid member of %s", name, self);
	end
	return child;
end
function Instance:FindFirstChildOfClass(className)
	--This seems like a really unnecessary function...
	for i, v in pairs(self._Children) do
		if v.ClassName == className then
			return v;
		end
	end
end
function Instance:GetChildren()
	return Utils.Table.ShallowCopy(self._Children);
end
function Instance:GetFullName()
	local s = {};
	while self do
		table.insert(s, 1, self.Name);
		self = self._Parent;
	end
	return table.concat(s, '.');
end
function Instance:GetPropertyChangedSignal(property)
	if not self._ChangedEventLoader then
		self._ChangedEventLoader = ChangedEventLoaderBuilder:Instantiate();
		self.Changed:connect(function(property)
			self._ChangedEventLoader:FireEvent(property);
		end)
	end
	return self._ChangedEventLoader[property];
end
function Instance:IsAncestorOf(other)
	other = other.Parent;
	while other and other ~= self do
		other = other.Parent;
	end
	return self == other;
end
function Instance:IsDescendantOf(other)
	self = self.Parent;
	while self and self ~= other do
		self = self.Parent;
	end
	return self == other;
end
function Instance:WaitForChild(childName, timeout)
	local event = RawInstance.new("BindableEvent");
	local cxn = self.ChildAdded:connect(function()
		event:Fire();
	end)
	local TerminateTime = tick() + timeout;
	spawn(function() wait(timeout); if event then event:Fire(); end end);
	while self:FindFirstChild(childName) == nil and tick() < TerminateTime do
		event.Event:wait()
	end
	cxn:disconnect();
	event = nil;
	return self:FindFirstChild(childName);
end

function Instance.new()
	local self = setmetatable({}, Instance.Meta);
	self._Children = {};
	self._EventLoader = EventLoaderBuilder:Instantiate();
	self._EventLoader.OnEventCreated = function(event)
		if event == "AncestryChanged" then
			local eventObj = self._EventLoader[event];
			AddEventToWatchlist(eventObj, self);
		end
	end
	return self;
end

LOCKED_PARENT = Instance.new();
function LOCKED_PARENT:_RemoveChild(child)
	Utils.Log.Error(4, "Attempt to reparent destroyed child %s", child);
end

-----------
-- Tests --
-----------

function Gui.Test.Instance_SetParent()
	local v1 = Instance.new();
	local v2 = Instance.new();
	local v3 = Instance.new();
	v3.Parent = v2;
	v2.Parent = v1;
	Utils.Log.AssertEqual("v3.Parent.Parent", v1, v3.Parent.Parent);
	Utils.Log.AssertEqual("v1.Parent = v3 success", false, pcall(function() v1.Parent = v3; end));
	Utils.Log.AssertEqual("v1.Parent", nil, v1.Parent or nil);
end

function Gui.Test.Instance_Events()
	local v1 = Instance.new();
	v1.Name = "Instance 1";
	local v2 = Instance.new();
	v2.Name = "Instance 2";
	local v3 = Instance.new();
	v3.Name = "Instance 3";
	local childAddedCount = 0;
	local childRemovedCount = 0;
	local descendantAddedCount = 0;
	local descendantRemovingCount = 0;
	local ancestryChangedCount = 0;
	for i, v in pairs({v1, v2, v3}) do
		v.ChildAdded:connect(function() childAddedCount = childAddedCount + 1; end);
		v.ChildRemoved:connect(function() childRemovedCount = childRemovedCount + 1; end);
		v.DescendantAdded:connect(function() descendantAddedCount = descendantAddedCount + 1; end);
		v.DescendantRemoving:connect(function() descendantRemovingCount = descendantRemovingCount + 1; end);
		v.AncestryChanged:connect(function() ancestryChangedCount = ancestryChangedCount + 1; end);
	end
	v2.Parent = v1;
	v3.Parent = v2;
	Utils.Log.AssertEqual("childAddedCount 1", 2, childAddedCount);
	Utils.Log.AssertEqual("childRemovedCount 1", 0, childRemovedCount);
	Utils.Log.AssertEqual("descendantAddedCount 1", 3, descendantAddedCount);
	Utils.Log.AssertEqual("descendantRemovingCount 1", 0, descendantRemovingCount);
	Utils.Log.AssertEqual("ancestryChangedCount 1", 2, ancestryChangedCount);
	v2.Parent = nil;
	v3.Parent = nil;
	Utils.Log.AssertEqual("childAddedCount 2", 2, childAddedCount);
	Utils.Log.AssertEqual("childRemovedCount 2", 2, childRemovedCount);
	Utils.Log.AssertEqual("descendantAddedCount 2", 3, descendantAddedCount);
	Utils.Log.AssertEqual("descendantRemovingCount 2", 2, descendantRemovingCount);
	Utils.Log.AssertEqual("ancestryChangedCount 2", 5, ancestryChangedCount);
	v3.Parent = v2;
	v2.Parent = v1;
	Utils.Log.AssertEqual("childAddedCount 3", 4, childAddedCount);
	Utils.Log.AssertEqual("childRemovedCount 3", 2, childRemovedCount);
	Utils.Log.AssertEqual("descendantAddedCount 3", 5, descendantAddedCount);
	Utils.Log.AssertEqual("descendantRemovingCount 3", 2, descendantRemovingCount);
	Utils.Log.AssertEqual("ancestryChangedCount 3", 8, ancestryChangedCount);

	Utils.Log.AssertEqual("#AncestryChangedWatchlist[v1]", 3, Utils.Table.CountMapEntries(GetObjectWatchlist(v1)));
	Utils.Log.AssertEqual("#AncestryChangedWatchlist[v2]", 2, Utils.Table.CountMapEntries(GetObjectWatchlist(v2)));
	Utils.Log.AssertEqual("#AncestryChangedWatchlist[v3]", 1, Utils.Table.CountMapEntries(GetObjectWatchlist(v3)));

	v3.Parent = nil;
	v2.Parent = nil;
	Utils.Log.AssertEqual("childAddedCount 2", 4, childAddedCount);
	Utils.Log.AssertEqual("childRemovedCount 2", 4, childRemovedCount);
	Utils.Log.AssertEqual("descendantAddedCount 2", 5, descendantAddedCount);
	Utils.Log.AssertEqual("descendantRemovingCount 2", 5, descendantRemovingCount);
	Utils.Log.AssertEqual("ancestryChangedCount 2", 10, ancestryChangedCount);
end

function Gui.Test.Instance_Traverse()
	local v1 = Instance.new();
	local v2 = Instance.new();
	local v3 = Instance.new();
	v1.Name = "Parent";
	v2.Name = "Child1";
	v3.Name = "Child2";
	v2.Parent = v1;
	v3.Parent = v1;
	Utils.Log.AssertEqual("v1.Child1", v2, v1.Child1);
	Utils.Log.AssertEqual("v1:FindFirstChild('Child1')", v2, v1:FindFirstChild('Child1'));
	Utils.Log.AssertEqual("v1.Child2", v3, v1.Child2);
	Utils.Log.AssertEqual("v1:FindFirstChild('Child2')", v3, v1:FindFirstChild('Child2'));
	for i, v in pairs(v1:GetChildren()) do
		Utils.Log.Assert(v==v2 or v==v3, "Children of %s must only be %s or %s", v1, v2, v3);
	end
	v3.Parent = v2;
	Utils.Log.AssertEqual("v3.Path", "Parent.Child1.Child2", v3:GetFullName());
	Utils.Log.AssertEqual("v3:IsDescendantOf(v1)", true, v3:IsDescendantOf(v1));
	Utils.Log.AssertEqual("v1:IsDescendantOf(v3)", false, v1:IsDescendantOf(v3));
	Utils.Log.AssertEqual("v1:IsDescendantOf(v1)", false, v1:IsDescendantOf(v1));
	Utils.Log.AssertEqual("v3:IsAncestorOf(v1)", false, v3:IsAncestorOf(v1));
	Utils.Log.AssertEqual("v1:IsAncestorOf(v3)", true, v1:IsAncestorOf(v3));
	Utils.Log.AssertEqual("v1:IsAncestorOf(v1)", false, v1:IsAncestorOf(v1));
end

function Gui.Test.Instance_CreateDestroy()
	local v1, v2 = Instance.new(), Instance.new();
	v2:Destroy();
	local success, errmsg = pcall(function() v2.Parent = v1; end);
	Utils.Log.Assert(not success, "Setting parent of destroyed object should fail");
end

function Gui.Test.Instance_Events2()
	local v1 = Instance.new();
	local v2 = Instance.new();
	spawn(function() v2.Parent = v1; end);
	Utils.Log.AssertEqual("v1:WaitForChild('Instance', 0)", nil, v1:WaitForChild('Instance', 0));
	Utils.Log.AssertEqual("v1:WaitForChild('Instance', 1)", v2, v1:WaitForChild('Instance', 1));
	Utils.Log.AssertEqual("v1:WaitForChild('Instance', 0)", v2, v1:WaitForChild('Instance', 0));

	local n = 0;
	v1:GetPropertyChangedSignal("Name"):connect(function()
		n = n + 1;
	end);
	Utils.Log.AssertEqual("NameChangedCount", 0, n);
	v1.Name = "V1";
	coroutine.yield();
	Utils.Log.AssertEqual("NameChangedCount", 1, n);
	v1.Name = "V2";
	v1.Name = "V2";
	coroutine.yield();
	Utils.Log.Assert(2 <= n and n <= 3, "invalid value for NameChangedCount; expected %s, got %s", "2 or 3", n);
end

function Gui.Test.Instance_Clone()
	local i = Instance.new();
	i.Name = "i";
	local i1 = Instance.new();
	i1.Parent = i;
	i1.Name = "i1";
	local i2 = Instance.new();
	i2.Parent = i;
	i2.Name = "i2";

	local j = i:Clone();
	Utils.Log.AssertEqual("j.Name", "i", j.Name);
	Utils.Log.AssertEqual("not j.i1", false, not j.i1);
	Utils.Log.AssertEqual("not j.i2", false, not j.i2);
end

function Gui.Test.Instance_Changed()
	local events = {"Name", "Parent"};
	local i = Instance.new();
	i.Changed:connect(function(prop)
		Utils.Log.AssertEqual("Changed event", events[1], prop);
		table.remove(events, 1);
	end)

	i.Name = "test";
	local j = Instance.new();
	i.Parent = j;
end

function Gui.Test.Instance_Archivable()
	local s = Instance.new();
	local i = Instance.new();
	i.Name = "i";
	i.Archivable = false;
	i.Parent = s;
	local j = Instance.new();
	j.Name = "j";
	j.Parent = s;
	local t = s:Clone();
	Utils.Log.AssertEqual("i.Archivable", false, i.Archivable);
	Utils.Log.AssertEqual("j.Archivable", true, j.Archivable);
	Utils.Log.AssertEqual("j", false, not t:FindFirstChild("j"));
	Utils.Log.AssertEqual("i", true, not t:FindFirstChild("i"));
end

return Instance;
