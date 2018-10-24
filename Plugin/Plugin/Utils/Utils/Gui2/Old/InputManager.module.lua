--[[

GuiInput Object

	This class allows objects to listen on events. If an object consumes an
event, any object lower than it (z layer) will be unable to consume the same
event unless an exception is made. The exceptions are managed by classes. By
default, all classes occlude all other classes (including themselves). This
can be changed by calling UnsetOcclusion(event, class1, class2).

Constructors:
	--new(): creates a new GuiInput object for a given ScreenGui.
	get(): returns the one and only GuiInput object.
Methods:
	SetObjectClass(obj, class): indicates that an object belongs to a given class.
	Listen(obj, event, callback): listens for an event to occur on obj. An event can be: "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward"
	SetOcclusion(event, classConsuming, classStarving, occlude): indicates that when an event fires, a member of classConsuming will/will not prevent the method from trickling down to any object in classStarving based on the value of occlude. If classConsuming or classStarving are nil, it means that this policy applies for all classes.

Events:
	Hover(isHovering, x, y): fires when the mouse moves while hovering over a part. isHovering will be false when the mouse is no longer hovering over a part.
	Click1(x, y): fires when the mouse clicks on an element.

--]]

local lib = script.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);

local Hover = require(script.Hover);

local Debug = Log.new("InputManager:\t", true);
--A map of event --> occluded indicating whether an event should occlude elements below it (e.g., listening to Click1 forbids two buttons from being clicked at once).
local EVENT_OCCLUDE_DEFAULT = {
	Hover = false;
	MouseWheelForward = true;
	MouseWheelBackward = true;
	Click1 = true;
	Click2 = true;
	Click3 = true;
};

local GuiInput = Class.new("GuiInput");

GuiInput._Classes = false; --! A map of class --> {event --> {class --> isOccludedBool, "DEFAULT" --> isOccludedBool}}
GuiInput._Defaults = false; --! A map of event --> isOccludedBool for when self._Classes has no answer.
GuiInput._Objects = false; --! A map of object --> {class = class, event = {callbacks}}.
GuiInput._Connections = false; --! A list of connections.
GuiInput._Hovering = false; --! A hover object; see script.Hover

local function GetScreenGui(obj)
	if obj==nil then
		return nil;
	elseif obj:IsA("LayerCollector") then
		return obj;
	else
		return GetScreenGui(obj.Parent);
	end
end

--[[ @brief Associates an object with a particular class.
     @param obj The object to be assigned to a class.
     @param class The class to assign to.
--]]
function GuiInput:SetObjectClass(obj, class)
	if not self._Objects[obj] then
		self._Objects[obj] = {};
	end
	self._Objects[obj].class = class;
end

--[[ @brief Gets or creates self._Classes[class][event].
     @param self The GuiInput object. This is basically a member function, I dunno why it looks like this.
     @param class The class which we are looking up.
     @param event The event which we are looking up.
--]]
local function GetEventTable(self, class, event)
	local classTable = self._Classes[class];
	if not classTable then
		self._Classes[class] = {};
		classTable = self._Classes[class];
	end
	local eventTable = classTable[event];
	if not eventTable then
		classTable[event] = {};
		eventTable = classTable[event];
	end
	return eventTable;
end

--[[ @brief Sets a policy for a class interaction.
     @param event The name of the event we are passing.
     @param classConsuming The class which would presumably consume the event (be higher). Nil if no class in particular (if this is nil, classStarving must be nil).
     @param classStarving The class which would presumably consume the event after the higher-level object consumes it. Nil if no class in particular.
     @param occlude Whether or not the class should occlude another class. Alternately, nil if it should fall back to the default.
--]]
function GuiInput:SetOcclusion(event, classConsuming, classStarving, occlude)
	if classConsuming then
		local eventTable = GetEventTable(self, classConsuming, event);
		if classStarving then
			eventTable[classStarving] = occlude;
		else
			eventTable.DEFAULT = occlude;
		end
	else
		if classStarving then
			Log.Error("Universal occlusion target rules not yet supported");
		else
			--Set the default action for this event.
			self._Defaults[event] = occlude;
		end
	end
end

