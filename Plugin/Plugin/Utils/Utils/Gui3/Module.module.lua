--[[

A set of functions to aid in generic gui operations.

PrepareContainer: Indicates whether a container can support the aspect ratio requirement. Possible return values are "yes", "requires shim", "requires pixel info".

--]]

local Utils = require(script.Parent.Parent);
local module = {};

--[[

The three types of layout requirements are:
1. Simple: this is for laying out elements based on pixel measurements (e.g., this box is 20 pixels wide and 10 pixels from the left), percentage measurements (this box is 90% the height of the parent), or both.
2. Aspect: this is for laying out elements which have an aspect ratio requirement, e.g., this box has a 1:2 aspect ratio (defined on the container's height) and is center justified.
	Note: in order to fit in this category, the aspect ratio requirement must be met by clamping on either the x or y axis, but cannot decide during runtime which is better to clamp on.
3. Full: this is for laying out elements which mix aspect ratio requirements and measurements which are proportional to the element size.

--]]
--module.LayoutRequirement = Utils.new("Enum", "LayoutRequirement", "Simple", "Aspect", "Full");

--[[

An AspectRatioContainer will allow children to maintain a given aspect ratio. It should generally be more efficient
than polling to see if an object's parent resized. It will create a frame layer. It also will handle the concept of
'gravity' for you. How nice!

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
--module.newAspectRatioContainer = require(script.AspectRatioContainer).new;

local Wrapper = require(script.Wrapper);
for _, class in pairs({"TextBox"}) do
	module["Wrapper_"..class] = function()
		local self = Wrapper.new();
		self.Object = Instance.new(class);
		return self;
	end;
end


return module;
