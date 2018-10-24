local Utils = require(script.Parent);
local Mouse = setmetatable({}, {});

if _G.MouseTeardown then
	_G.MouseTeardown();
end

--TODO: try to find a way to get this in studio as well.
if game:GetService("Players").LocalPlayer then
	local realMouse = game.Players.LocalPlayer:GetMouse();
	getmetatable(Mouse).__index = function(self, i)
		return realMouse[i];
	end
end

local gui = Instance.new("ScreenGui");
gui.DisplayOrder = 10;
local image = Instance.new("ImageLabel");
image.BackgroundTransparency = 1;
image.Size = UDim2.new(0, 32, 0, 32);
image.Parent = gui;
image.AnchorPoint = Vector2.new(.5, .5);

function Mouse.SetGuiIcon(params)
	local enable = true;
	if params.Enabled ~= nil then
		enable = params.Enabled;
	end
	if enable then
		if game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("PlayerGui") then
			gui.Parent = game.Players.LocalPlayer.PlayerGui;
		else
			gui.Parent = game.CoreGui;
		end
	else
		gui.Parent = nil;
	end
	game:GetService("UserInputService").MouseIconEnabled = not enable;
	if params[1] then
		image.Image = params[1];
	end
	if params.Rotation then
		image.Rotation = params.Rotation;
	end
	game:GetService("UserInputService").InputChanged:connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local p = input.Position;
			image.Position = UDim2.new(0, p.x, 0, p.y);
		end
	end)
end

--[[ @brief Returns the object, position, and normal at the mouse location.
--]]
function Mouse.GetTarget()
	local r = Ray.new(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000);
	local ignore = {};
	local obj, pos, normal = workspace:FindPartOnRayWithIgnoreList(r, ignore);
	return obj, pos, normal;
end

function Mouse.Teardown()
	gui.Parent = nil;
	game:GetService("UserInputService").MouseIconEnabled = true;
	_G.MouseTeardown = nil;
end
_G.MouseTeardown = Mouse.Teardown;

return Mouse;
