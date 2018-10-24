--[[

This module manages the hover event. A hover occurs if the mouse moves over it.
It terminates if the mouse moves away or something of higher priority is between
the mouse and the target.

Properties:
	InputManager: the one true InputManager object which this class relies on.
	Callback: a function which is called everytime an event occurs. The signature
		is function(gui, event, x, y) where gui is a GuiObject, event is
		"MouseEnter", "MouseMoved", or "MouseLeave", and <x, y> is the mouse
		position.
Methods:
	GuiMove(gui, x, y): indicates that a move occurred for a gui.
	GlobalMove(x, y): indicates that the mouse has moved -- not necessarily over a gui.
	Destroy(): Cleans up this class so hover events aren't in limbo.
Constructors:
	new(): returns a new Hover manager.

--]]

local lib = script.Parent.Parent.Parent;
local Log = require(lib.Log);
local Class = require(lib.Class);

local Debug = Log.new("Hover:\t", true);
local Hover = Class.new("Hover");

Hover._InputManager = false; --! The InputManager associated with this module.
Hover._HoveringGuis = false; --! A map of gui --> true if the gui is being hovered over.
Hover._LastScreenGui = false; --! A reference to the last ScreenGui which was hovered on.
Hover._Callback = function(gui, state, x, y) end; --! A callback function which fires when an object is hovered over or no longer hovered over.
Hover._LastGuiPosition = false; --! A Vector2 value of the position of the mouse the last time the GuiMove function was called. Possibly nil.
Hover._LastGlobalPosition = false; --! A Vector2 value of the position of the mouse the last time the GlobalMove function was called. Possibly nil.

Hover.Set.InputManager = "_InputManager";
Hover.Get.InputManager = "_InputManager";
Hover.Set.Callback = "_Callback";
Hover.Get.Callback = "_Callback";

--[[ @brief Returns a list of gui elements which exist at position <x, y> and
     @param root The base element in the gui hierarchy.
     @param x The x location to search.
     @param y The y location to search.
     @return A list of gui objects at position <x, y> sorted by their z level.
--]]
function Hover:_GetGuisAtPosition(root, x, y)
	local objects = {};
	local function recurse(root)
		if root:IsA("GuiBase2d") and (not root:IsA("GuiObject") or root.Visible) then
			local children = root:GetChildren();
			for i = #children, 1, -1 do
				recurse(children[i]);
			end
			local pos, size = root.AbsolutePosition, root.AbsoluteSize;
			if pos.x <= x and pos.x + size.x >= x and pos.y <= y and pos.y + size.y >= y then
				table.insert(objects, root);
			end
		end
	end
	recurse(root);
	return objects;
end

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

--[[ @brief Indicates that a move event occurred for a gui.
     @param gui The gui for which the event occurred.
     @param x The mouse's x location.
     @param y The mouse's y location.
--]]
function Hover:GuiMove(gui, x, y)
	self._LastGuiPosition = Vector2.new(x, y);
	local screenGui = GetScreenGui(gui);
	if not screenGui then return; end

	--If the ScreenGui is different, then everything in this current ScreenGui should no longer have "hovered" fired for them.
	if self._LastScreenGui ~= screenGui then
		for gui in pairs(self._HoveringGuis) do
			--End hover event.
			self._Callback(gui, "MouseLeave", x, y);
		end
		self._HoveringGuis = {};
		self._LastScreenGui = screenGui;
	end

	--Get all guis which are under the mouse and worth firing "Hover" for.
	local guis = self:_GetGuisAtPosition(screenGui, x, y);
	guis = self._InputManager:_GetActiveGuis(guis, "Hover");
	--Call MouseEnter or MouseMoved for all guis in "guis".
	local activeGuis = {};
	for i, gui in pairs(guis) do
		activeGuis[gui] = true;
		if not self._HoveringGuis[gui] then
			self._HoveringGuis[gui] = true;
			self._Callback(gui, "MouseEnter", x, y);
		else
			self._Callback(gui, "MouseMoved", x, y);
		end
	end
	--Call MouseLeave for all guis in self._HoveringGuis but not in "guis".
	local deleteThese = {};
	for gui in pairs(self._HoveringGuis) do
		if not activeGuis[gui] then
			table.insert(deleteThese, gui);
		end
	end
	for i, gui in pairs(deleteThese) do
		self._HoveringGuis[gui] = nil;
		self._Callback(gui, "MouseLeave", x, y);
	end
end

--[[ @brief Indicates that the mouse has moved -- not necessarily over a gui.
     @param x The mouse's x location.
     @param y The mouse's y location.
--]]
function Hover:GlobalMove(x, y)
	if self._LastScreenGui then
		local current = Vector2.new(x, y);
		local gui = self._LastGuiPosition or Vector2.new(-1000, 0);
		local global = self._LastGlobalPosition or Vector2.new(0, -1000);
		if gui ~= global and gui ~= current and current ~= global then
			for gui in pairs(self._HoveringGuis) do
				--End hover event.
				self._Callback(gui, "MouseLeave", x, y);
			end
			self._HoveringGuis = {};
			self._LastScreenGui = nil;
		end
	end
end

--[[ @brief Cleans up this class so hover events aren't in limbo.
--]]
function Hover:Destroy()
	for gui in pairs(self._HoveringGuis) do
		self._Callback(gui, false, self._LastGlobalPosition.x, self._LastGlobalPosition.y);
	end
end

--[[ @brief Instantiates a new hover manager.
     @return The new hover manager.
--]]
function Hover.new()
	local self = setmetatable({}, Hover.Meta);
	self._HoveringGuis = {};
	return self;
end

return Hover;
