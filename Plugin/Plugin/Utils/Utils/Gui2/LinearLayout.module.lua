local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local View = require(script.Parent.View);
local Test = Gui.Test;

local ReflowDebug = Gui.Log.Reflow;
local Debug = Gui.Log.Debug;

local LinearLayout = Utils.new("Class", "LinearLayout", View);
local Super = LinearLayout.Super;

local LinearLayoutDebug = Log.new("LinearLayout:\t", false);

Gui.Enum:newEnumClass("LinearLayoutDirection", "Horizontal", "Vertical");

LinearLayout._Cushion = 0;
LinearLayout._InferSize = true;
LinearLayout._Direction = Gui.Enum.LinearLayoutDirection.Vertical;
LinearLayout._AlwaysUseFrame = false;
LinearLayout._GridLayoutBacking = false;
LinearLayout._ChildProperties = {
	Size = false; --defaults to 0 when InferSize = false.
	Weight = 1;
	AspectRatio = 0;
	Index = 0;
};
LinearLayout._ChildPlacements = false;
--
--function LinearLayout.Set:_GridLayoutBacking(v)
--	Log.Warn("%s._GridLayoutBacking = %s", self, v);
--	if tostring(v)=="Window_TitleBar" then
--		Log.Error("Whoops!");
--	end
--	self.__GridLayoutBacking = v;
--end
--LinearLayout.Get._GridLayoutBacking = "__GridLayoutBacking";

--[[ @brief Sets the cushion.
     @param cushion The amount of space to fit between elements.
--]]
function LinearLayout.Set:Cushion(v)
	Log.AssertNonNilAndType("Cushion", "number", v);
	self._Cushion = v;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets whether size should be queried or defaulted to 0.
     @param infer If true, the minimum size of the children will be used in laying out the elements. Otherwise, 0 will be used.
--]]
function LinearLayout.Set:InferSize(v)
	Log.AssertNonNilAndType("InferSize", "boolean", v);
	self._InferSize = v;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets the direction of the layout.
     @param dir A value of Gui.Enum.LinearLayoutDirection.Horizontal or Gui.Enum.LinearLayoutDirection.Vertical.
--]]
function LinearLayout.Set:Direction(v)
	v = Gui.Enum.LinearLayoutDirection:ValidateEnum(v, "Direction");
	self._Direction = v;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Sets whether a frame should group all elements.
     @param v True if a frame should group all children.
--]]
function LinearLayout.Set:AlwaysUseFrame(v)
	Log.AssertNonNilAndType("AlwaysUseFrame", "boolean", v);
	self._AlwaysUseFrame = v;
	self._GridLayoutBacking.AlwaysUseFrame = v;
	self._SignalReflowPre:Trigger();
end
--[[ @brief Passes the FillX/FillY parameters to the underlying grid layout.
--]]
function LinearLayout.Set:FillX(v)
	self._GridLayoutBacking.FillX = v;
end
function LinearLayout.Set:FillY(v)
	self._GridLayoutBacking.FillY = v;
end
function LinearLayout.Set:Gravity(v)
	self._GridLayoutBacking.Gravity = v;
end
function LinearLayout.Set:Margin(v)
	self._GridLayoutBacking.Margin = v;
end
LinearLayout.Get.Cushion = "_Cushion";
LinearLayout.Get.InferSize = "_InferSize";
LinearLayout.Get.Direction = "_Direction";
LinearLayout.Get.AlwaysUseFrame = "_AlwaysUseFrame";
LinearLayout.Get.ChildProperties = "_ChildProperties";
function LinearLayout.Get:FillX()
	return self._GridLayoutBacking.FillX;
end
function LinearLayout.Get:FillY()
	return self._GridLayoutBacking.FillY;
end
function LinearLayout.Get:Gravity()
	return self._GridLayoutBacking.Gravity;
end
function LinearLayout.Get:Margin()
	return self._GridLayoutBacking.Margin;
end


function LinearLayout.Set:ParentNoNotify(v)
	self._GridLayoutBacking.ParentNoNotify = v;
	Super.Set.ParentNoNotify(self, v);
