--[[

An AspectRatioContainer will allow children with a given aspect ratio. It should generally be more efficient than polling to see if an object's parent resized.
It creates a frame layer so polling is not necessary to keep the aspect ratio correct.
It also will handle the concept of 'gravity' for you. How nice!

This is useful when:
 - you only need to maintain an aspect ratio with (optionally) added pixels.
    - this is in contrast to maintaining an aspect ratio alongside normal scaling.
 - you don't have pixel information at your disposal.

Properties:
	Gravity: a Vector2 indicating in which corner of the parent the AspectRatioContainer should fit. A value of 0 indicates the left/top and 1 indicates right/bottom for the x/y axes, respectively.
	Parent: the parent of the AspectRatioContainer.
	DominantAxis: the axis which dictates the size of "1" in the scale. E.g., if Parent.AbsoluteSize = <200, 100> and self.Size = UDim2.new(1, 0, 1, 0), self.DominantAxis = "Width" implies that self.AbsoluteSize = <200, 200>, and "Height" implies that self.AbsoluteSize = <100, 100>.
	CanvasSize (UDim2): the amount of space which children get. UDim2.new(1, 0, 1, 0) will always be a square.
	Scale (UDim): the amount of space along the DominantAxis which this container will take up. UDim.new(1, 0) will run the entire height/width. UDim.new(0, 40) will keep the height/width at a constant 40 pixels.

Methods:
	GetLocation(pos, size): gets the position/size the child should use in order to achieve this location.
		A size of UDim2.new(1, 0, 1, 0) will always be square; use this when trying to maintain certain aspect ratios.
		pos: The position at which we want to place the object with respect to CanvasSize.
		size: The size at which we want to place the object with respect to CanvasSize.
		return: The position at which the instance should be placed within GetHandle()
		return: The size which the instance should be ascribed.
	GetHandle(): returns a frame which represents this AspectRatioContainer.

--]]

local Utils = require(script.Parent.Parent.Parent);

local AspectRatioContainer = Utils.new("Class", "AspectRatioContainer");

AspectRatioContainer._DominantAxis = Enum.DominantAxis.Height;
AspectRatioContainer._Gravity = Vector2.new();
AspectRatioContainer._Frame = false;
AspectRatioContainer._Parent = false;
AspectRatioContainer._CanvasSize = false;
AspectRatioContainer._Scale = UDim.new(1, 0);

function AspectRatioContainer.Set:Gravity(v)
	self._Gravity = v;
	self._Frame.Position = UDim2.new(v.x, 0, v.y, 0);
	self._Frame.AnchorPoint = v;
end
AspectRatioContainer.Get.Gravity = "_Gravity";

function AspectRatioContainer.Set:Parent(v)
	self._Parent = v;
	self._Frame.Parent = v;
end
AspectRatioContainer.Get.Parent = "_Parent";

function AspectRatioContainer.Set:DominantAxis(v)
	self._DominantAxis = v;
	self._Frame.SizeConstraint = (v == Enum.DominantAxis.Height) and Enum.SizeConstraint.RelativeYY or Enum.SizeConstraint.RelativeXX;
end
AspectRatioContainer.Get.DominantAxis = "_DominantAxis";

function AspectRatioContainer.Set:CanvasSize(v)
	self._CanvasSize = v;
	self:_ResizeContainer();
end
AspectRatioContainer.Get.CanvasSize = "_CanvasSize";

function AspectRatioContainer.Set:Scale(v)
	self._Scale = v;
	self:_ResizeContainer();
end
AspectRatioContainer.Get.Scale = "_Scale";

-------------
-- Methods --
-------------

function AspectRatioContainer:GetLocation(pos, size)
	local sz = self._CanvasSize or self._Size;
	local px = pos.X.Scale / sz.X.Scale;
	local py = pos.Y.Scale / sz.Y.Scale;
	local sx = size.X.Scale / sz.X.Scale;
	local sy = size.Y.Scale / sz.Y.Scale;
	return
		UDim2.new(
			px,
			pos.X.Offset - sz.X.Offset * px,
			py,
			pos.Y.Offset - sz.Y.Offset * py
		),
		UDim2.new(
			sx,
			size.X.Offset - sz.X.Offset * sx,
			sy,
			size.Y.Offset - sz.Y.Offset * sy
		);
end

function AspectRatioContainer:GetHandle()
	return self._Frame;
end

function AspectRatioContainer:_ResizeContainer()
	local canvasDomSize, canvasSubSize;
	if self._DominantAxis == Enum.DominantAxis.Width then
		canvasDomSize = self._CanvasSize.X;
		canvasSubSize = self._CanvasSize.Y;
	else
		canvasDomSize = self._CanvasSize.Y;
		canvasSubSize = self._CanvasSize.X;
	end
	local scaleFactor = canvasSubSize.Scale / canvasDomSize.Scale;
	local domSize = self._Scale;
	local subSize = UDim.new(scaleFactor * domSize.Scale, (domSize.Offset - canvasDomSize.Offset) * scaleFactor + canvasSubSize.Offset);
	if self._DominantAxis == Enum.DominantAxis.Width then
		self._Frame.Size = UDim2.new(domSize.Scale, domSize.Offset, subSize.Scale, subSize.Offset);
	else
		self._Frame.Size = UDim2.new(subSize.Scale, subSize.Offset, domSize.Scale, domSize.Offset);
	end
