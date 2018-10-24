local Utils = require(script.Parent);
local CFrame2D = Utils.new("Class", "CFrame2D");

local SNAP_THRESHOLD = 1e-10;

CFrame2D._x = 0;
CFrame2D._y = 0;
CFrame2D._r00 = 1;
CFrame2D._r01 = 0;
CFrame2D._r10 = 0;
CFrame2D._r11 = 1;

function CFrame2D:inverse()
	local det = self._r00 * self._r11 - self._r01 * self._r10;
	local r00 = self._r11 * det;
	local r01 = -self._r01 * det;
	local r10 = -self._r10 * det;
	local r11 = self._r00 * det;
	local x = r00 * -self._x + r01 * -self._y;
	local y = r10 * -self._x + r11 * -self._y;
	if math.abs(x) < SNAP_THRESHOLD then x = 0; end
	if math.abs(y) < SNAP_THRESHOLD then y = 0; end
	if math.abs(r00) < SNAP_THRESHOLD then r00 = 0; end
	if math.abs(r01) < SNAP_THRESHOLD then r01 = 0; end
	if math.abs(r10) < SNAP_THRESHOLD then r10 = 0; end
	if math.abs(r11) < SNAP_THRESHOLD then r11 = 0; end
	return CFrame2D.new(x, y, r00, r01, r10, r11);
end

function CFrame2D:__mul(right)
	local x = self._x + self._r00 * right._x + self._r01 * right._y;
	local y = self._y + self._r10 * right._x + self._r11 * right._y;
	local r00 = self._r00 * right._r00 + self._r01 * right._r10;
	local r01 = self._r00 * right._r01 + self._r01 * right._r11;
	local r10 = self._r10 * right._r00 + self._r11 * right._r10;
	local r11 = self._r10 * right._r01 + self._r11 * right._r11;
	if math.abs(x) < SNAP_THRESHOLD then x = 0; end
	if math.abs(y) < SNAP_THRESHOLD then y = 0; end
	if math.abs(r00) < SNAP_THRESHOLD then r00 = 0; end
	if math.abs(r01) < SNAP_THRESHOLD then r01 = 0; end
	if math.abs(r10) < SNAP_THRESHOLD then r10 = 0; end
	if math.abs(r11) < SNAP_THRESHOLD then r11 = 0; end
	return CFrame2D.new(x, y, r00, r01, r10, r11);
end

function CFrame2D:__tostring()
	return tostring(self._x) .. ", " .. tostring(self._y) .. ", " .. tostring(self._r00) .. ", " .. tostring(self._r01) .. ", " .. tostring(self._r10) .. ", " .. tostring(self._r11);
end

function CFrame2D.new(...)
	local args = {...};
	if #args == 0 then
		return setmetatable({}, CFrame2D.Meta);
	elseif #args == 1 then
		return setmetatable({
			_r00 = math.cos(args[1]),
			_r01 = -math.sin(args[1]),
			_r10 = math.sin(args[1]),
			_r11 = math.cos(args[1])}, CFrame2D.Meta);
	elseif #args == 2 then
		return setmetatable({_x = args[1], _y = args[2]}, CFrame2D.Meta);
	elseif #args == 6 then
		return setmetatable({_x = args[1], _y = args[2], _r00 = args[3], _r01 = args[4], _r10 = args[5], _r11 = args[6]}, CFrame2D.Meta);
	end
end

function CFrame2D.Angle(n)
	return CFrame2D.new(0, 0, math.cos(n), -math.sin(n), math.sin(n), math.cos(n));
end

function CFrame2D:ApplyToGui(obj)
	obj.Position = UDim2.new(self._x, 0, 1 - self._y, 0);
	obj.Rotation = -math.deg(math.atan2(self._r10, self._r00));
	obj.AnchorPoint = Vector2.new(0.5, 0.5);
end

function CFrame2D.Test()
	local Debug = Utils.new("Log", "Test: ", true);
	Debug("Testing Multiplication Operator");
	local cf1 = CFrame2D.new(5, 5);
	local cf2 = CFrame2D.Angle(math.rad(45));
	local cf3 = cf1 * cf2;
	Debug("{%s} * \n{%s} = \n{%s}", cf1, cf2, cf3);
	local cf4 = CFrame2D.new(math.sqrt(2) * 5, 0);
	local cf5 = cf3 * cf4;
	Debug("{%s} * \n{%s} = \n{%s}", cf3, cf4, cf5);
	local cf6 = cf5 * cf2;
	Debug("{%s} * \n{%s} = \n{%s}", cf5, cf2, cf6);
	Debug(".\n..\n...");
	Debug("Testing Inverse");
	Debug("...\n..\n.");
	local cf7 = cf1:inverse();
	local cf8 = cf1 * cf7;
	local cf9 = cf7 * cf1;
	Debug("{%s} * \n{%s} = \n{%s}", cf1, cf7, cf8);
	Debug("{%s} * \n{%s} = \n{%s}", cf7, cf1, cf9);
	local cf10 = cf3:inverse();
	local cf11 = cf10 * cf3;
	local cf12 = cf3 * cf10;
	Debug("{%s} * \n{%s} = \n{%s}", cf10, cf3, cf11);
	Debug("{%s} * \n{%s} = \n{%s}", cf3, cf10, cf12);
end

return CFrame2D;
