local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "GridLayout: ", false);

Gui.Enum:newEnumClass("StartCorner", "TopLeft", "TopRight", "BottomLeft", "BottomRight");
Gui.Enum:newEnumClass("FillDirection", "Horizontal", "Vertical");

local START_CORNER_TO_INT = {
	[Gui.Enum.StartCorner.TopLeft] = 0;
	[Gui.Enum.StartCorner.TopRight] = 1;
	[Gui.Enum.StartCorner.BottomLeft] = 2;
	[Gui.Enum.StartCorner.BottomRight] = 3;
};
local FILL_DIRECTION_TO_STRING = {
	[Gui.Enum.FillDirection.Horizontal] = "Vertical";
	[Gui.Enum.FillDirection.Vertical] = "Horizontal";
};

local Super = Gui.Layout;
local GridLayout = Utils.new("Class", "GridLayout", Super);

GridLayout._GridSize = Vector2.new(1, 1);
GridLayout._Cushion = Vector2.new(0, 0);
GridLayout._StartCorner = Gui.Enum.StartCorner.TopLeft;
GridLayout._FillDirection = Gui.Enum.FillDirection.Horizontal;
GridLayout._RowAspectRatios = {0};
GridLayout._RowWeights = {1};
GridLayout._RowSizes = {0};
GridLayout._ColumnAspectRatios = {0};
GridLayout._ColumnWeights = {1};
GridLayout._ColumnSizes = {0};

for publicProperty, privateProperty in pairs({
		GridSize = "_GridSize";
		Cushion = "_Cushion";
		RowAspectRatios = "_RowAspectRatios";
		RowWeights = "_RowWeights";
		RowSizes = "_RowSizes";
		ColumnAspectRatios = "_ColumnAspectRatios";
		ColumnWeights = "_ColumnWeights";
		ColumnSizes = "_ColumnSizes"; }) do
	GridLayout.Set[publicProperty] = function(self, value)
		self[privateProperty] = value;
		self:_TriggerReflow();
	end
	GridLayout.Get[publicProperty] = privateProperty;
end
function GridLayout.Set:StartCorner(v)
	v = Gui.Enum.StartCorner:InterpretEnum("StartCorner", v);
	self._StartCorner = v;
	self:_TriggerReflow();
end
function GridLayout.Set:FillDirection(v)
	v = Gui.Enum.FillDirection:InterpretEnum("FillDirection", v);
	self._FillDirection = v;
	self:_TriggerReflow();
end
GridLayout.Get.StartCorner = "_StartCorner";
GridLayout.Get.FillDirection = "_FillDirection";

function GridLayout:_Clone(new)
	new.GridSize = self.GridSize;
	new.Cushion = self.Cushion;
	new.RowAspectRatios = self.RowAspectRatios;
	new.RowWeights = self.RowWeights;
	new.RowSizes = self.RowSizes;
	new.ColumnAspectRatios = self.ColumnAspectRatios;
	new.ColumnWeights = self.ColumnWeights;
	new.ColumnSizes = self.ColumnSizes;
end

local function PadToLength(t, n)
	for i = 1, n do
		if t[i] == nil then
			t[i] = t[i - 1] or 0;
		end
	end
	return t;
end
local tableAdd = Utils.Table.Add;
local scalarMultiply = Utils.Table.MultiplyNumberByTable;
local range = Utils.Table.Range;

