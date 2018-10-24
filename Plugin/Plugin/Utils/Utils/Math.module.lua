local Utils = require(script.Parent);
local Debug = Utils.new("Log", "Math: ", true);

local module = {}

function module.HexColor(n)
	Utils.Log.AssertNonNilAndType("Parameter 1", "number", n);
	Utils.Log.Assert(0 <= n and n <= 16777215, "Parameter 1 for FromHex must be in range [0, 16777215]");
	local b = n % 256;
	n = math.floor(n / 256);
	local g = n % 256;
	n = math.floor(n / 256);
	local r = n;
	return Color3.fromRGB(r, g, b);
end

function module.Round(n, m)
	m = m or 1;
	return math.floor(n/m + 0.5)*m;
end

function module.Clamp(n, low, high)
	if n < low then
		return low;
	elseif n > high then
		return high;
	else
		return n;
	end
end

function module.AlmostEqual(n, m, threshold)
	return math.abs(n - m) < threshold;
end

--[[ @brief Gets a CFrame given two lookVectors which describe it.
     @param upVector A vector facing upwards.
     @param backVector A vector facing backwards which should describe the output CFrame. This need not be orthogonal to upVector.
     @return A CFrame for which cf.upVector = upVector and cf.backVector is approximately backVector.
--]]
function module.GetOrientationYZ(upVector, backVector, pt)
	pt = pt or Vector3.new();
	local topVector = upVector.unit;
	local rightVector = topVector:Cross(backVector).unit;
	local backVector = rightVector:Cross(topVector);
	return CFrame.new(pt.x, pt.y, pt.z, rightVector.x, topVector.x, backVector.x,rightVector.y, topVector.y, backVector.y, rightVector.z, topVector.z, backVector.z),
		rightVector, topVector, backVector;
end

function module.GetOrientationYX(upVector, rightVector, pt)
	pt = pt or Vector3.new();
	local topVector = upVector.unit;
	local backVector = rightVector:Cross(upVector);
	local rightVector = topVector:Cross(backVector);
	return CFrame.new(pt.x, pt.y, pt.z, rightVector.x, topVector.x, backVector.x,rightVector.y, topVector.y, backVector.y, rightVector.z, topVector.z, backVector.z),
		rightVector, topVector, backVector;
end

--@brief Creates a CFrame so the rightVector is exactly set and the upVector is approximately set.
function module.GetOrientationXY(rightVector, upVector, pt)
	pt = pt or Vector3.new();
	rightVector = rightVector.unit;
	local backVector = rightVector:Cross(upVector).unit;
	upVector = backVector:Cross(rightVector);
	return CFrame.new(pt.x, pt.y, pt.z, rightVector.x, upVector.x, backVector.x,rightVector.y, upVector.y, backVector.y, rightVector.z, upVector.z, backVector.z),
		rightVector, upVector, backVector;
end

--[[ @brief Converts a vector to one which is orthogonal to normal.
     @param vector The vector to convert.
     @param normal The vector to be orthogonal to.
     @param A vector approximately in the same direction (with same length) as vector, but orthogonal to normal.
--]]
function module.SnapVectorOrthoToRay(vector, normal)
	local mag = vector.magnitude;
	local dir = normal:Cross(vector):Cross(normal);
	if dir.magnitude ~= 0 then
		dir = dir.unit * mag;
	end
	return dir;
end

--[[ @brief Gets the center of mass of a collection of parts.
     @param parts The parts to compute the center of mass of.
     @param referencePoint A CFrame which should be considered the origin during the computation.
     @return A Vector3 value indicating the center of mass in the provided reference frame.
--]]
function module.GetCenterOfMass(parts, referencePoint)
	referencePoint = referencePoint or CFrame.new();
	local sum = Vector3.new();
	local totalMass = 0;
	for i, part in pairs(parts) do
		local partCOM = part.Position;
		local partMass = part:GetMass();
		if part:IsA("WedgePart") then
			partCOM = (part.CFrame * CFrame.new(part.Size/6*Vector3.new(0, -1, 1))).p;
		end
--		Debug("Part %s has relative center of mass <%s>, mass %.1f", part.Name, referencePoint:pointToObjectSpace(partCOM), partMass);
		sum = sum + referencePoint:pointToObjectSpace(partCOM) * partMass;
		totalMass = totalMass + partMass;
	end
	return sum, totalMass;
end

--[[ @brief Gets the total mass of the given part & all parts attached to it.
     @param root The part we are computing the mass of.
     @return The sum of root's mass & all connected parts' masses.
--]]
function module.GetTotalConnectedMass(root)
	local sum = 0;
	for i, v in pairs(root:GetConnectedParts(true)) do
		sum = sum + v:GetMass();
	end
	return sum;
end

