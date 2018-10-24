local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "LinearScroller: ", true);

local DIRECTION_ENUM = Utils.new("Enum", "Direction", "Horizontal", "Vertical");
local LINEARSCROLLER_SCHEMA = {
	ScrollBar = {
		Type = "Single";
		LayoutParams = {
			Width = 16;
			SetValue = function(gui, index, range, total)
				gui.Index = index;
				gui.Range = range;
				gui.Total = total;
			end;
		};
		Default = Gui.Create "ScrollBar" {
			LayoutParams = {AspectRatio = 0.5; LinearSize = 0;};
			Name = "ScrollBar";
		};
		ParentName = "_Button";
	};
	DefaultRole = "ScrollBar";
	['*'] = {
		Type = "Many";
		LayoutParams = {
			Format = function(element, index)
				
			end;
			LinearSize = 0;
			AspectRatio = 0;
		};
		Default = Gui.Create "Rectangle" {
			LayoutParams = {
				Format = function(element, index)
					element.Color = Color3.fromHSV((index - 1) % 9 / 9, 1, 1)
				end
			};
		};
	};
};

local Super = Gui.SpecializedLayout;
local LinearScroller = Utils.new("Class", "LinearScroller", Super);

LinearScroller._Direction = DIRECTION_ENUM.Vertical;
LinearScroller._Cushion = 0;
LinearScroller._InnerMargin = Utils.new("Margin", 0);
LinearScroller._ChildTypes = {};
LinearScroller._Index = 0;
LinearScroller._Offset = 0;

LinearScroller._LastPos = UDim2.new(123, 345, 543, 321);
LinearScroller._LastSize = UDim2.new(-1, -2, 3, 4);
LinearScroller._Button = false;
LinearScroller._TotalIndices = 0;
LinearScroller._ScrollPixels = 0;
LinearScroller._ScrollAspect = 0;

function LinearScroller.Set:Direction(v)
	v = DIRECTION_ENUM:ValidateEnum(v);
	self._Direction = v;
	self._TriggerReflow();
end
function LinearScroller.Set:Cushion(v)
	self._Cushion = v;
	self._TriggerReflow();
	self:_RecalculateChildren();
end
function LinearScroller.Set:InnerMargin(v)
	Utils.Log.AssertNonNilAndType("InnerMargin", "table", v);
	self._InnerMargin = v;
	self._TriggerReflow();
end
function LinearScroller.Set:ChildTypes(v)
	self._ChildTypes = v;
	self:_RecalculateChildren();
	self._TriggerReflow();
end
function LinearScroller.Set:Index(v)
	self._Index = v;
	self._TriggerReflow();
end
function LinearScroller.Set:Offset(v)
	self._Offset = v;
	self._TriggerReflow();
end

LinearScroller.Get.Direction = "_Direction";
LinearScroller.Get.Cushion = "_Cushion";
LinearScroller.Get.InnerMargin = "_InnerMargin";
LinearScroller.Get.ChildTypes = "_ChildTypes";
LinearScroller.Get.Index = "_Index";
LinearScroller.Get.Offset = "_Offset";

--[[ @brief Compute _TotalIndices, _ScrollPixels, and _ScrollAspect.
     @details These variables are stored internally by the class and expected to change when any component features change.
--]]
function LinearScroller:_RecalculateChildren()
	local totalCount = 0;
	local scrollPixels = 0;
	local scrollAspect = 0;
	for i, tuple in pairs(self._ChildTypes) do
		local name, count = unpack(tuple);
		totalCount = totalCount + count;
		local params = self._ChildParameters:GetRoleLayoutParams(name);
		scrollPixels = scrollPixels + params.LinearSize * count;
		scrollAspect = scrollAspect + params.AspectRatio * count;
	end
	self._TotalIndices = totalCount;
	self._ScrollPixels = scrollPixels + self._Cushion * (totalCount - 1);
	self._ScrollAspect = scrollAspect;
end

function LinearScroller:_Reflow()
	local pos, size = Super._Reflow(self, true);
	local coordinatesChanged = pos ~= self._LastPos or size ~= self._LastSize;
	self._LastPos = pos;
	self._LastSize = size;
	self._Button._Size = size;
	self._Button._Position = pos;
	self._Button:_ConditionalReflow();

	local scrollBar, scrollBarParams = self._ChildParameters:GetChildOfRole("ScrollBar");
	scrollBar._Size = UDim2.new(0, scrollBarParams.Width, 1, 0);
	scrollBar._Position = UDim2.new(1, -scrollBarParams.Width, 0, 0);

	--Gui3Task: based on our current index, iterate through until we run out of space to render elements. Only add as many children of each role as needed.

	return pos, size;
end

function LinearScroller:_GetRbxHandle()
	return self._Button:_GetRbxHandle();
end

function LinearScroller.new()
	local self = setmetatable(Super.new(), LinearScroller.Meta);
	local function FlagChange(role)
		self:_RecalculateChildren();
		self:_TriggerReflow();
	end
	self._ChildParameters.RoleSourceChanged:connect(FlagChange);
	self._ChildParameters.LayoutParamsChanged:connect(FlagChange);
	self._Button = Gui.new("Button");
	self._ChildParameters.Schema = LINEARSCROLLER_SCHEMA;

	return self;
end

function Gui.Test.LinearScroller_Default(sgui, cgui)
	local s = LinearScroller.new();
	s.Parent = sgui;
end

return LinearScroller;
