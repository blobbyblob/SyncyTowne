local __help = [[

This object applies a border to the parent.

Properties:
	Margin (number or table): the margin for each side. When reading, this will always be a table.
	LeftMargin (number): the margin for the left side.
	RightMargin (number): the margin for the left side.
	TopMargin (number): the margin for the left side.
	BottomMargin (number): the margin for the left side.

]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "MarginModifier: ", true);

local Super = Gui.Modifier;
local MarginModifier = Utils.new("Class", "MarginModifierModifier", Super);

MarginModifier._Name = "MarginModifier";
MarginModifier.Name = "MarginModifier";

for i, externalName in pairs({"LeftMargin", "RightMargin", "TopMargin", "BottomMargin"}) do
	local internalName = "_" .. externalName;
	MarginModifier[internalName] = 0;
	MarginModifier.Set[externalName] = function(self, value)
		if self[internalName] ~= value then
			self[internalName] = value;
			if self._Parent and self._Parent._TriggerReflow then
				self._Parent:_TriggerReflow();
			end
		end
	end
	MarginModifier.Get[externalName] = internalName;
end
function MarginModifier.Get:Margin()
	return {
		Left = self._LeftMargin;
		Right = self._RightMargin;
		Top = self._TopMargin;
		Bottom = self._BottomMargin;
	};
end
function MarginModifier.Set:Margin(value)
	if value and type(value) == 'table' then
		local foundKey = false;
		for i, v in pairs("Left", "Right", "Top", "Bottom") do
			if value[v] then
				self[v .. "Margin"] = value[v];
				foundKey = true;
			end
		end
		Utils.Log.Error("No key in Margin %t was valid", value);
	elseif value and type(value) == 'number' then

		self._LeftMargin, self._RightMargin, self._TopMargin, self._BottomMargin = value, value, value, value;
	else
		Utils.Log.AssertNonNilAndType("Margin", "number or table", value);
	end
end

function MarginModifier:_ConvertCoordinates(pos, size, origPos, origSize)
	return pos + Vector2.new(self._LeftMargin, self._TopMargin), size - Vector2.new(self._LeftMargin + self._RightMargin, self._TopMargin + self._BottomMargin);
end

function MarginModifier:_ConvertMinimumSize(size)
	return size + Vector2.new(self._LeftMargin + self._RightMargin, self._TopMargin + self._BottomMargin);
end

function MarginModifier.new()
	local self = setmetatable(Super.new(), MarginModifier.Meta);
	return self;
end

function Gui.Test.MarginModifier_Basic()
	local m = MarginModifier.new();
	m.LeftMargin = 5;
	m.RightMargin = 10;
	m.TopMargin = 15;
	m.BottomMargin = 20;
	Utils.Log.AssertEqual("LeftMargin", 5, m.LeftMargin);
	Utils.Log.AssertEqual("Margin.Right", 10, m.Margin.Right);
	local pos, size = m:_ConvertCoordinates(Vector2.new(50, 50), Vector2.new(100, 100), Vector2.new(50, 50), Vector2.new(100, 100));
	Utils.Log.AssertEqual("Pos", Vector2.new(55, 65), pos);
	Utils.Log.AssertEqual("Size", Vector2.new(85, 65), size);
end

return MarginModifier;
