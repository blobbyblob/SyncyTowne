--[[

This class is responsible for differentiating between a click & a drag for a single mouse button.

Properties:
	InputManager: the one true InputManager object which this class relies on.
	Callback: a function which is called everytime an event occurs. The signature is
		function(gui, event, x, y) where gui is a GuiObject, event is the string
		"Mouse1Click", "Mouse2Click", "DragBegin", "Drag", or "DragStopped".
Methods:
	MouseDown(gui, button, x, y): indicates to the manager that a MouseDown event occurred on a gui.
	MouseUp(gui, button, x, y): indicates to the manager that a MouseUp event occurred on a gui.
	GlobalMouseDown(button, x, y): indicates to the manager that the mouse clicked in the workspace or on a gui.
	GlobalMouseUp(button, x, y): indicates to the manager that the mouse released in the workspace or on a gui.
	GlobalMouseMoved(x, y): indicates to the manager that the mouse moved.

--]]

local lib = script.Parent.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);

local Debug = Log.new("ClickDrag:\t", true);
local ClickDrag = Class.new("ClickDrag");

ClickDrag._InputManager = false; --! The InputManager associated with this module.
ClickDrag._Callback = false; --! A function to call when an event occurs.
ClickDrag._Dragging = false; --! A flag which is set when the user is dragging.
ClickDrag._DragGuis = false; --! A list of guis which were viable for dragging on the last mouse click.
ClickDrag._Click1Guis = false; --! A list of guis for which Mouse1Down was called without a corresponding Mouse1Up.

ClickDrag.Set.InputManager = "_InputManager";
ClickDrag.Get.InputManager = "_InputManager";
ClickDrag.Set.Callback = "_Callback";
ClickDrag.Get.Callback = "_Callback";

--[[ @brief Gets the LayerCollector which this object belongs to.
     @param obj The gui whose LayerCollector we're searching for.
     @return The first LayerCollector ancestor (e.g., ScreenGui) we find.
--]]
local function GetScreenGui(obj)
	if obj==nil then
		return nil;
	elseif obj:IsA("LayerCollector") then
		return obj;
	else
		return GetScreenGui(obj.Parent);
	end
end

function ClickDrag:_StartDrag()
	self._Dragging = true;
end

function ClickDrag:_SendMouse1Down(guis, ...)
	for i, gui in pairs(self._Click1Guis or {}) do
		self._Callback(gui, "Mouse1Up", ...);
	end
	self._Click1Guis = guis;
	for _, gui in pairs(guis) do
		self._Callback(gui, "Mouse1Down", ...);
	end
end

function ClickDrag:MouseDown(gui, button, x, y)
	--Find a gui at <x, y> which is receptive to "Click1" or "Drag", or "Click2".
	if button == 1 then
		local clickGuis = self._InputManager:GetActiveGuisAtPosition(GetScreenGui(gui), x, y, "Click1");
		local dragGuis = self._InputManager:GetActiveGuisAtPosition(GetScreenGui(gui), x, y, "Drag");
		self._DragGuis = dragGuis;
		--If we can only drag, not click, then start dragging.
		if #clickGuis == 0 and #dragGuis > 0 then
			self:_StartDrag();
		else
			--Assume we're starting a click.
			self:_SendMouse1Up();
			self:_SendMouse1Down(clickGuis, x, y);
		end
		--Otherwise, send MouseDown event.
	end
end

--[[ @brief Instantiates a new ClickDrag manager.
     @return The new ClickDrag manager.
--]]
function ClickDrag.new()
	local self = setmetatable({}, ClickDrag.Meta);
	return self;
end

return ClickDrag;