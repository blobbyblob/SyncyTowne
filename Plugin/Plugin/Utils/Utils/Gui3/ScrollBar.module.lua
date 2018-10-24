local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local ARROW_SCROLL_COUNT = 12;

local Debug = Utils.new("Log", "ScrollBar: ", true);

--Gui3Task: make/get some sensible defaults
local SCROLLBAR_SCHEMA = {
	Backdrop = {
		Type = "Single";
		LayoutParams = {};
		Default = Gui.Create "Rectangle" {
			Name = "Backdrop";
			Color = Utils.Math.HexColor(0xCC88FF);
			ZIndex = 0;
		};
		ParentName = "_Button";
	};
	Bar = {
		Type = "Single";
		LayoutParams = {
			MinimumSize = 0;
		};
		Default = Gui.Create "Rectangle" {
			Name = "Bar";
			Color = Utils.Math.HexColor(0x88FFCC);
		};
		ParentName = "_Button";
	};
	Arrow = {
		Type = "Many";
		LayoutParams = {
			SetArrowDirection = function(gui, direction) Debug("SetArrowDirection(%s, %s) called", gui, direction); end;
			GetClickEvent = function(gui) Debug("GetClickEvent(%s) called", gui); end;
			AspectRatio = 1;
		};
		Default = Gui.Create "Rectangle" {
			Name = "Arrow";
			Color = Utils.Math.HexColor(0xFFCC88);
			LayoutParams = {
				AspectRatio = 16/9;
			};
		};
		ParentName = "_Button";
	};
	DefaultRole = "Backdrop";
};
local DIRECTION_ENUM = Utils.new("Enum", "Direction", "Horizontal", "Vertical");

local Super = Gui.SpecializedLayout;
local ScrollBar = Utils.new("Class", "ScrollBar", Super);

ScrollBar._Index = 0;
ScrollBar._Total = 600;
ScrollBar._Range = 200;
ScrollBar._Direction = DIRECTION_ENUM.Vertical;

ScrollBar._LastPos = UDim2.new();
ScrollBar._LastSize = UDim2.new();
ScrollBar._Button = false;
ScrollBar._ReflowAllFlag = true;

function ScrollBar.Set:Total(v)
	self._Total = v;
	self:_TriggerReflow();
end
function ScrollBar.Set:Range(v)
	self._Range = v;
	self:_TriggerReflow();
end
function ScrollBar.Set:Direction(v)
	self._Direction = DIRECTION_ENUM:InterpretEnum("Direction", v);
	self._ReflowAllFlag = true;
	self:_TriggerReflow();
end
function ScrollBar.Set:Index(v)
	self._Index = v;
	self:_TriggerReflow();
end
ScrollBar.Get.Total = "_Total";
ScrollBar.Get.Range = "_Range";
ScrollBar.Get.Direction = "_Direction";
ScrollBar.Get.Index = "_Index";

function ScrollBar:_GetRbxHandle()
	return self._Button:_GetRbxHandle();
end

function ScrollBar:_Reflow()
	Debug("ScrollBar._Reflow(%s) called", self);
	local pos, size = Super._Reflow(self, true);
	if size.X.Offset < 0 or size.Y.Offset < 0 then
		size = UDim2.new(0, size.X.Offset < 0 and 0 or size.X.Offset, 0, size.Y.Offset < 0 and 0 or size.Y.Offset);
	end
	local coordinatesChanged = pos ~= self._LastPos or size ~= self._LastSize;
	self._LastPos = pos;
	self._LastSize = size;
	self._Button._AbsoluteSize = self._AbsoluteSize;
	self._Button._AbsolutePosition = self._AbsolutePosition;

	if self._Total <= 0 then
		self._Total = 1;
		self._Range = 1;
	end
	if self._Range > self._Total then
		self._Range = self._Total;
	end
	if self._Index < 0 then
		self._Index = 0;
	elseif self._Index + self._Range > self._Total then
		self._Index = self._Total - self._Range;
	end

	local bar, barParams = self._ChildParameters:GetChildOfRole("Bar");
	local upArrow, arrowParams = self._ChildParameters:GetChildOfRole("Arrow", 1);
	local buttonAspect = arrowParams.AspectRatio;
	local orthoSize = size.X.Offset;
	local linearSize = size.Y.Offset;
	local MakeUDim = UDim2.new;
	if self._Direction == DIRECTION_ENUM.Horizontal then
		orthoSize, linearSize = linearSize, orthoSize;
		function MakeUDim(a, b, c, d)
			return UDim2.new(c, d, a, b);
		end
	else
		buttonAspect = 1/buttonAspect;
	end
	local arrowSize = math.floor(orthoSize * buttonAspect);
	local totalSize = linearSize - arrowSize * 2;
	local proportionalSize = self._Range / self._Total;
	local proportionalPosition = self._Index / self._Total;
	if barParams.MinimumSize > proportionalSize then
		proportionalSize = barParams.MinimumSize;
	end

	if coordinatesChanged or self._ReflowAllFlag then
		self._ReflowAllFlag = false;
		local backdrop = self._ChildParameters:GetChildOfRole("Backdrop");
		backdrop._Size = MakeUDim(0, orthoSize, 0, totalSize);
		backdrop._Position = MakeUDim(0, 0, 0, arrowSize);

		upArrow._Size = MakeUDim(0, orthoSize, 0, arrowSize);
		upArrow._Position = MakeUDim();

		local downArrow = self._ChildParameters:GetChildOfRole("Arrow", 2);
		downArrow._Size = MakeUDim(0, orthoSize, 0, arrowSize);
		downArrow._Position = MakeUDim(0, 0, 0, totalSize + arrowSize);
	end

	bar._Size = MakeUDim(0, orthoSize, 0, totalSize * proportionalSize);
	bar._Position = MakeUDim(0, 0, 0, arrowSize + totalSize * proportionalPosition);
