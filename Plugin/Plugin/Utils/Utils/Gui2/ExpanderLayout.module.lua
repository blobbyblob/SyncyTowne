--[[

A way to clamp the view to only one focal point. The children form a canvas. Any rect2d in this canvas can be focused on.

Properties:
	ContractedPosition: the location to focus in on when contracted.
	ContractedSize: the size of the canvas to show when contracted.
	ExpandedSize: the size of the entire canvas.
	State [Gui.Enum.ExpanderLayoutState]: whether the layout is expanded or contracted.
	ContractedGravity [Gui.Enum.ViewGravity]: When provided with more space than necessary, this will dictate where the extra space goes.
--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local View = require(script.Parent.View);
local Test = Gui.Test;

local Super = View;
local ExpanderLayout = Utils.new("Class", "ExpanderLayout", Super);

Gui.Enum:newEnumClass("ExpanderLayoutState", "Expanded", "Contracted");

----------------
-- Properties --
----------------
ExpanderLayout._ContractedPosition = Vector2.new();
ExpanderLayout._ContractedSize = Vector2.new(50, 50);
ExpanderLayout._ExpandedSize = Vector2.new(0, 0);
ExpanderLayout._Expanded = false;
ExpanderLayout._FocusGravity = Gui.Enum.ViewGravity.Center;

ExpanderLayout._Frame = false;

---------------------
-- Getters/Setters --
---------------------
function ExpanderLayout.Set:ContractedPosition(v)
	if self._ContractedPosition == v then return; end
	self._ContractedPosition = v;
	if not self._Expanded then
		self._SignalReflowPre:Trigger();
	end
	self._Changed:Fire("ContractedPosition");
end
ExpanderLayout.Get.ContractedPosition = "_ContractedPosition";

function ExpanderLayout.Set:ContractedSize(v)
	if self._ContractedSize == v then return; end
	self._ContractedSize = v;
	if not self._Expanded then
		self._SignalReflowPre:Trigger();
	end
	self._Changed:Fire("ContractedSize");
end
ExpanderLayout.Get.ContractedSize = "_ContractedSize";

function ExpanderLayout.Set:ExpandedSize(v)
	if self._ExpandedSize == v then return; end
	self._ExpandedSize = v;
	if self._Expanded then
		self._SignalReflowPre:Trigger();
	end
	self._Changed:Fire("ExpandedSize");
end
ExpanderLayout.Get.ExpandedSize = "_ExpandedSize";

function ExpanderLayout.Set:State(v)
	v = (v == Gui.Enum.ExpanderLayoutState.Expanded);
	if self._Expanded == v then return; end
	self._Expanded = v;
	self._SignalReflowPre:Trigger();
	self._Changed:Fire("State");
end
function ExpanderLayout.Get:State()
	return self._Expanded and Gui.Enum.ExpanderLayoutState.Expanded or Gui.Enum.ExpanderLayoutState.Contracted;
end

function ExpanderLayout.Set:ContractedGravity(v)
	if v ~= self._FocusGravity then
		self._FocusGravity = v;
		self._Changed:Fire("ContractedGravity");
		if not self._Expanded then
			self._SignalReflowPre:Trigger();
		end
	end
end
ExpanderLayout.Get.ContractedGravity = "_FocusGravity";

--------------------------------------------
-- Overridden methods for Wrapper Classes --
--------------------------------------------
function ExpanderLayout:_GetHandle()
	return self._Frame;
end

function ExpanderLayout:_GetChildContainerRaw(child)
	return self._Frame;
end

function ExpanderLayout:_Reflow(pos, size)
	Gui.Log.Reflow("ExpanderLayout._Reflow(%s, %s, %s) called", self, pos, size);
	--The amount of space afforded to children is given by self._ExpandedSize.
	local x, y = self._ExpandedSize.x, self._ExpandedSize.y;
	--If the provided size is greater than the required size, take it.
	self._Frame.Size = size;
	if self._Frame.AbsoluteSize.x > x then x = self._Frame.AbsoluteSize.x; end
	if self._Frame.AbsoluteSize.y > y then y = self._Frame.AbsoluteSize.y; end
	--Make sure the provided size is at least as large as what the children need.
	for i, v in pairs(self:GetChildren()) do
		local sz = v:_GetMinimumSize();
		if sz.x > x then x = sz.x; end
		if sz.y > y then y = sz.y; end
	end
	local childSize = UDim2.new(0, x, 0, y);

	if not self._Expanded then
		--If we are deactivated, clip the contents of the contents element.
		self._Frame.Size = size;
		local absSize = self._Frame.AbsoluteSize;
		local x, y = 0, 0;
		if self._FocusGravity == Gui.Enum.ViewGravity.CenterLeft or self._FocusGravity == Gui.Enum.ViewGravity.Center or self._FocusGravity == Gui.Enum.ViewGravity.CenterRight then
			y = 0.5;
		elseif self._FocusGravity == Gui.Enum.ViewGravity.BottomLeft or self._FocusGravity == Gui.Enum.ViewGravity.BottomCenter or self._FocusGravity == Gui.Enum.ViewGravity.BottomRight then
			y = 1;
		end
		if self._FocusGravity == Gui.Enum.ViewGravity.TopCenter or self._FocusGravity == Gui.Enum.ViewGravity.Center or self._FocusGravity == Gui.Enum.ViewGravity.BottomCenter then
			x = 0.5;
		elseif self._FocusGravity == Gui.Enum.ViewGravity.TopRight or self._FocusGravity == Gui.Enum.ViewGravity.CenterRight or self._FocusGravity == Gui.Enum.ViewGravity.BottomRight then
			x = 1;
		end
		local extraSpace = absSize - self._ContractedSize;

		self._Frame.Position = pos + UDim2.new(0, extraSpace.x * x, 0, extraSpace.y * y);
		self._Frame.Size = UDim2.new(0, self._ContractedSize.x, 0, self._ContractedSize.y);
		for i, v in pairs(self:GetChildren()) do
			v:_SetPPos(-UDim2.new(0, self._ContractedPosition.x, 0, self._ContractedPosition.y));
			v:_SetPSize(childSize);
		end
	elseif self._Expanded then
		self._Frame.Position = pos;
		self._Frame.Size = UDim2.new(0, childSize.X.Offset, 0, childSize.Y.Offset);
		for i, v in pairs(self:GetChildren()) do
			v:_SetPPos(UDim2.new());
			v:_SetPSize(childSize);
		end
	end
end

-----------------
-- Constructor --
-----------------

function ExpanderLayout.new()
	local self = setmetatable(Super.new(), ExpanderLayout.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.ClipsDescendants = true;
	self._Frame.BackgroundTransparency = 1;
	return self;
end

--------------------
-- Test Functions --
--------------------
function Test.ExpanderLayout_Basic()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "ExpanderLayout_Basic";
	local expander = Gui.new("ExpanderLayout", sgui);
	expander.Gravity = Gui.Enum.ViewGravity.Center;
	expander.FillX = false;
	expander.FillY = false;
	expander.MinimumX = 400;
	expander.MinimumY = 50;
	local image = Gui.new("ImageLabel", expander);
	image.Image = "rbxassetid://407509186";
	wait(.1);
	expander.State = Gui.Enum.ExpanderLayoutState.Expanded;
	wait(.1);
	expander.ContractedPosition = Vector2.new(100, 0);
	expander.State = Gui.Enum.ExpanderLayoutState.Contracted;
end


return ExpanderLayout;