--[[ @brief Converts a CFrame's rotation matrix into a quaternion.
     @param cf The CFrame to convert.
     @return A tuple containing the qx, qy, qz, qw components of a quaternion.
--]]
function module.QuaternionFromCFrame(cf)
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cf:components();
	local tr = m00 + m11 + m22
	local qw, qx, qy, qz;
	
	if tr > 0 then
	  local S = math.sqrt(tr+1.0) * 2; -- S=4*qw 
	  qw = 0.25 * S;
	  qx = (m21 - m12) / S;
	  qy = (m02 - m20) / S; 
	  qz = (m10 - m01) / S; 
	elseif m00 > m11 and m00 > m22 then 
	  local S = math.sqrt(1.0 + m00 - m11 - m22) * 2; -- S=4*qx 
	  qw = (m21 - m12) / S;
	  qx = 0.25 * S;
	  qy = (m01 + m10) / S; 
	  qz = (m02 + m20) / S; 
	elseif m11 > m22 then 
	  local S = math.sqrt(1.0 + m11 - m00 - m22) * 2; -- S=4*qy
	  qw = (m02 - m20) / S;
	  qx = (m01 + m10) / S; 
	  qy = 0.25 * S;
	  qz = (m12 + m21) / S; 
	else 
	  local S = math.sqrt(1.0 + m22 - m00 - m11) * 2; -- S=4*qz
	  qw = (m10 - m01) / S;
	  qx = (m02 + m20) / S;
	  qy = (m12 + m21) / S;
	  qz = 0.25 * S;
	end
	return qx, qy, qz, qw;
end

--[[ @brief Interpolates between two quaternions.
     @param qa The first quaternion. This should be an array of the form: {qx, qy, qz, qw}
     @param qb The second quaternion. This should be of the same form as qa.
     @param t The interpolation value. 0 means the return value is qa, 1 means the return
         value is qb, and everything in-between will be spherically interpolated.
     @return a tuple (not an array) contaning qx, qy, qz, qw.
--]]
function module.Slerp(qa, qb, t)
	--Calculate angle between them.
	local cosHalfTheta = qa[1] * qb[1]
	                   + qa[2] * qb[2]
	                   + qa[3] * qb[3]
	                   + qa[4] * qb[4];

	--If the dot product is negative, the quaternions
	--have opposite handed-ness and slerp won't take
	--the shorter path. Fix by reversing one quaternion.
	if (cosHalfTheta < 0.0) then
		qa[1], qa[2], qa[3], qa[4] = -qa[1], -qa[2], -qa[3], -qa[4];
		cosHalfTheta = -cosHalfTheta;
	end


	--if qa=qb or qa=-qb then theta = 0 and we can return qa
	if (math.abs(cosHalfTheta) >= 1.0)then
		return unpack(qa);
	end

	--Calculate temporary values.
	local halfTheta = math.acos(cosHalfTheta);
	local sinHalfTheta = math.sqrt(1.0 - cosHalfTheta*cosHalfTheta);
	--if theta = 180 degrees, then rotate around the preferred axis.
	if (math.abs(sinHalfTheta) < 0.001) then
		return
			qa[1] * 0.5 + qb[1] * 0.5,
			qa[2] * 0.5 + qb[2] * 0.5,
			qa[3] * 0.5 + qb[3] * 0.5,
			qa[4] * 0.5 + qb[4] * 0.5;
	end
	local ratioA = math.sin((1 - t) * halfTheta) / sinHalfTheta;
	local ratioB = math.sin(t * halfTheta) / sinHalfTheta;
	
	--calculate Quaternion.
	local qx = (qa[1] * ratioA + qb[1] * ratioB);
	local qy = (qa[2] * ratioA + qb[2] * ratioB);
	local qz = (qa[3] * ratioA + qb[3] * ratioB);
	local qw = (qa[4] * ratioA + qb[4] * ratioB);

	return qx, qy, qz, qw;
end

function module.CFrameFromComponents(pos, right, up, back)
	return CFrame.new(pos.x, pos.y, pos.z, right.x, up.x, back.x, right.y, up.y, back.y, right.z, up.z, back.z);
end

function module.RemapRange(value, fromLow, fromHigh, toLow, toHigh, extrapolate)
	local x = (value - fromLow) / (fromHigh - fromLow);
	x = math.clamp(x, 0, 1);
	return toLow * (1 - x) + toHigh * x;
end