function GridLayout:_Reflow()
	if not self._Parent then
		return Super._Reflow(self, true);
	end
	Debug("GridLayout._Reflow(%s) called", self);
	local pos, size = Super._Reflow(self, true);
	Utils.Log.AssertNonNilAndType("size", "userdata", size);
	Debug("Position: <%s>; Size: <%s>", pos, size);

	self._ChildParameters.Cache = true;

	local GridCellFinder = require(script.GridCellFinder).new();
	GridCellFinder.AnchorLocation = START_CORNER_TO_INT[self._StartCorner];
	GridCellFinder.FillDirection = FILL_DIRECTION_TO_STRING[self._FillDirection];
	GridCellFinder.MinimumSize = self._GridSize;
	for i, v, params in self:_IterateLayoutChildren() do
		if params.Position == Vector2.new() then
			GridCellFinder:RegisterUnknownLocation(i, params.Size.x, params.Size.y);
		else
			GridCellFinder:RegisterKnownLocation(i, params.Position.x, params.Position.y, params.Size.x, params.Size.y);
		end
	end
	local sz = GridCellFinder.Size;

	local accumulateSizeX = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._ColumnSizes), sz.x));
	local accumulateSizeY = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._RowSizes), sz.y));
	local accumulateAspectX = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._ColumnAspectRatios), sz.x));
	local accumulateAspectY = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._RowAspectRatios), sz.y));
	local accumulateWeightX = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._ColumnWeights), sz.x));
	local accumulateWeightY = Utils.Table.Accumulate(PadToLength(Utils.Table.ShallowCopy(self._RowWeights), sz.y));
	local sumAspectX = accumulateAspectX[sz.x];
	local sumAspectY = accumulateAspectY[sz.y];
	Debug("Pixel Requirement: <%s, %s>", accumulateSizeX[sz.x], accumulateSizeY[sz.y]);
	Debug("AspectRatios: x=%.1f, y=%.1f; y/x = %.2f", sumAspectX, sumAspectY, sumAspectX==0 and 0 or sumAspectY/sumAspectX);
	local aspectPixels = 0;
	local rowWeightPixels, columnWeightPixels = 0, 0;
	if sumAspectX ~= 0 and sumAspectY ~= 0 then
		local size = Vector2.new(
			size.X.Offset - accumulateSizeX[sz.x] - self._Cushion.x * (sz.x - 1),
			size.Y.Offset - accumulateSizeY[sz.y] - self._Cushion.y * (sz.y - 1)
		);
		Debug("Excess Space (for weights): %s", size);
		local aspect = sumAspectY/sumAspectX;
		local yReq = size.x * aspect;
		local xReq = size.y / aspect;
		if size.y > yReq then
			--We have more than enough height. Distribute extra space to rows.
			aspectPixels = size.x / sumAspectX;
			if accumulateWeightY[sz.y] > 0 then
				rowWeightPixels = (size.y - yReq) / accumulateWeightY[sz.y];
			end
		else
			--We have less height than necessary. Define the "aspectPixelCount" by the height and distribute extra space to rows.
			aspectPixels = size.y / sumAspectY;
			if accumulateWeightX[sz.x] > 0 then
				columnWeightPixels = (size.x - xReq) / accumulateWeightX[sz.x];
			end
		end
	else
		local size = Vector2.new(
			size.X.Offset - accumulateSizeX[sz.x] - self._Cushion.x * (sz.x - 1),
			size.Y.Offset - accumulateSizeY[sz.y] - self._Cushion.y * (sz.y - 1)
		);
		Debug("Excess Space (for weights): %s", size);
		rowWeightPixels = size.y / accumulateWeightY[sz.y];
		columnWeightPixels = size.x / accumulateWeightX[sz.x];
	end
	Debug("Table Arithmetic Input:");
	Debug("    aspectPixels: %.1f", aspectPixels);
	Debug("    weightPixels: %.1f, %.1f", columnWeightPixels, rowWeightPixels);
	Debug("    cushion: %s", self._Cushion);
	Debug("    accumulateSizeX: %t", accumulateSizeX);
	Debug("    accumulateAspectX: %t", accumulateAspectX);
	Debug("    accumulateWeightX: %t", accumulateWeightX);
	Debug("    accumulateSizeY: %t", accumulateSizeY);
	Debug("    accumulateAspectY: %t", accumulateAspectY);
	Debug("    accumulateWeightY: %t", accumulateWeightY);
	local columnBoundaries = tableAdd(
		accumulateSizeX,
		scalarMultiply(aspectPixels, accumulateAspectX),
		scalarMultiply(columnWeightPixels, accumulateWeightX),
		scalarMultiply(self._Cushion.x, range(1, sz.x + 1)));
	local rowBoundaries = tableAdd(
		accumulateSizeY,
		scalarMultiply(aspectPixels, accumulateAspectY),
		scalarMultiply(rowWeightPixels, accumulateWeightY),
		scalarMultiply(self._Cushion.y, range(1, sz.y + 1)));
	table.insert(columnBoundaries, 1, 0);
	table.insert(rowBoundaries, 1, 0);
	Debug("ColumnBoundaries: %t", columnBoundaries);
	Debug("RowBoundaries: %t", rowBoundaries);

	for i, v, params in self:_IterateLayoutChildren() do
		local position = GridCellFinder:FetchLocation(i);
		local size = params.Size;

		Debug("Placing %s at cell position <%s>, size <%s>", v, position, size);
		--FInally, convert the pos/size to cell begin/end points.
		Debug("Column boundaries: %s - %s", columnBoundaries[position.x], columnBoundaries[position.x + size.x]);
		Debug("Row boundaries: %s - %s", rowBoundaries[position.y], rowBoundaries[position.y + size.y]);

		v._Position = pos + UDim2.new(0, columnBoundaries[position.x], 0, rowBoundaries[position.y])
		v._Size = UDim2.new(
			0, columnBoundaries[position.x + size.x] - columnBoundaries[position.x] - self._Cushion.x,
			0, rowBoundaries[position.y + size.y] - rowBoundaries[position.y] - self._Cushion.y)
	end

	for i, v, params in self:_IterateLayoutChildren() do
		v:_ConditionalReflow();
	end

	self._ChildParameters.Cache = false;
