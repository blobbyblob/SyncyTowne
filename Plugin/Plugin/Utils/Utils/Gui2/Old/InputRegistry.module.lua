--[[
	The following library helps to produce gestures which work on windows, mac, xbox, and touch.
	Two gui elements won't try to consume the same event unless one rejects it (returns false).
--]]

local lib = script.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);
local Utils = require(lib.Utils);
local Gui = _G[script.Parent];
local Test = Gui.Test;

local TreeManager = require(script.TreeManager);

local Debug = Log.new("Input:\t", true);

Gui.Enum.InputEvent = {
	Click = "Click"; --Fires on single tap.
	AltClick = "AltClick"; --Fires on right click, ctrl + click (mac), or long press.
	DoubleClick = "DoubleClick"; --Fires on double click or double tap.
	HoverStart = "HoverStart"; --Fires when the mouse hovers over or they draw a small circle using their finger.
	HoverEnded = "HoverEnded"; --Fires when the mouse is no longer hovering or the user moved their attention to another part of the screen.
	FocusStart = "FocusStart"; --Fires the moment the mouse moves onto an element or an event fires for that element.
	FocusEnded = "FocusEnded"; --Fires when the mouse leaves the gui or an event fires for another element.

	ScrollUp = "ScrollUp"; --Fires when a user swipes down or mouse wheels up.
	ScrollDown = "ScrollDown"; --Fires when a user swipes up or mouse wheels down.
	ScrollRight = "ScrollRight"; --Fires when a user swipes left or mouse wheels down while holding control.
	ScrollLeft = "ScrollLeft"; --Fires when a user swipes right or mouse wheels up while holding control.
};
local CLICK = Gui.Enum.InputEvent.Click;

local InputRegistry = Class.new("InputRegistry");

InputRegistry._Events = false; --A map of object to a map of InputEvent Enums to an array of callback functions.
InputRegistry._Listeners = false; --A map of object to array of connections indicating whether we are listening through this object or not.
InputRegistry._TreeManager = false; --An object which is the topmost in the hierarchy.

--[[ @brief TopDirectory is the uppermost directory inside of which all interactive gui elements reside.
     @param v The new top directory.
--]]
function InputRegistry.Set:TopDirectory(v)
	self._TreeManager.Root = v;
end

--[[ @brief Listens for an event to happen to a given object.
     @param obj The object to listen on. This should have an AbsolutePosition and AbsoluteSize. If obj is nil, it will fire only when not consumed otherwise.
     @param event The event to listen for. Possible values are in Gui.Enum.InputEvent.
     @param f The function to fire if event is triggered. This should return true if it consumes the event.
--]]
function InputRegistry:Connect(obj, event, f)
	Debug("InputRegistry.Connect(%s, %s, %s, %s) called", self, obj, event, f);

end
--[[ @brief Creates an event object which has methods "connect" and "wait".
     @param obj The object we are creating the event for.
     @param event The event which we will listen on.
     @return The event object.
--]]
function InputRegistry:GetEvent(obj, event)
	local evt = Utils.newEvent();
	self:Connect(obj, event, function(...)
		evt:Fire(...);
	end)
end

--[[ @brief Connects to obj enabling it to fire other events.
     @param obj A ROBLOX Instance.
--]]
function InputRegistry:_Listen(obj)
	if self._Listeners[obj] then return; end
	self._Listeners[obj] = true;
	Debug("Listening through: %s", obj);
	self._Listeners[obj] = {};
	--Connect to all events possible.
	if obj:IsA("GuiButton") then
		obj.MouseButton1Click:connect(function(x, y)
			Debug("%s.MouseButton1Click(%s, %s) called", obj, x, y);
			self:Fire(CLICK, x, y);
		end)
	end

end
function InputRegistry:_Unlisten(obj)
	if not self._Listeners[obj] then return; end
	for i, v in pairs(self._Listeners[obj]) do
		if v.connected then
			v:disconnect();
		end
	end
	self._Listeners[obj] = nil;
end

--[[ @brief Fires an event at position <x, y>
     @param event The event to fire. Should be a member of Gui.Enum.InputEvent.
     @param x The x location of the event.
     @param y The y location of the event.
--]]
function InputRegistry:Fire(event, x, y)
	local function checkObj(obj)
		--Check to see if we've ever hooked into obj.
		local events = self._Events[obj];
		if not events then return false; end

		--Check to see if we've hooked into this specific event for obj.
		local callbacks = events[event];
		if not callbacks then return false; end

		--Check to see if we're positioned over obj.
		local relative = Vector2.new(x, y) - obj.AbsolutePosition;
		if not (relative.x >= 0 and relative.y >= 0 and relative.x <= obj.AbsoluteSize.x and relative.y <= obj.AbsoluteSize.y) then return false; end

		--If we've passed all checks, fire the event.
		for i, v in pairs(callbacks) do
			v(x, y);
		end
		
		return true;
	end

	local function continueRecursing(obj)
		--If the object is not a gui object, it is fine.
		if not obj:IsA("GuiObject") then return true; end

		--If the object is invisible, stop searching.
		if obj.Visible == false then return false; end

		--Otherwise, return true.
		return true;
	end

	--Run through the queue for this event and find a match. If the event is consumed and the obj is currently not the focus, give it focus & take focus from the last element.
	self._TreeManager:ReverseTraverse(checkObj, continueRecursing)
end

--[[ @brief Cleans up the InputRegistry so that it no longer listens/fires events.
--]]
function InputRegistry:Destroy()
	self.TopDirectory = nil;
end
function InputRegistry.new()
	local self = setmetatable({}, InputRegistry.Meta);
	self._Events = {};
	self._Listeners = setmetatable({}, {__mode='k'});
	self._TreeManager = TreeManager.new();
	self._TreeManager.ClassFilter = "GuiObject";
	self._TreeManager.DescendantAdded:connect(function(obj) self:_Listen(obj); end);
	self._TreeManager.DescendantRemoving:connect(function(obj) self:_Unlisten(obj); end);
	return self;
end

function Gui.Test.InputRegistry_Basic(sgui, cgui)
	local input;
	sgui.AncestryChanged:connect(function(child, parent)
		if not sgui:IsDescendantOf(game) then
			if input then
				input:Destroy();
			end
		end
	end)
	Debug("Module re-required");

	local frame1 = Instance.new("ImageButton");
	frame1.Name = "Frame1";
	frame1.Size = UDim2.new(.5, 0, .5, 0);
	frame1.Position = UDim2.new(.25, -20, 0.25, -20);
	frame1.Active = true;
	frame1.Parent = cgui;
	local frame2 = Instance.new("ImageButton");
	frame2.Name = "Frame2";
	frame2.Size = UDim2.new(1, 0, 1, 0);
	frame2.Position = UDim2.new(0, 40, 0, 40);
	frame2.Active = true;
	frame2.Parent = frame1;

	input = InputRegistry.new();
	input.TopDirectory = frame1.Parent.Parent;
	input:Connect(frame1, Gui.Enum.InputEvent.Click, function(...)
		Debug("%s clicked", frame1);
	end)
	input:Connect(frame2, Gui.Enum.InputEvent.Click, function(...)
		Debug("%s clicked", frame2);
	end)
end

return InputRegistry;