--[[ @brief Updates an occlusion mask assuming that an element in class just consumed event.
     @param class The class of object which was triggered.
     @param event The event which was fired.
     @param mask The mask as it exists. This may get updated.
     @return The new mask.
--]]
function GuiInput:_UpdateOcclusionMask(class, event, mask)
	local eventTable = GetEventTable(self, class, event);
	local defaultValue = false;
	if eventTable.DEFAULT ~= nil then
		defaultValue = eventTable.DEFAULT;
	else
		defaultValue = not not self._Defaults[event];
	end

	if not mask.DEFAULT then
		if defaultValue then
			--Default changing from false to true.

			--Clear out exceptions which were not maintained by this new event.
			for i, v in pairs(mask) do
				if i~="DEFAULT" then
					mask[i] = v or eventTable[i];
				end
			end
			--Add exceptions to the mask.
			for i, v in pairs(eventTable) do
				if i~="DEFAULT" then
					mask[i] = mask[i] or v;
				end
			end

			mask.DEFAULT = defaultValue;
		else
			--Default remaining false.

			--Add any new exceptions.
			for i, v in pairs(eventTable) do
				if i~="DEFAULT" then
					mask[i] = mask[i] or v;
				end
			end
		end
	else
		--Default remaining true.

		--Clear out exceptions which were not maintained by this new event.
		for i, v in pairs(mask) do
			if i~="DEFAULT" then
				mask[i] = v or eventTable[i];
			end
		end
	end
	return mask;
end

--[[ @brief Determines if a class is a valid target for a mouse event.
     @param class The class of the target.
     @param event The name of the event.
     @param mask The mask as it stands, or nil if none exists.
--]]
function GuiInput:_IsOccluded(class, event, mask)
	if mask[class]~=nil then
		return mask[class];
	else
		return mask.DEFAULT;
	end
end

--[[ @brief Returns a starting event mask.
--]]
function GuiInput:_GetBaseMask()
	--A mask is of the form
	--  {DEFAULT = true; classA = true, classB = false}
	--meaning that all classes are permitted with the exception of classB.
	return {DEFAULT = false};
end

function GuiInput:Listen(obj, event, callback)
	if not self._Objects[obj] then
		self._Objects[obj] = {};
		self._Objects[obj].class = "Default";
	end
	if not self._Objects[obj].connected then
		self._Objects[obj].connected = true;
		table.insert(self._Connections,
			obj.InputBegan:connect(function(event) self:_InputBegan(event, obj); end)
		);
		table.insert(self._Connections,
			obj.InputChanged:connect(function(event) self:_InputChanged(event, obj); end)
		);
		table.insert(self._Connections,
			obj.InputEnded:connect(function(event) self:_InputEnded(event, obj); end)
		);
	end
	if self._Objects[obj][event] == nil then
		self._Objects[obj][event] = {};
	end
	table.insert(self._Objects[obj][event], callback);
end

function GuiInput:_InputChangedGlobal(event)
	Debug("_InputChangedGlobal(%s) called", event);
	if event.UserInputType == Enum.UserInputType.MouseMovement then
		self._Hover:GlobalMove(event.Position.x, event.Position.y);
	end
end

function GuiInput:_InputEndedGlobal(event)
	Debug("_InputEndedGlobal(%s) called", event);
end

function GuiInput:_InputBegan(event, object)
	Debug("_InputBegan(%s (%s), %s) called", event, event.Position, object);
	if event.UserInputType == Enum.UserInputType.MouseMovement then
		self._Hover:GuiMove(object, event.Position.x, event.Position.y);
	end
end

function GuiInput:_InputChanged(event, object)
	Debug("_InputChanged(%s, %s) called", event, object);
	if event.UserInputType == Enum.UserInputType.MouseMovement then
		self._Hover:GuiMove(object, event.Position.x, event.Position.y);
	end
end

function GuiInput:_InputEnded(event, object)
	Debug("_InputEnded(%s, %s) called", event, object);
end

--[[ @brief Cleans up this class and prevents it from being used again.
--]]
function GuiInput:Destroy()
	self._Classes = nil;
	self._Defaults = nil;
	self._Objects = nil;
	self._Hover:Destroy();
	for i, cxn in pairs(self._Connections) do
		if cxn and cxn.connected then
			cxn:disconnect();
		end
	end
end

--[[ @brief Triggers an event at a given site.
     @param screenGui The ScreenGui which received the event.
     @param event The name of the event which we are firing.
     @param x The x location of the event.
     @param y The y location of the event.
--]]
function GuiInput:_TriggerEvent(screenGui, event, x, y, ...)
	local guis = self:_GetGuisAtPosition(screenGui, x, y);
end