end

function LinearLayout.Set:Parent(v)
	self._GridLayoutBacking.ParentNoNotify = v;
	Super.Set.Parent(self, v);
end

--[[ @brief Returns the children in the order they were added. If their LayoutParams.Index property is set, they will attempt to be placed at that index.
     @param self The LinearLayout we are obtaining children from.
--]]
function GetChildrenInOrder(self)
	local children = {};
	local maxn = 0;
	for i, v in pairs(self:GetChildren()) do
		local layoutParams = self._ChildProperties[v];
		if layoutParams.Index~=0 then
			children[layoutParams.Index] = v;
			if layoutParams.Index > maxn then
				maxn = layoutParams.Index;
			end
		end
	end
	for i, v in pairs(self:GetChildren()) do
		local layoutParams = self._ChildProperties[v];
		if layoutParams.Index==0 then
			children[#children+1] = v;
			if #children > maxn then
				maxn = #children;
			end
		end
	end
	Utils.Table.CloseGaps(children, maxn);
	return children;
end

--[[ @brief Update the underlying grid layout to recognize all parameters for this LinearLayout.
     @details Parameters will be passed from LinearLayout to GridLayout.
--]]
function LinearLayout:_UpdateGridLayout()
	local children = GetChildrenInOrder(self);
	LinearLayoutDebug("Children in order:");
	for i, v in pairs(children) do
		LinearLayoutDebug("    %s = %s", i, v);
	end

	self._GridLayoutBacking.AlwaysUseFrame = self._AlwaysUseFrame;

	local linearDirection, orthoDirection = "x", "y";
	local linearPixels, orthoPixels = self._GridLayoutBacking.ColumnWidths, self._GridLayoutBacking.RowHeights;
	local linearWeights = self._GridLayoutBacking.ColumnWeights;
	local aspectWeights = self._GridLayoutBacking.ColumnRowWeights;
	if self._Direction == Gui.Enum.LinearLayoutDirection.Vertical then
		LinearLayoutDebug("Laying out vertically");
		linearDirection, orthoDirection = "y", "x";
		linearPixels, orthoPixels = orthoPixels, linearPixels;
		linearWeights = self._GridLayoutBacking.RowWeights;
		aspectWeights = self._GridLayoutBacking.RowColumnWeights;

		self._GridLayoutBacking.ColumnWeights = {1};
		self._GridLayoutBacking.ColumnRowWeights = {0};
		self._GridLayoutBacking.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Vertical;
	else
		LinearLayoutDebug("Laying out horizontally");
		self._GridLayoutBacking.RowColumnWeights = {0};
		self._GridLayoutBacking.RowWeights = {1};
		self._GridLayoutBacking.GrowthDirection = Gui.Enum.GridLayoutGrowthDirection.Horizontal;
	end
	local orthoSize = 0;
	--Iterate through children and place them in the correct slot.
	--Size the slots based on the requested size/weight.
	--If AspectRatio is defined, size the slot based on how much orthogonal space is given.
	for i, v in pairs(children) do
		local sz = v:_GetMinimumSize();
		local t = self._GridLayoutBacking.ChildProperties:GetWritableParameters(v);
		t[linearDirection:upper()] = i;
		t[orthoDirection:upper()] = 1;
		t.Width = 1;
		t.Height = 1;
		local layoutParams = self._ChildProperties[v];
		local linearPixelRequirement = layoutParams.Size;
		if not layoutParams.Size and self._InferSize then
			linearPixelRequirement = sz[linearDirection];
		end

		orthoSize = math.max(orthoSize, sz[orthoDirection]);
		linearPixels[i] = linearPixelRequirement;
		linearWeights[i] = layoutParams.Weight;
		LinearLayoutDebug("Element %s", v);
		LinearLayoutDebug("    Required pixels: %s", linearPixels[i]);
		LinearLayoutDebug("    Weight: %s", linearWeights[i]);

		if layoutParams.AspectRatio ~= 0 then
			local aspectRatio = layoutParams.AspectRatio;
			if self._Direction ~= Gui.Enum.LinearLayoutDirection.Vertical then
				aspectRatio = 1 / aspectRatio;
			end
			linearPixels[i] = 0;
			orthoSize = math.max(orthoSize, sz[linearDirection]*aspectRatio);
			aspectWeights[i] = 1/aspectRatio;
		else
			aspectWeights[i] = 0;
		end
	end
	for i, v in pairs(children) do
		local layoutParams = self._ChildProperties[v];
		if layoutParams.AspectRatio ~= 0 then
			local aspectRatio = layoutParams.AspectRatio;
			if self._Direction ~= Gui.Enum.LinearLayoutDirection.Vertical then
				aspectRatio = 1 / aspectRatio;
			end
			linearPixels[i] = --[[linearPixels[i] + ]] orthoSize / aspectRatio;
		end
	end
	orthoPixels[1] = orthoSize;
	self._GridLayoutBacking.Cushion = Vector2.new(self._Cushion, self._Cushion);
	LinearLayoutDebug("Children in order:");
	for i, v in pairs(children) do
		LinearLayoutDebug("    %s = %s", i, v);
	end
end

--[[ @brief Returns the minimum required size for this element.
--]]
function LinearLayout:_GetMinimumSize()
	self:_UpdateGridLayout();
	return self._GridLayoutBacking:_GetMinimumSize();
end

--[[ @brief Places child elements in a line.
     @param pos The position to place this element at.
     @param size The size to make the element.
--]]
function LinearLayout:_Reflow(pos, size)
	Gui.Log.Reflow("LinearLayout:_Reflow(%s, %s, %s) called", self, pos, size);
	self:_UpdateGridLayout();
	self._GridLayoutBacking:_SetPPos(pos);
	self._GridLayoutBacking:_SetPSize(size);
	self._GridLayoutBacking:ForceReflow();
--	self._GridLayoutBacking.Size = self.Size;
--	self._GridLayoutBacking.Position = self.Position;
--	self._GridLayoutBacking:ForceReflow();
end

--[[ @brief Returns the roblox instance which represents this LinearLayout.
--]]
function LinearLayout:_GetHandle()
	return self._GridLayoutBacking:_GetHandle();
end

--[[ @brief Returns the child container for the given child.
     @details This function defers to the object it wraps.
     @param child The child for which we are querying.
     @return The element (Roblox instance) which the child should be placed in.
--]]
function LinearLayout:_GetChildContainer(child)
	return self._GridLayoutBacking:_GetChildContainer(child);
end

function LinearLayout:_RemoveChild(child)
	self._ChildPlacements:RemoveChild(child);
	Super._RemoveChild(self, child);
end

function LinearLayout:_AddChild(child)
	self._ChildPlacements:AddChildTo(child, self._GridLayoutBacking);
	Super._AddChild(self, child);
end

function LinearLayout.new(instance)
	local self = setmetatable(Super.new(), LinearLayout.Meta);
	self._GridLayoutBacking = Gui.new("GridLayout");
	self._GridLayoutBacking.Name = "UnderlyingGridLayout";
	self._ChildProperties = Gui.ChildProperties(LinearLayout._ChildProperties);
	self._ChildPlacements = Gui.ChildPlacements();
	return self;
end

------------------------
-- Test Functions --
------------------------

--[[ @brief Tests to make sure _GetMinimumSize() computes the correct values.
--]]
function Test.LinearLayout_MinimumSize()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_MinimumSize";
	local x = Gui.new("LinearLayout", sgui);
	x.Cushion = 10;
	x.InferSize = true;
	for i = 1, 3 do
		local y = Gui.new("Frame", x);
		y.MinimumX = 20;
		y.MinimumY = 20;
	end
	x.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	Log.AssertEqual("horizontal minimum size", Vector2.new(80, 20), x:_GetMinimumSize());
	x.Margin = 5;
	Log.AssertEqual("horizontal minimum size with margin", Vector2.new(90, 30), x:_GetMinimumSize());
	x.Direction = Gui.Enum.LinearLayoutDirection.Vertical;
	Log.AssertEqual("vertical minimum size with margin", Vector2.new(30, 90), x:_GetMinimumSize());
end
--[[ @brief Tests to make sure objects are given the proper aspect ratio.
--]]
function Test.LinearLayout_AspectRatio()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_AspectRatio";
	local x = Gui.new("LinearLayout", sgui);
	x.Name = "HorizontalLayout";
	x.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	x.Cushion = 0;
	x.InferSize = true;
	for i = 1, 3 do
		local y = Gui.new("Frame", x);
		y.Name = "Frame " .. tostring(i);
		y.MinimumX = 10;
		y.MinimumY = 20;
		y.LayoutParams = {AspectRatio = 1;};
		y.LayoutParams.Weight = i%1;
	end
	wait();
	Log.AssertEqual("horizontal with square elements", Vector2.new(60, 20), x:_GetMinimumSize());
	x.Size = UDim2.new(0, 80, 0, 20);
	wait();
	for i, v in pairs(x:GetChildren()) do
		Log.AssertEqual("frame parent", x._GridLayoutBacking:_GetChildContainer(v), v:_GetHandle().Parent);
		Log.AssertEqual("frame allotted size", UDim2.new(0, 20, 0, 20), v._PlacementSize);
	end
end

function Test.LinearLayout_Shuffle()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_Shuffle";
	local x = Gui.new("LinearLayout", sgui);
	x.Cushion = 10;
	x.Size = UDim2.new(0, 320, 0, 320);
	x.Position = UDim2.new(0.5, -160, .5, -160);
	local elements = {};
	for i = 1, 3 do
		local y = Gui.new("Frame", x);
		y.Name = "Frame_" .. tostring(i);
		y.LayoutParams = {Index = 4 - i};
		elements[i] = y;
	end
	wait();
	Log.Assert(elements[1].AbsolutePosition.y > elements[2].AbsolutePosition.y, "element 1 (index 3) should come after element 2 (index 2).");
	Log.Assert(elements[1].AbsolutePosition.y > elements[3].AbsolutePosition.y, "element 1 (index 3) should come after element 3 (index 1).");
	Log.Assert(elements[2].AbsolutePosition.y > elements[3].AbsolutePosition.y, "element 2 (index 2) should come after element 3 (index 1).");
	x.AlwaysUseFrame = true;
	wait();
	Log.Assert(elements[1].AbsolutePosition.y > elements[2].AbsolutePosition.y, "element 1 (index 3) should come after element 2 (index 2).");
	Log.Assert(elements[1].AbsolutePosition.y > elements[3].AbsolutePosition.y, "element 1 (index 3) should come after element 3 (index 1).");
	Log.Assert(elements[2].AbsolutePosition.y > elements[3].AbsolutePosition.y, "element 2 (index 2) should come after element 3 (index 1).");
end

--[[ @brief Test to make sure that the margin is properly recognized.
--]]
function Test.LinearLayout_Margin()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_Margin";
	local x = Gui.new("LinearLayout", sgui);
--	x.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	x.Margin = 80;
	x.Cushion = 40;
	for i = 1, 3 do
		local y = Gui.new("Frame", x);
	end
end

function Test.LinearLayout_AlwaysUseFrame()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_AlwaysUseFrame";
	local x = Gui.new("LinearLayout", sgui);
	x.AlwaysUseFrame = true;
	x.Cushion = 10;
	x.FillX = false;
	x.FillY = false;
	x.Gravity = Gui.Enum.ViewGravity.Center;
	wait();
	Log.AssertNonNilAndType("x:_GetHandle()", "userdata", x:_GetHandle());
	local children = {};
	for i = 1, 7 do
		local y = Gui.new("Frame", x);
		y.MinimumX = 200;
		y.MinimumY = 40;
		wait(.1);
		Log.AssertEqual("y:_GetHandle().Parent", x:_GetHandle(), y:_GetHandle().Parent);
		children[y] = false;
	end
	for y, _ in pairs(children) do
		children[y] = {y:_GetHandle().AbsoluteSize, y:_GetHandle().AbsolutePosition};
	end
	x.AlwaysUseFrame = false;
	for child, props in pairs(children) do
		Log.AssertEqual("Size", props[1], child.AbsoluteSize);
		Log.AssertEqual("Position", props[2], child.AbsolutePosition);
	end
end

--[[ @brief Test to make sure the aspect ratio feature works correctly when gravity is toward the right/bottom.
--]]
function Test.LinearLayout_Gravity()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_Gravity";
--	sgui.Size = UDim2.new(0.5, 0, 0.2, 0);
--	sgui.Position = UDim2.new(0.25, 0, 0.4, 0);
	sgui.Size = UDim2.new(0, 400, 0, 80);
	sgui.Position = UDim2.new(.5, -200, .5, -40);
	local frame = Gui.new("Frame", sgui);
	frame.BackgroundColor3 = Color3.new(.7, .7, .7);
	local layout = Gui.new("LinearLayout", frame);
	layout.Margin = 10;
	layout.Name = "GravityTest";
	layout.FillX = false;
	layout.Cushion = 5;
	layout.Gravity = Gui.Enum.ViewGravity.CenterRight;
	layout.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	for i = 1, 3 do
		local f = Gui.new("Frame", layout);
		f.BackgroundColor3 = Color3.fromHSV((i-1)/3, 1, 1);
		f.LayoutParams = {Index = i; AspectRatio = 1};
	end
end

--[[ @brief Written in response to glitch where parents get screwed up when added late.
--]]
function Test.LinearLayout_LateParent()
	local sgui = Gui.new("ScreenGui", game.StarterGui);
	sgui.Name = "LinearLayout_LateParent";
	sgui.Size = UDim2.new(0, 400, 0, 80);
	sgui.Position = UDim2.new(.5, -200, .5, -40);
--	local frame = Gui.new("Frame", sgui);
--	frame.BackgroundColor3 = Color3.new(.7, .7, .7);
--	local layout = Gui.new("LinearLayout", frame);
--	layout.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
--	layout.FillY = false;
--	for i = 1, 3 do
--		local f = Gui.new("Frame", layout);
--		f.BackgroundColor3 = Color3.fromHSV((i-1)/3, 1, 1);
--		f.LayoutParams = {Index = i; AspectRatio = 1};
--		f.MinimumY = 20;
--	end

	local top = Gui.new("LinearLayout");
	top.Name = "Top";
--	top.AlwaysUseFrame = true;
	top.Direction = Gui.Enum.LinearLayoutDirection.Vertical;
	local inc = Gui.new("LinearLayout", top);
	inc.Name = "Increment";
--	inc.AlwaysUseFrame = true;
	inc.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	inc.LayoutParams = {
		Size = 20;
		Weight = 0;
	};
	local label = Gui.new("TextLabel");
	label.Text = "Increment:";
	label.Name = "Label";
	label.Parent = inc;
	--We must make sure that the order of children is correct.
	local children = {};
	table.insert(children, label);
	for i = 1, #children - 1 do
		Log.Assert(children[i].AbsolutePosition.x < children[i+1].AbsolutePosition.x, "Child out of order: %s comes after %s", children[i], children[i+1]);
	end
	top.Parent = sgui;
	for i = 0, 2 do
		wait();
		local x = Gui.new("TextLabel");
		x.Name = tostring(i);
		x.Text = tostring(i);
		x.Parent = inc;
		table.insert(children, x);
		wait();
		for i = 1, #children - 1 do
			Log.Assert(children[i].AbsolutePosition.x < children[i+1].AbsolutePosition.x, "Child out of order: %s comes after %s", children[i], children[i+1]);
		end
	end
	--Verify that all children are still represented.
	Log.AssertEqual("number of children", 4, #inc:GetChildren());
	top.Parent = nil;
	wait();
	top.Parent = sgui;
	wait();
	Log.AssertEqual("number of children", 4, #inc:GetChildren());
end

return LinearLayout;