end

function PositionInSpace(gui, s)
	local pos = gui.AbsolutePosition;
	local size = gui.AbsoluteSize;
	return pos.x <= s.x and s.x <= pos.x + size.x and pos.y <= s.y and s.y <= pos.y + size.y, s.x < pos.x or s.y < pos.y;
end

local UIS = game:GetService("UserInputService");
function ScrollBar.new()
	local self = setmetatable(Super.new(), ScrollBar.Meta);
	self._Button = Gui.Create "Button" {};
	self._Button.Click1:connect(function(x, y)
		Debug("Click1(%s, %s) called", x, y);
		local offset = Vector2.new(x, y);
		local guiSpace = self._Button.AbsolutePosition + offset;

		local bar, barParams = self._ChildParameters:GetChildOfRole("Bar");
		local upArrow, arrowParams = self._ChildParameters:GetChildOfRole("Arrow", 1);
		local downArrow = self._ChildParameters:GetChildOfRole("Arrow", 2);
		if PositionInSpace(downArrow, guiSpace) then
			Debug("Clicked Down Arrow");
			self.Index = self.Index + ARROW_SCROLL_COUNT;
			self:_ConditionalReflow();
		elseif PositionInSpace(upArrow, guiSpace) then
			Debug("Clicked Up Arrow");
			self.Index = self.Index - ARROW_SCROLL_COUNT;
			self:_ConditionalReflow();
		else
			local inBar, isBefore = PositionInSpace(bar, guiSpace);
			if not inBar then
				Debug("Clicked Backdrop (not Bar)");
				self.Index = self.Index + (isBefore and -1 or 1) * self._Range;
				self:_ConditionalReflow();
			end
		end
	end);
	local dragging = false;
	local conversion = 0;
	self._Button.Drag:connect(function(state, x, y)
		Debug("Drag(%s, %s, %s) called", state, x, y);
		if state == "Down" then
			local offset = Vector2.new(x, y);
			local guiSpace = self._Button.AbsolutePosition + offset;
			local bar = self._ChildParameters:GetChildOfRole("Bar");
			if PositionInSpace(bar, guiSpace) then
				local backdrop = self._ChildParameters:GetChildOfRole("Backdrop");
				conversion = self._Total / backdrop.AbsoluteSize[self._Direction == DIRECTION_ENUM.Horizontal and 'x' or 'y'];
				dragging = UIS:GetMouseLocation();
			end
		elseif dragging then
			local delta = dragging - UIS:GetMouseLocation();
			self.Index = self.Index - delta[self._Direction == DIRECTION_ENUM.Horizontal and "x" or "y"] * conversion;
			dragging = UIS:GetMouseLocation();
			if state == "Up" then
				dragging = false;
			end
			self:_ConditionalReflow();
		end
	end)
	self._ChildParameters.Schema = SCROLLBAR_SCHEMA;
	self._ChildParameters:SetRoleCount("Arrow", 2);
	return self;
end

function Gui.Test.ScrollBar_Default(sgui, cgui)
	local s = ScrollBar.new();
	s.Size = UDim2.new(0, 25, 0, 150);
	s.Position = UDim2.new(.5, -12, .5, -75);
	s.Parent = cgui;
end

function Gui.Test.ScrollBar_Horizontal(sgui, cgui)
	local s = ScrollBar.new();
	s.Size = UDim2.new(0, 450, 0, 25);
	s.Position = UDim2.new(.5, -225, 0.5, -12);
	s.Direction = "Horizontal";
	s.Parent = cgui;
end

function Gui.Test.ScrollBar_Clone(sgui, cgui)
	local s = ScrollBar.new();
	s.Size = UDim2.new(0, 25, 0, 450);
	s.Position = UDim2.new(.5, -12, 0.5, -225);
	local t = s:Clone();
	t.Parent = cgui;
	Utils.Log.Assert("Number of children", 4, s:GetChildren());
	Utils.Log.Assert("Number of children", 4, s:_GetRbxHandle():GetChildren());
end

--Gui3Task: Figure out why sliding is somewhat laggy.

return ScrollBar;
