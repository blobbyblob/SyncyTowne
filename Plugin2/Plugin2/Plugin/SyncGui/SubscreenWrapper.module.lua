--[[

Wraps a subpage & displays a title & back button at the top.

Properties:
	Frame (read-only): the frame which can be parented to some hierarchy to make the wrapper & child display.
	SubscreenFrame: the frame which will be wrapped. This will have its size normalized.
	ExitCallback: a callback to invoke when the back button is pressed.
	Title: The title text to use.

Methods:
	Destroy(): cleans up the frame & all related connections.

Events:

Constructors:
	new(): construct with default settings.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "SubscreenWrapper: ", true);

local SUBSCREEN_WRAPPER = script.SubscreenWrapper;

local SubscreenWrapper = Utils.new("Class", "SubscreenWrapper");

SubscreenWrapper._Frame = false;
SubscreenWrapper._SubscreenFrame = false;
SubscreenWrapper._Maid = false;
SubscreenWrapper._ExitCallback = function() Debug("ExitCallback() invoked"); end

SubscreenWrapper.Get.Frame = "_Frame";
SubscreenWrapper.Get.SubscreenFrame = "_SubscreenFrame";
function SubscreenWrapper.Set:SubscreenFrame(v)
	v.Size = UDim2.new(1, 0, 1, -30);
	v.LayoutOrder = 2;
	v.Parent = self._Frame;
end
SubscreenWrapper.Get.ExitCallback = "_ExitCallback";
SubscreenWrapper.Set.ExitCallback = "_ExitCallback";
SubscreenWrapper.Get.Title = function(self) return self._Frame.TopBar.Title.Text; end
function SubscreenWrapper.Set:Title(v)
	self._Frame.TopBar.Title.Text = v;
end

function SubscreenWrapper:Destroy()
	self._Maid:Destroy();
end

function SubscreenWrapper.new()
	local self = setmetatable({}, SubscreenWrapper.Meta);
	self._Frame = SUBSCREEN_WRAPPER:Clone();
	self._Maid = Utils.new("Maid");
	self._Maid.Back = self._Frame.TopBar.Back.MouseButton1Down:Connect(function()
		self._ExitCallback();
	end);
	self._Maid.Frame = self._Frame;
	return self;
end

return SubscreenWrapper;