function GuiInput:GetActiveGuisAtPosition(screenGui, x, y, event)
	return self:_GetActiveGuis(self:_GetGuisAtPosition(screenGui, x, y), event);
end

--[[ @brief Returns a list of gui elements which exist at position <x, y> and
     @param root The base element in the gui hierarchy.
     @param x The x location to search.
     @param y The y location to search.
     @return A list of gui objects at position <x, y> sorted by their z level.
--]]
function GuiInput:_GetGuisAtPosition(root, x, y)
	local objects = {};
	local function recurse(root)
		if root:IsA("GuiBase2d") and (not root:IsA("GuiObject") or root.Visible) then
			local pos, size = root.AbsolutePosition, root.AbsoluteSize;
			if pos.x <= x and pos.x + size.x >= x and pos.y <= y and pos.y + size.y >= y then
				table.insert(objects, root);
			end
			for i, v in pairs(root:GetChildren()) do
				recurse(v);
			end
		end
	end
	recurse(root);
	return objects;
end

--[[ @brief Returns a list of the guis which are activated for a given event.
     @details A gui is activated if it has no gui on top of it which occludes it.
     @param guis The list of guis to consider.
     @param event The event which we presumably will fire.
     @return A list of guis which should have this event fired.
--]]
function GuiInput:_GetActiveGuis(guis, event)
	local mask = self:_GetBaseMask();
	local s = {};
	for i, v in pairs(guis) do
		local data = self._Objects[v];
		if not data then
			Debug("Object %s has no events", v);
		elseif not data[event] then
			Debug("Object %s not listening to event %s", v, event);
		elseif self:_IsOccluded(data.class, event, mask) then
			Debug("Object %s is occluded", v);
		end
		if data and data[event] and not self:_IsOccluded(data.class, event, mask) then
			mask = self:_UpdateOcclusionMask(data.class, event, mask);
			table.insert(s, v);
		end
	end
	return s;
end

local Singleton;
function GuiInput.get()
	if not Singleton then
		Singleton = GuiInput.new();
	end
	return Singleton;
end

function GuiInput.new()
	local self = setmetatable({}, GuiInput.Meta);
	self._Classes = {};
	self._Defaults = {};
	for i, v in pairs(EVENT_OCCLUDE_DEFAULT) do
		self._Defaults[i] = v;
	end
	self._Objects = {};
	self._Connections = {};
	table.insert(self._Connections,
		game:GetService("UserInputService").InputChanged:connect(function(event, gameProcessedEvent) self:_InputChangedGlobal(event); end)
	);
	table.insert(self._Connections,
		game:GetService("UserInputService").InputEnded:connect(function(event, gameProcessedEvent) self:_InputEndedGlobal(event); end)
	);
	self._Hover = Hover.new();
	self._Hover.InputManager = self;
	self._Hover.Callback = function(gui, event, x, y)
		event = event~="MouseLeave";
		for _, f in pairs(self._Objects[gui].Hover) do
			f(event, x, y);
		end
	end;
	return self;
end

function GuiInput.Test()
	local input = GuiInput.new();
	input:SetOcclusion("Click1", "A", "B", false);
	input:SetOcclusion("Click1", "B", nil, false);
	input:SetOcclusion("MouseEnter", "B", "B", true);
	local mask = GuiInput:_GetBaseMask();
	Debug("Mask1: %t", mask);
	mask = input:_UpdateOcclusionMask("B", "Click1", mask);
	Debug("Mask2: %t", mask);
	mask = input:_UpdateOcclusionMask("A", "Click1", mask);
	Debug("Mask3: %t", mask);
	mask = input:_UpdateOcclusionMask("B", "Click1", mask);
	Debug("Mask4: %t", mask);

	local mask = GuiInput:_GetBaseMask();
	Debug("Mask1: %t", mask);
	Debug("Valid: %s", not input:_IsOccluded("B", "MouseEnter", mask));
	mask = input:_UpdateOcclusionMask("A", "MouseEnter", mask);
	Debug("Mask2: %t", mask);
	Debug("Valid: %s", not input:_IsOccluded("B", "MouseEnter", mask));
	mask = input:_UpdateOcclusionMask("B", "MouseEnter", mask);
	Debug("Mask3: %t", mask);
	Debug("Valid: %s", not input:_IsOccluded("B", "MouseEnter", mask));
	Debug("Valid: %s", not input:_IsOccluded("A", "MouseEnter", mask));
end

return GuiInput;
