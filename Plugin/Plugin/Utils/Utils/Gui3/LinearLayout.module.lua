local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "LinearLayout: ", false);

local Super = Gui.Layout;
local LinearLayout = Utils.new("Class", "LinearLayout", Super);

Gui.Enum:newEnumClass("Direction", "Horizontal", "Vertical");

LinearLayout._Direction = Gui.Enum.Direction.Vertical;
LinearLayout._Cushion = 0;
LinearLayout._Name = "LinearLayout";

function LinearLayout.Set:Cushion(v)
	self._Cushion = v;
	self:_TriggerReflow();
end
function LinearLayout.Set:Direction(v)
	v = Gui.Enum.Direction:InterpretEnum("Direction", v);
	self._Direction = v;
	self:_TriggerReflow();
end
LinearLayout.Get.Cushion = "_Cushion";
LinearLayout.Get.Direction = "_Direction";

function LinearLayout:_Clone(new)
	new.Cushion = self.Cushion;
	new.Direction = self.Direction;
end

function LinearLayout:_Reflow()
	Debug("LinearLayout._Reflow(%s) called", self);
	local pos, size = Super._Reflow(self, true);
	Utils.Log.AssertNonNilAndType("size", "userdata", size);

	local ortho, linear = "X", "Y";
	if self._Direction == Gui.Enum.Direction.Horizontal then
		ortho, linear = "Y", "X";
	end

	self._ChildParameters.Cache = true;

	--Get the sum of Size, Weight, and AspectRatio (potentially flipped).
	local sizeSum, weightSum, aspectSum = 0, 0, 0;
	for i, v, params in self:_IterateLayoutChildren() do
		sizeSum = sizeSum + params.Size;
		weightSum = weightSum + params.Weight;
		local aspect = params.AspectRatio;
		if aspect ~= 0 and self._Direction == Gui.Enum.Direction.Horizontal then
			aspect = 1 / aspect;
		end
		aspectSum = aspectSum + aspect;
	end
	Debug("Sums: Size=%d, Weight=%.1f, AspectRatio=%.1f", sizeSum, weightSum, aspectSum);

	--Determine how many pixels an aspect ratio of 1 equals.
	local aspectPixel = size[ortho].Offset;
	--Determine how many pixels a weight of 1 equals.
	local pixelsRemaining = size[linear].Offset
		- self._Cushion * (#self._Children - 1)
		- sizeSum
		- aspectPixel * aspectSum;
	local weightPixel = 0;
	if pixelsRemaining > 0 and weightSum ~= 0 then
		weightPixel = pixelsRemaining / weightSum;
	end
	
	--Order the children based on index.
	local children = {};
	for i, v, params in self:_IterateLayoutChildren() do
		if params.Index ~= 0 then
			if children[params.Index] then
				Utils.Log.Warn("Child %s and %s both have layout index of %d", children[params.Index], v, params.Index);
			else
				children[params.Index] = v;
			end
		end
	end
	local n = 1;
	for i, v, params in self:_IterateLayoutChildren() do
		if params.Index == 0 or children[params.Index] ~= v then
			while children[n] do
				n = n + 1;
			end
			children[n] = v;
		end
	end
	Utils.Table.CloseGaps(children);
	if Debug.Shown then
		Debug("Children in Render Order:");
		for i, v in pairs(children) do
			Debug("    %d = %s", i, v);
		end
	end

	--Place all children based on their Size, Weight, and AspectRatio
	local orthoSize = size[ortho].Offset;
	local p = 0;
	for i, v in pairs(children) do
		local params = self._ChildParameters[v];
		v._Position = pos + UDim2.new(0, linear=="X" and p or 0, 0, linear=="Y" and p or 0);
		local aspect = params.AspectRatio;
		if aspect ~= 0 and self._Direction == Gui.Enum.Direction.Horizontal then
			aspect = 1 / aspect;
		end
		local s = params.Size + aspect * aspectPixel + params.Weight * weightPixel;
		v._Size = UDim2.new(0, linear=="X" and s or orthoSize, 0, linear=="Y" and s or orthoSize);
		p = p + s + self._Cushion;
	end

	self._ChildParameters.Cache = false;
end

function LinearLayout.new()
	local self = setmetatable(Super.new(), LinearLayout.Meta);
	self.Cushion = self.Cushion;
	self.Direction = self.Direction;
	self._ChildParameters:SetDefault("Size", 0);
	self._ChildParameters:SetDefault("Weight", 1);
	self._ChildParameters:SetDefault("AspectRatio", 0);
	self._ChildParameters:SetDefault("Index", 0);
	return self;
end

function Gui.Test.LinearLayout_Default(sgui)
	local r = LinearLayout.new();
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
	Utils.Log.AssertEqual("rect1.Position", Vector2.new(0, 0), elements[1].AbsolutePosition);
	Utils.Log.AssertEqual("rect2.Position", Vector2.new(0, 40), elements[2].AbsolutePosition);
	Utils.Log.AssertEqual("rect3.Position", Vector2.new(0, 80), elements[3].AbsolutePosition);
	Utils.Log.AssertEqual("rect1.Size", Vector2.new(120, 40), elements[1].AbsoluteSize);
	Utils.Log.AssertEqual("rect2.Size", Vector2.new(120, 40), elements[2].AbsoluteSize);
	Utils.Log.AssertEqual("rect3.Size", Vector2.new(120, 40), elements[3].AbsoluteSize);
end

function Gui.Test.LinearLayout_Basic(sgui)
	local r = LinearLayout.new();
	r.Size = UDim2.new(0, 120, 0, 120);
	r.Position = UDim2.new(0, 0, 0, 0);
	r.Direction = "Horizontal";
	r.Cushion = 6;
	local elements = {};
	for i = 0, 2 do
		local s = Gui.new("Rectangle");
		s.Color = Color3.fromHSV(i/3, 1, 1);
		s.Parent = r;
		table.insert(elements, s);
	end
	r.Parent = sgui;
	Utils.Log.AssertEqual("rect1.Position", Vector2.new(0, 0), elements[1].AbsolutePosition);
	Utils.Log.AssertEqual("rect2.Position", Vector2.new(42, 0), elements[2].AbsolutePosition);
	Utils.Log.AssertEqual("rect3.Position", Vector2.new(84, 0), elements[3].AbsolutePosition);
	Utils.Log.AssertEqual("rect1.Size", Vector2.new(36, 120), elements[1].AbsoluteSize);
	Utils.Log.AssertEqual("rect2.Size", Vector2.new(36, 120), elements[2].AbsoluteSize);
	Utils.Log.AssertEqual("rect3.Size", Vector2.new(36, 120), elements[3].AbsoluteSize);
end

function Gui.Test.LinearLayout_Reverse(sgui)
	local r = LinearLayout.new();
	r.Size = UDim2.new(0, 120, 0, 120);
	local elements = {};
	for i = 0, 2 do
		local s = Gui.new("Rectangle");
		s.Name = "Rect" .. tostring(i+1);
		s.Color = Color3.fromHSV(i/3, 1, 1);
		s.Parent = r;
		s.LayoutParams = {Index = 3 - i};
		table.insert(elements, s);
	end
	r.Parent = sgui;
	r:_ConditionalReflow();
	Utils.Log.AssertEqual("rect1.Position", Vector2.new(0, 80), elements[1].AbsolutePosition);
	Utils.Log.AssertEqual("rect2.Position", Vector2.new(0, 40), elements[2].AbsolutePosition);
	Utils.Log.AssertEqual("rect3.Position", Vector2.new(0, 0), elements[3].AbsolutePosition);
	Utils.Log.AssertEqual("rect1.Size", Vector2.new(120, 40), elements[1].AbsoluteSize);
	Utils.Log.AssertEqual("rect2.Size", Vector2.new(120, 40), elements[2].AbsoluteSize);
	Utils.Log.AssertEqual("rect3.Size", Vector2.new(120, 40), elements[3].AbsoluteSize);
end

function Gui.Test.LinearLayout_Aspect(sgui)
	local r = LinearLayout.new();
	r.Size = UDim2.new(0, 80, 0, 160);
	local elements = {};
	for i = 0, 2 do
		local s = Gui.new("Rectangle");
		s.Color = Color3.fromHSV(i/3, 1, 1);
		s.Parent = r;
		s.LayoutParams = {AspectRatio = .5; Weight = 0;};
		table.insert(elements, s);
	end
	r.Parent = sgui;
	r:_ConditionalReflow();
	Utils.Log.AssertEqual("rect1.Position", Vector2.new(0, 0), elements[1].AbsolutePosition);
	Utils.Log.AssertEqual("rect2.Position", Vector2.new(0, 40), elements[2].AbsolutePosition);
	Utils.Log.AssertEqual("rect3.Position", Vector2.new(0, 80), elements[3].AbsolutePosition);
	Utils.Log.AssertEqual("rect1.Size", Vector2.new(80, 40), elements[1].AbsoluteSize);
	Utils.Log.AssertEqual("rect2.Size", Vector2.new(80, 40), elements[2].AbsoluteSize);
	Utils.Log.AssertEqual("rect3.Size", Vector2.new(80, 40), elements[3].AbsoluteSize);
end

return LinearLayout;
