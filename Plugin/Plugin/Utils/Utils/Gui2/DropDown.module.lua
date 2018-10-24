--[[

A DropDown is an input device which allows the user to select from a list of choices.

Properties:
	Values: a list of strings which the user can select.
	Value: the currently selected string.
	SelectedIndex: the currently selected index.
	IsFocused: a boolean which, if true, indicates that the drop down menu is expanded.

LayoutParams:
	Role [Gui.Enum.DropDownRole]: the location at which this element should go. Values are Main and DropElement.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local View = require(script.Parent.View);
local Test = Gui.Test;

Gui.Enum:newEnumClass("DropDownRole", "Main", "DropElement", "GridLayout", "Unknown");

local Debug = Log.new("DropDown: ", true);
local MouseEventDebug = Log.new("DropDown: ", false);
local Super = View;
local DropDown = Utils.new("Class", "DropDown", Super);

local LAYOUT_PARAM_DEFAULTS = {
	Role = Gui.Enum.DropDownRole.Unknown;
	FormatFunction = function(element, index, value)
		element.Text = value;
	end;
};

----------------
-- Properties --
----------------
DropDown._Values = {"Option 1", "Option 2", "Option 3"};
DropDown._Value = "Option 1";
DropDown._SelectedIndex = 1;
DropDown._HasFocus = false;

DropDown._Frame = false;
DropDown._Button = false;
DropDown._ImageLabel = false;
DropDown._ExpanderLayout = false;
DropDown._TextButtons = {};

DropDown._ChildLayoutParams = false;
DropDown._LastMain = false;
DropDown._LastDropElement = Gui.new("TextButton");
DropDown._LastGridLayout = false;

---------------------
-- Getters/Setters --
---------------------
function DropDown.Set:Values(v)
	self._Values = v;
	self._Changed:Fire("Values");
	self:_PopulateGridLayout(false);
	self._SignalReflowPre:Trigger();
	if self._SelectedIndex <= #v and self._SelectedIndex >= 1 then
		self.Value = v[self._SelectedIndex];
	end
end
DropDown.Get.Values = "_Values";

function DropDown.Set:Value(v)
	if self._Value ~= v then
		self._Value = v;
		self._Changed:Fire("Value");
	end
	if not self._Values[self._SelectedIndex] == v then
		for i, u in pairs(self._Values) do
			if u==v then
				self.SelectedIndex = i;
				break;
			end
		end
		if self._Values[self._SelectedIndex]~=v then
			self.SelectedIndex = 1;
		end
	end
end
DropDown.Get.Value = "_Value";

function DropDown.Set:SelectedIndex(v)
	self._SelectedIndex = v;
	if self._Value ~= self._Values[v] then
		self.Value = self._Values[v];
	end
	self._ExpanderLayout.ContractedPosition = self._TextButtons[v].AbsolutePosition - self._LastGridLayout.AbsolutePosition;
	self._ExpanderLayout.ContractedSize = self._TextButtons[v].AbsoluteSize;
	self._SignalReflowPre:Trigger();
end
DropDown.Get.SelectedIndex = "_SelectedIndex";

function DropDown.Set:IsFocused(v)
	if v ~= self._HasFocus then
		self._HasFocus = v;
		if v then
			self._ExpanderLayout.State = Gui.Enum.ExpanderLayoutState.Expanded;
			self._Button.Visible = false;
		else
			self._ExpanderLayout.State = Gui.Enum.ExpanderLayoutState.Contracted;
			self._Button.Visible = true;
		end
	end
end
DropDown.Get.IsFocused = "_HasFocus";

function DropDown.Set:Name(v)
	Super.Set.Name(self, v);
	self._Frame.Name = v;
	self._Button.Name = v .. "_Button";
	self._ImageLabel.Name = v .. "_DropDownArrow";
	self._ExpanderLayout.Name = v .. "_ExpanderLayout";
	self._LastGridLayout.Name = v .. "_GridLayout";
	for i, x in pairs(self._TextButtons) do
		x.Name = v .. "_Button" .. tostring(i);
	end
end

--------------------------------------------
-- Overridden methods for Wrapper Classes --
--------------------------------------------
function DropDown.Set:Parent(parent)
	Super.Set.Parent(self, parent);
	self._Frame.ParentNoNotify = parent;
end
function DropDown.Set:ParentNoNotify(parent)
	Super.Set.ParentNoNotify(self, parent);
	self._Frame.ParentNoNotify = parent;
end

function DropDown:_GetHandle()
	return self._Frame:_GetHandle();
end

function DropDown:_GetChildContainer(obj)
	local LayoutParams = self._ChildLayoutParams[obj];
	if LayoutParams.Role == Gui.Enum.DropDownRole.Main then
		return self._Button:_GetHandle();
	elseif LayoutParams.Role == Gui.Enum.DropDownRole.GridLayout then
		return self._ExpanderLayout:_GetHandle();
	end
	return nil;
end

function DropDown:_Reflow(pos, size)
	Gui.Log.Reflow("DropDown._Reflow(%s, %s, %s) called", self, pos, size);
	self:_CheckChildren();
	Super._Reflow(self, pos, size);
	self._Frame:_SetPPos(pos);
	self._Frame:_SetPSize(size);
	self._Frame:ForceReflow();
	self._ExpanderLayout.ContractedSize = Vector2.new(self.AbsoluteSize.x, 0);
	self._ExpanderLayout:_SetPPos(UDim2.new(0, 0, 1, 0));
	self._ExpanderLayout:_SetPSize(UDim2.new(size.X.Scale, size.X.Offset, 0, 1000));
end

-----------------
-- New Methods --
-----------------
--[[ @brief Determines if new "Main" or "DropElement" items have been added and if so, routes that info where it needs to go.
--]]
function DropDown:_CheckChildren()
	Debug("DropDown._CheckChildren(%s) called", self);
	local main, dropElement, gridLayout;
	for i, v in pairs(self:GetChildren()) do
		local LayoutParams = self._ChildLayoutParams[v];
		if not main and LayoutParams.Role == Gui.Enum.DropDownRole.Main then
			main = v;
		elseif not dropElement and LayoutParams.Role == Gui.Enum.DropDownRole.DropElement then
			dropElement = v;
		elseif not gridLayout and LayoutParams.Role == Gui.Enum.DropDownRole.GridLayout then
			gridLayout = v;
		elseif main and dropElement then
			break;
		end
	end
	if main and self._LastMain ~= main then
		self._ChildLayoutParams[main].FormatFunction(main, self.SelectedIndex, self.Value);
		self._LastMain = main;
	end
	if dropElement == nil and self._LastDropElement ~= DropDown._LastDropElement or
	   dropElement ~= nil and self._LastDropElement ~= dropElement then
		Debug("New DropElement: %s", dropElement);
		self._LastDropElement = dropElement;
		self:_PopulateGridLayout(true);
	end
	if gridLayout and self._LastGridLayout ~= gridLayout then
		Debug("New GridLayout: %s", gridLayout);
		if self._LastGridLayout == self._DefaultGridLayout then
			self._LastGridLayout.Parent = nil;
		end
		self._LastGridLayout = gridLayout;
		self:_PopulateGridLayout(true);
	elseif not gridLayout and self._LastGridLayout ~= self._DefaultGridLayout then
		self._DefaultGridLayout.Parent = self._ExpanderLayout;
		self._LastGridLayout = self._DefaultGridLayout;
		self:_PopulateGridLayout(true);
	end
end

function DropDown:_PopulateGridLayout(forceRedraw)
	Debug("DropDown._PopulateGridLayout(%s, %s) called", self, forceRedraw);
	--Delete excess TextButtons if we have too many.
	for i = forceRedraw and 1 or #self._Values+1, #self._TextButtons do
		self._TextButtons[i]:Destroy();
		self._TextButtons[i] = nil;
	end
	--Add TextButtons if we have too few.
	for i = #self._TextButtons+1, #self._Values do
		self._TextButtons[i] = self._LastDropElement:Clone();
		self._TextButtons[i].Name = self._Name .. "_Button" .. tostring(i);
		Debug("Setting %s.Parent = %s", self._TextButtons[i], self._LastGridLayout);
		self._TextButtons[i].Parent = self._LastGridLayout;
		self._TextButtons[i]:_GetHandle().MouseButton1Click:connect(function()
			if self.IsFocused then
				self.SelectedIndex = i;
				self.IsFocused = false;
			end
		end);
	end
	--Update all the text to ensure it matches the values.
	for i, v in pairs(self._TextButtons) do
		self._ChildLayoutParams[self._LastDropElement].FormatFunction(v, i, self.Values[i]);
	end
end

-----------------
-- Constructor --
-----------------

function DropDown.new()
	--[[
		Frame
			ExpanderLayout
				GridLayout
					--This may have a number of children based on regular GridLayout rules.
			Button
				ImageLabel
				--Another element to show the unexpanded dropdown can be found here.
	--]]

	local self = setmetatable(Super.new(), DropDown.Meta);
	self._Frame = Gui.new("Frame");
	self._Frame.BackgroundTransparency = 0;
	self._Frame.BackgroundColor3 = Color3.new(1, 0, 0);
	self._Frame.Active = true;
	self._ExpanderLayout = Gui.new("ExpanderLayout");
	self._ExpanderLayout.ContractedGravity = Gui.Enum.ViewGravity.Center;
	self._ExpanderLayout.ParentNoNotify = self._Frame;
	self._DefaultGridLayout = Gui.new("GridLayout", self._ExpanderLayout);
	self._DefaultGridLayout.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;
	self._DefaultGridLayout.ColumnWeights = {1};
	self._DefaultGridLayout.RowWeights = {0};
	self._DefaultGridLayout.RowHeights = {25};
	self._DefaultGridLayout.Cushion = Vector2.new(4, 4);
	self._DefaultGridLayout.AlwaysUseFrame = true;
	self._DefaultGridLayout.MinimumGridDimensions = Vector2.new(1, 1);
	self._LastGridLayout = self._DefaultGridLayout;
	self._Button = Gui.new("ImageButton");
	self._Button.Parent = self._Frame;
	self._Button.BackgroundTransparency = 1;
	self._ImageLabel = Gui.new("ImageLabel", self._Button);
	self._ImageLabel.Image = "rbxassetid://17070105";
	self._ImageLabel.BackgroundTransparency = 1;
	self._ImageLabel.FillX = false;
	self._ImageLabel.FillY = false;
	self._ImageLabel.MinimumX = 20;
	self._ImageLabel.MinimumY = 20;
	self._ImageLabel.Gravity = Gui.Enum.ViewGravity.CenterRight;
	self._ImageLabel.Margin = {Left = 0; Right = 10; Top = 0; Bottom = 0};

	self._Button.MouseButton1Click:connect(function()
		MouseEventDebug("_Frame.MouseButton1Click() called");
		self.IsFocused = not self.IsFocused;
	end);
	self._ExpanderLayout:_GetHandle().MouseLeave:connect(function()
		MouseEventDebug("_ExpanderLayout.MouseLeave() called");
		if self.IsFocused then
			self.IsFocused = false;
		end
	end)
	self._ChildLayoutParams = Gui.ChildProperties(LAYOUT_PARAM_DEFAULTS);
	local params = self._ChildLayoutParams:GetWritableParameters(self._LastDropElement);
	params.Role = Gui.Enum.DropDownRole.DropElement;
	params.FormatFunction = function(element, index, value) element.Text = value; end;

	self.Values = self.Values;
	self.Name = self.Name;
	self._SignalReflowPre:Trigger();
	return self;
end

--------------------
-- Test Functions --
--------------------
function Test.DropDown_Basic(sgui, cgui)
	local view = Gui.new("View", sgui);
	view.Name = "DropDown_Basic";
	view.MinimumX = 400;
	view.MinimumY = 50;
	view.FillX = false;
	view.FillY = false;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local dd = Gui.new("DropDown", view);
	dd.Values = {"a", "b", "c", "d", "e"};
	wait(1);
	dd.Value = "b";
	wait(1);
	dd.IsFocused = true;
	wait(1);
	dd.SelectedIndex = 4;
	dd.IsFocused = false;
end

function Test.DropDown_Custom(sgui, cgui)
	local view = Gui.new("View", sgui);
	view.MinimumX = 400;
	view.MinimumY = 50;
	view.FillX = false;
	view.FillY = false;
	view.Gravity = Gui.Enum.ViewGravity.Center;
	local dd = Gui.new("DropDown", view);
	dd.Values = {"a", "b", "c", "d", "e"};
	local de = Gui.new("TextButton");
	de.LayoutParams = {
		Role = Gui.Enum.DropDownRole.DropElement;
		FormatFunction = function(element, index, value)
			element.Text = value;
			element.BackgroundColor3 = index%2 == 0 and Utils.Math.HexColor(0xbfd7ff) or Utils.Math.HexColor(0xe5efff);
		end;
	};
	de.BackgroundColor3 = Color3.fromRGB(255, 128, 0);
	de.Size = UDim2.new(1, 0, 0, 15);
	de.Name = "CustomDropDownElement";
	de.Parent = dd;
	local gl = Gui.new("GridLayout");
	gl.ColumnWeights = {1};
	gl.RowHeights = {15};
	gl.RowWeights = {0};
	gl.MinimumGridDimensions = Vector3.new(1, 1);
	gl.LayoutParams = {
		Role = Gui.Enum.DropDownRole.GridLayout;
	};
	gl.Name = "CustomGridLayout";
	gl.Parent = dd;
	dd.IsFocused = true;
end

return DropDown;