end

function AspectRatioContainer.new()
	local self = setmetatable({}, AspectRatioContainer.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.BackgroundTransparency = .8;
	return self;
end

function Oscillate(arc, sgui)
	local function onHeartbeat(step, timeSinceStarted)
		local x = timeSinceStarted % (math.pi * 2);
		arc.Gravity = Vector2.new((1-math.cos(x))/2, (1-math.cos(x))/2);
	end
	Utils.Animate.ConditionalOnHeartbeat(onHeartbeat, function() return not not sgui.Parent; end, true)
end

function Utils.Gui.Test.AspectRatioContainer_Basic(sgui)
	local g = Instance.new("Frame", sgui);
	g.Size = UDim2.new(0, 400, 0, 100);
	g.Position = UDim2.new(0.5, 0, 0.5, 0);
	g.AnchorPoint = Vector2.new(0.5, 0.5);
	g.BackgroundColor3 = Color3.new(0, 1, 0);

	local arc = AspectRatioContainer.new();
	arc.Parent = g;
	arc.CanvasSize = UDim2.new(2, 30, 1, 20);
	arc.DominantAxis = Enum.DominantAxis.Height;

	local f1 = Instance.new("Frame", arc:GetHandle());
	f1.BackgroundColor3 = Color3.new(1, 0, 0);
	f1.Position, f1.Size = arc:GetLocation(UDim2.new(0, 10, 0, 10), UDim2.new(1, 0, 1, 0));

	local f2 = Instance.new("Frame", arc:GetHandle());
	f2.BackgroundColor3 = Color3.new(1, 1, 0);
	f2.Position, f2.Size = arc:GetLocation(UDim2.new(1, 20, 0, 10), UDim2.new(1, 0, 1, 0));
	
	wait(.5);
	Oscillate(arc, sgui);
end

function Utils.Gui.Test.AspectRatioContainer_Undersized(sgui)
	local g = Instance.new("Frame", sgui);
	g.Size = UDim2.new(0, 400, 0, 100);
	g.Position = UDim2.new(0.5, 0, 0.5, 0);
	g.AnchorPoint = Vector2.new(0.5, 0.5);
	g.BackgroundColor3 = Color3.new(0, 1, 0);

	local arc = AspectRatioContainer.new();
	arc.Parent = g;
	arc.DominantAxis = Enum.DominantAxis.Height;
	arc.CanvasSize = UDim2.new(2, 30, 1, 20)
	arc.Scale = UDim.new(0.5, 20);

	local f1 = Instance.new("Frame", arc:GetHandle());
	f1.BackgroundColor3 = Color3.new(1, 0, 0);
	f1.Position, f1.Size = arc:GetLocation(UDim2.new(0, 10, 0, 10), UDim2.new(1, 0, 1, 0));

	local f2 = Instance.new("Frame", arc:GetHandle());
	f2.BackgroundColor3 = Color3.new(1, 1, 0);
	f2.Position, f2.Size = arc:GetLocation(UDim2.new(1, 20, 0, 10), UDim2.new(1, 0, 1, 0));

	wait(.5);
	Oscillate(arc, sgui);
end

function Utils.Gui.Test.AspectRatioContainer_Vertical(sgui)
	local g = Instance.new("Frame", sgui);
	g.Size = UDim2.new(0, 100, 0, 300);
	g.Position = UDim2.new(0.5, 0, 0.5, 0);
	g.AnchorPoint = Vector2.new(0.5, 0.5);
	g.BackgroundColor3 = Color3.new(0, 1, 0);

	local arc = AspectRatioContainer.new();
	arc.Parent = g;
	arc.DominantAxis = Enum.DominantAxis.Width;
	arc.CanvasSize = UDim2.new(2, 30, 1, 20);
	arc.Scale = UDim.new(1, 0);

	local f1 = Instance.new("Frame", arc:GetHandle());
	f1.BackgroundColor3 = Color3.new(1, 0, 0);
	f1.Position, f1.Size = arc:GetLocation(UDim2.new(0, 10, 0, 10), UDim2.new(1, 0, 1, 0));

	local f2 = Instance.new("Frame", arc:GetHandle());
	f2.BackgroundColor3 = Color3.new(1, 1, 0);
	f2.Position, f2.Size = arc:GetLocation(UDim2.new(1, 20, 0, 10), UDim2.new(1, 0, 1, 0));
	
	wait(.5);
	Oscillate(arc, sgui);
end

return AspectRatioContainer;