end

function GridLayout.new()
	local self = setmetatable(Super.new(), GridLayout.Meta);
	GridLayout._Clone(self, self);
	self._ChildParameters:SetDefault("Size", Vector2.new(1, 1));
	self._ChildParameters:SetDefault("Position", Vector2.new());
	return self;
end

function Gui.Test.GridLayout_Default(sgui)
	local r = GridLayout.new();
	r.Size = UDim2.new(0, 120, 0, 120);
	r.Position = UDim2.new(0, 0, 0, 0);
	local elements = {};
	for i = 1, 3 do
		local s = Gui.new("Rectangle");
		s.Color = Color3.new(math.random(), math.random(), math.random());
		s.Parent = r;
		table.insert(elements, s);
	end
	r.Parent = sgui;
end
function Gui.Test.GridLayout_Basic(sgui)
	local rect = Gui.new("Rectangle");
	rect.Size = UDim2.new(0, 140, 0, 140);
	rect.Parent = sgui;
	local r = GridLayout.new();
	r.Cushion = Vector2.new(4, 4);
	r.GridSize = Vector2.new(3, 3);
	r.StartCorner = Gui.Enum.StartCorner.TopRight;
	r.FillDirection = Gui.Enum.FillDirection.Vertical;
	local elements = {};
	for i = 1, 8 do
		local s = Gui.new("Rectangle");
		s.Color = Color3.new(math.random(), math.random(), math.random());
		s.Parent = r;
		table.insert(elements, s);
	end
	r.Parent = rect;
end
function Gui.Test.GridLayout_Aspect(sgui)
	local rect = Gui.new("Rectangle");
	rect.Size = UDim2.new(0, 300, 0, 100);
	rect.Parent = sgui;
	local r = GridLayout.new();
	r.RowAspectRatios = {1};
	r.ColumnAspectRatios = {1};
	r.GridSize = Vector2.new(2, 1);
	r.RowWeights = {0};
	r.ColumnWeights = {0, 1};
	local elements = {};
	for i = 1, 2 do
		local s = Gui.new("Rectangle");
		s.Color = Color3.new(math.random(), math.random(), math.random());
		s.Parent = r;
		table.insert(elements, s);
	end
	r.Parent = rect;
end

return GridLayout;