--[[ @brief Returns the (smallest) vector part1 would have to be moved to no longer be touching part2.
     @details The only valid shapes for part1 and part2 are rectangular prisms, wedges, and spheres.
--]]
function module.GetSeparatingAxis(part1, part2)
	local function GetAxes(part)
		local axisList = {};
		local lower = {};
		local upper = {};
		if part:IsA("WedgePart") then
			Debug("WedgePart not implemented");
		elseif part:IsA("CornerWedgePart") then
			Debug("CornerWedgePart not implemented");
		else
			local cf = part.CFrame;
			axisList = {cf.rightVector, cf.upVector, cf.lookVector};
			lower = {
				cf.p:Dot(cf.rightVector) - part.Size.x*.5,
				cf.p:Dot(cf.upVector)    - part.Size.y*.5,
				cf.p:Dot(cf.lookVector)  - part.Size.z*.5,
			};
			upper = {
				lower[1] + part.Size.x,
				lower[2] + part.Size.y,
				lower[3] + part.Size.z,
			};
		end
		return axisList, lower, upper;
	end
	local function GetAxisRange(part, axes)
		if part:IsA("WedgePart") then
			Debug("WedgePart not implemented");
		elseif part:IsA("CornerWedgePart") then
			Debug("CornerWedgePart not implemented");
		end
		local lower = {};
		local upper = {};
		local cf = part.CFrame;
		local r, u, f = cf.rightVector, cf.upVector, cf.lookVector;
		for i = 1, #axes do
			local axis = axes[i];
			local dr, du, df = r:Dot(axis), u:Dot(axis), f:Dot(axis);
			local p = cf.p:Dot(axis);
			local offset = math.abs(dr) * part.Size.x*.5 + math.abs(du) * part.Size.y*.5 + math.abs(df) * part.Size.z*.5;
			lower[i] = p - offset;
			upper[i] = p + offset;
		end
		return lower, upper;
	end
	local Part1IsBall = part1:IsA("BasePart") and part1.Shape == Enum.PartType.Ball;
	local Part2IsBall = part2:IsA("BasePart") and part2.Shape == Enum.PartType.Ball;
	if Part1IsBall and Part2IsBall then
		Debug("Ball collisions not implemented");
		return Vector3.new();
	elseif Part1IsBall then
		Debug("Ball collisions not implemented");
		return Vector3.new();
	elseif Part2IsBall then
		Debug("Ball collisions not implemented");
		return Vector3.new();
	else
		local axes1, lower11, upper11 = GetAxes(part1);
		local lower12, upper12 = GetAxisRange(part2, axes1);
		local axes2, lower22, upper22 = GetAxes(part1);
		local lower21, upper21 = GetAxisRange(part1, axes2);
		--Pick the axis with the least overlap.
		local overlap = math.huge;
		local offset;
		for i = 1, #axes1 do
			local o = upper11[i] - lower12[i];
			if o < overlap then
				if o < 0 then
					return Vector3.new();
				end
				overlap = o;
				offset = axes1[i] * -o;
			end
			o = upper12[i] - lower11[i];
			if o < overlap then
				if o < 0 then
					return Vector3.new();
				end
				overlap = o;
				offset = axes1[i] * o;
			end
		end
		for i = 1, #axes2 do
			local o = upper21[i] - lower22[i];
			if o < overlap then
				if o < 0 then
					return Vector3.new();
				end
				overlap = o;
				offset = axes2[i] * -o;
			end
			o = upper22[i] - lower21[i];
			if o < overlap then
				if o < 0 then
					return Vector3.new();
				end
				overlap = o;
				offset = axes2[i] * o;
			end
		end
		return offset;
	end
end

module.GunRaycast = require(script.GunRaycast);
module.Voxel = require(script.Voxel);

module.VoxelSpaceConverter = module.Voxel.VoxelSpaceConverter.new;
module.VoxelOccupancy = module.Voxel.VoxelOccupancy.new;
module.QuadraticEase = require(script.QuadraticEase);
module.QuadraticEaseSetTime = require(script.QuadraticEaseSetTime);
module.GetRotationToTarget = require(script.GetRotationToTarget).call;
module.GetVelocityAtPoint = require(script.GetVelocityAtPoint);
module.CFrameGroupRelative = require(script.CFrameGroupRelative);

function module.Test()
	local cf1 = CFrame.Angles(math.random(), math.random(), math.random());
	local cf2 = CFrame.new(0, 0, 0, module.QuaternionFromCFrame(cf1));
	local part = Instance.new("Part");
	part.CFrame = CFrame.new(0, 20, 0);
	part.Size = Vector3.new(8, 4, 16);
	part.Parent = workspace;
	local origin = part.CFrame * CFrame.Angles(math.random(), math.random(), math.random());
	local target = part.CFrame * CFrame.Angles(math.random(), math.random(), math.random());
	local oQuat = {module.QuaternionFromCFrame(origin)};
	local tQuat = {module.QuaternionFromCFrame(target)};
	for i = 1, 4 do
		if i == 1 then
			part.CFrame = origin;
		elseif i == 2 then
			part.CFrame = target;
		elseif i == 3 then
			part.CFrame = CFrame.new(origin.x, origin.y, origin.z, unpack(oQuat));
		else
			part.CFrame = CFrame.new(target.x, target.y, target.z, unpack(tQuat));
		end
		wait(1);
	end
	while part.Parent do
		for _, v in pairs({origin, target}) do
			part.CFrame = v;
			wait(.5);
		end
		for i = 0, 1, .01 do
			wait();
			local p = origin.p * i + target.p * (1 - i);
			part.CFrame = CFrame.new(p.x, p.y, p.z, module.Slerp(oQuat, tQuat, i));
		end
	end
end

function module.Test()
	Utils.Log.AssertEqual("RemapRange(.1, 0, .2, 2, 4)", module.RemapRange(.1, 0, .2, 2, 4), 3);
end

return module
