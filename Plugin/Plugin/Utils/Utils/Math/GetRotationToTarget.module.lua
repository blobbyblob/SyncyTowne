local Utils = require(script.Parent.Parent);
local Debug = Utils.new("Log", "GetRotationToTarget: ", false);

--[[ @brief Function which gets the necessary rotation to point a ray at a target
         when it pivots around a ray.
     @details If the target point doesn't lie directly on the plane formed by the
         ray (when used as a surface normal), this problem is technically
         unsolvable -- however, this script strives to get the "best guess".
     @param hinge The CFrame of a hinge we rotate around. The x axis is the rotational axis.
     @param barrel The CFrame of an object which we want to point at the target. The axis we point on is the x axis.
     @param target The Vector3 of the target we wish to point at.
--]]
function GetRotationToTarget(hinge, barrel, target)
	Debug("<%s>\t<%s>\t<%s>", hinge, barrel, target);
	--The space we do this problem in should be located at the hinge and have the following features:
	--1. The x axis points along the barrel of the gun.
	--2. The z axis points along the rotational axis.
--	Debug("Barrel: <%s>; Hinge: <%s>", barrel.rightVector, hinge.rightVector);
	local p = hinge.p;
	local b = hinge.rightVector;
	local u = b:Cross(barrel.rightVector).unit;
	local r = u:Cross(b);
	local problemSpace = CFrame.new(p.x, p.y, p.z, r.x, u.x, b.x, r.y, u.y, b.y, r.z, u.z, b.z);
--	Debug("Problem Space: <%s>", problemSpace);

	local targetOffset = problemSpace:pointToObjectSpace(target) * Vector3.new(1, 1, 0);
	local tLen = targetOffset.magnitude;
--	Debug("Target Offset: <%s> (length %s, original <%s>, rederived: <%s>)", targetOffset, tLen, target, (problemSpace * CFrame.new(targetOffset)).p);

	local barrelOffset = problemSpace:toObjectSpace(barrel);
	barrelOffset = barrelOffset - Vector3.new(0, 0, barrelOffset.z);
	local y = barrelOffset.p.y;
	local x = math.sqrt(tLen * tLen - y * y);
--	Debug("Barrel Offset: <%s>", barrelOffset);

--	Debug("Equation Variables:\n\tx = %s\n\tt_x = %s\n\ty = %s\n\tt_y = %s\n\t||t|| = %s", x, targetOffset.x, y, targetOffset.y, tLen);
	local angle = math.atan2(x * targetOffset.y - y * targetOffset.x, x * targetOffset.x + y * targetOffset.y);
--	Debug("Result: %.1f", math.deg(angle));
	return angle;
end

function Test()
	Debug("Starting Test");
	local hinge = CFrame.new(1, 1, 1);
	local barrel = CFrame.new(1, 1, 1, 0, 0, -1, 0, 1, 0, 1, 0, 0);
	local target1 = Vector3.new(1, 0, 2);
	local target2 = Vector3.new(1, 2, 2);
--	Debug("Angles: %s, %s", math.deg(GetRotationToTarget(hinge, barrel, target1)), math.deg(GetRotationToTarget(hinge, barrel, target2)));
	Utils.Log.AssertAlmostEqual("target1 angle", math.rad(45), math.rad(1), GetRotationToTarget(hinge, barrel, target1));
	Utils.Log.AssertAlmostEqual("target2 angle", math.rad(-45), math.rad(1), GetRotationToTarget(hinge, barrel, target2));

	local barrel2 = CFrame.new(0, 2, 2, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	Utils.Log.AssertAlmostEqual("target1 angle", math.rad(0), math.rad(1), GetRotationToTarget(hinge, barrel2, Vector3.new(-1, 2, 3)));
	Utils.Log.AssertAlmostEqual("target2 angle", math.rad(90), math.rad(1), GetRotationToTarget(hinge, barrel2, Vector3.new(4, -1, 2)));
end

return setmetatable(
	{Test=Test, call = GetRotationToTarget},
	{__call = function(self, ...) GetRotationToTarget(...); end}
);
