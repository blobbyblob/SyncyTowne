--[[

An object which stores the notion of a margin.

Constructors
	new(left, right, top, bottom): constructs a margin which has the provided pixel offsets on the left, right, top, and bottom sides.
	new(margin): constructs a margin which has the same pixel offset on all sides.
Methods
	tuple<UDim2 Position, UDim2 Size> ApplyMargin(UDim2 Position, UDim2 Size): applies this margin to the provided Position and Size UDim2 values.
Members
	Left (read-only): the number of pixels of margin on the left.
	Right (read-only): the number of pixels of margin on the right.
	Top (read-only): the number of pixels of margin on the top.
	Bottom (read-only): the number of pixels of margin on the bottom.

--]]

local lib = script.Parent;
local Class = require(lib.Class);
local Log = require(lib.Log);

local Debug = Log.new("Benchmark:\t", true);

local Margin = Class.new("Margin");

Margin._Left = 0;
Margin._Right = 0;
Margin._Top = 0;
Margin._Bottom = 0;

Margin.Get.Left = "_Left";
Margin.Get.Right = "_Right";
Margin.Get.Top = "_Top";
Margin.Get.Bottom = "_Bottom";

function Margin:ApplyMargin(pos, size)
	return pos + UDim2.new(0, self._Left, 0, self._Top), size - UDim2.new(0, self._Left + self._Right, 0, self._Top + self._Bottom);
end

function Margin:__tostring()
	if self._Left == self._Right and self._Left == self._Top and self._Left == self._Bottom then
		return string.format("Margin: %d", self._Left);
	else
		return string.format("Margin: left %d, right %d, top %d, bottom %d", self._Left, self._Right, self._Top, self._Bottom);
	end
end

function Margin.new(...)
	local args = {...};
	if #args == 4 then
		Log.AssertNonNilAndType("Left", "number", args[1]);
		Log.AssertNonNilAndType("Right", "number", args[2]);
		Log.AssertNonNilAndType("Top", "number", args[3]);
		Log.AssertNonNilAndType("Bottom", "number", args[4]);
		local self = setmetatable({}, Margin.Meta);
		self._Left = args[1];
		self._Right = args[2];
		self._Top = args[3];
		self._Bottom = args[4];
		return self;
	elseif #args == 1 then
		Log.AssertNonNilAndType("Margin", "number", args[1]);
		return Margin.new(args[1], args[1], args[1], args[1]);
	elseif #args == 0 then
		return Margin.new(0, 0, 0, 0);
	else
		Log.AssertEqual("Number of Args", "0, 1, or 4", #args);
	end
end

function Margin.Test()
	local Debug = Log.new("Margin:\t", true);
	Debug("Margin.new(): %s", Margin.new());
	Debug("Margin.new(5): %s", Margin.new(5));
	Debug("Margin.new(1, 2, 3, 4): %s", Margin.new(1, 2, 3, 4));
	Debug("Margin.new(5):ApplyMargin(UDim2.new(1, 20, 2, 40), UDim2.new(.5, 10, 1, 20)): [%s], [%s]", Margin.new(5):ApplyMargin(UDim2.new(1, 20, 2, 40), UDim2.new(.5, 10, 1, 20)));
end

return Margin;

