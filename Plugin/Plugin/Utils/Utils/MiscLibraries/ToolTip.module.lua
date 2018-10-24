--[[

A class to show ToolTipText on demand.

--]]

local Utils = require(script.Parent.Parent);

local Debug = Utils.new("Log", "ToolTip: ", false);

local ToolTip = Utils.new("Class", "ToolTip");

ToolTip._Visible = false;
ToolTip._ScreenGui = false;
ToolTip._TextLabel = false;
ToolTip._Cxns = false;
ToolTip._RecomputeSize = false;

function ToolTip.Set:Visible(v)
	Debug("ToolTip.Visible = %s", v);
	self._Visible = v;
	if v then
		self._ScreenGui.Parent = game:GetService("Players").LocalPlayer.PlayerGui;
		self._Cxns.Move = game:GetService("UserInputService").InputChanged:connect(function(inputEvent)
			if inputEvent.UserInputType == Enum.UserInputType.MouseMovement then
				local x, y = inputEvent.Position.x, inputEvent.Position.y;
				self._TextLabel.AnchorPoint = Vector2.new(1, 1);
				if self._RecomputeSize then
					self._TextLabel.Size = UDim2.new(0, self._TextLabel.TextBounds.x + 10, 0, self._TextLabel.TextBounds.y + 10);
					self._RecomputeSize = false;
				end
				self._TextLabel.Position = UDim2.new(0, x - 10, 0, y - 10);
			end
		end);
	else
		self._ScreenGui.Parent = nil;
		self._Cxns:Disconnect("Move");
	end
end
ToolTip.Get.Visible = "_Visible";

function ToolTip.Set:Text(txt)
	self._TextLabel.Text = txt;
	self._RecomputeSize = true;
end

function ToolTip:Format(t)
	for property, value in pairs(t) do
		self._TextLabel[property] = value;
	end
end

function ToolTip:SetActive(text)
	self.Text = text;
	self.Visible = true;
	--This can be done better in the future by keeping a stack of currently active tokens.
	local token = {Disconnect = function(cxn)
		self.Visible = false;
		cxn.connected = false;
	end, connected = true};
	token.disconnect = token.Disconnect;
	return token;
end

function ToolTip.new()
	local self = setmetatable({}, ToolTip.Meta);
	self._ScreenGui = Instance.new("ScreenGui");
	self._ScreenGui.Name = "ToolTip";
	self._TextLabel = Instance.new("TextLabel");
	self._TextLabel.Parent = self._ScreenGui;
	self._Cxns = Utils.new("ConnectionHolder");
	return self;
end

return ToolTip.new();
