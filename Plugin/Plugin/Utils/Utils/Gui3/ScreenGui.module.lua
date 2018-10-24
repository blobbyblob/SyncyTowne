local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "ScreenGui: ", true);

local Super = Gui.GuiBase2d;
local ScreenGui = Utils.new("Class", "ScreenGui", Super);

ScreenGui._Frame = false;

function ScreenGui.Set:Name(v)
	Super.Set.Name(self, v);
	self._Frame.Name = v;
end

function ScreenGui:_Clone(new)

end

function ScreenGui:_GetRbxHandle()
	return self._Frame;
end

function ScreenGui.new()
	local self = setmetatable(Super.new(), ScreenGui.Meta);
	self._Frame = Instance.new("ScreenGui");
	return self;
end

function Gui.Test.ScreenGui_Basic(sgui)
	local r = ScreenGui.new();
	r.Parent = sgui.Parent;
end

return ScreenGui;
