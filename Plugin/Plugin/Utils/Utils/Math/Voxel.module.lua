--[[

Logic related to voxels.


VoxelSpaceConverter: helps convert to/from voxel space.
Properties:
	CellSize: the number of studs per cell.
	Offset: the offset in studs from <0, 0, 0>.
Methods:
	GetCellAtRay(ray): returns the cell at a ray's position & the next adjacent cell. If the ray falls at the border, the first returned cell will be the one pointed by -Direction, and the second will be pointed by Direction.
	GetCellAtPoint(point): returns the cell at a given point. If the point falls near a border, it's up to rounding to decide which cell is active.
	CellToWorldSpace(cell): returns the center position of a cell in world space.
	CellToWorldRange(cell): returns the lower and upper bounds of a cell in world space.


VoxelOccupancy: can store whether or not a cell or cells are occupied.
Methods:
	SetCellOccupied(cell, occupancyValue): sets a cell to be occupied. occupancyValue may take any value.
	IsCellOccupied(cell): returns the occupancy value for a given cell, or nil if none exists.
	Flood(seedCell, condition): performs a flood fill starting from a seed cell and adhering to a condition. The seed cell will not be checked against the condition.

--------------------------------------------------------------------------------------
-- Consider the remainder of this comment block a pointless stream of consciousness --
--------------------------------------------------------------------------------------

A solution would be useful for voxel systems. It could be an iterative approach to optimizing the voxel case:
1. Only load chunks near the player.
2. Memoize the "boundary" voxels between air and solids so each chunk doesn't require an n^3 search to find these voxels. We assume most chunks will have a smal fraction of boundary voxels vs. other voxels.
3. Associate boundary voxels with the air blob that they touch and be able to associate air blobs to neighboring air blobs. Thus, a solid which only touches air that the user could not possibly see does not need to be rendered.

--]]

local Utils = require(script.Parent.Parent);
local Voxel = {};

--[[
VoxelSpaceConverter: helps convert to/from voxel space.
Properties:
	CellSize: the number of studs per cell.
	Offset: the offset in studs from <0, 0, 0>.
Methods:
	GetCellAtRay(ray): returns the cell at a ray's position & the next adjacent cell. If the ray falls at the border, the first returned cell will be the one pointed by -Direction, and the second will be pointed by Direction.
	GetCellAtPoint(point): returns the cell at a given point. If the point falls near a border, it's up to rounding to decide which cell is active.
	CellToWorldSpace(cell): returns the center position of a cell in world space.
	CellToWorldRange(cell): returns the lower and upper bounds of a cell in world space.
--]]

local VoxelSpaceConverter = Utils.new("Class", "VoxelSpaceConverter");

VoxelSpaceConverter.CellSize = 4;
VoxelSpaceConverter.Offset = Vector3.new();

function VoxelSpaceConverter:GetCellAtRay(ray)
	local origin = (ray.Origin - self.Offset) / self.CellSize;
	--These three variables represent the distance to the edge.
	local dx = math.abs((origin.x + .5) % 1 - .5);
	local dy = math.abs((origin.y + .5) % 1 - .5);
	local dz = math.abs((origin.z + .5) % 1 - .5);
	--These three variables represent the cell that ray.Origin is located in.
	local rx = math.floor(origin.x);
	local ry = math.floor(origin.y);
	local rz = math.floor(origin.z);
	--First three conditions cover selecting a face.
	--The first returned value should be the cell from which the ray originates and
	--the second should be in the direction the ray faces.
	if dx < .01 then
		if ray.Direction.x < 0 then
			return Vector3.new(math.floor(origin.x + .5), ry, rz), Vector3.new(math.floor(origin.x - .5), ry, rz);
		else
			return Vector3.new(math.floor(origin.x - .5), ry, rz), Vector3.new(math.floor(origin.x + .5), ry, rz);
		end
	elseif dy < .01 then
		if ray.Direction.y < 0 then
			return Vector3.new(rx, math.floor(origin.y + .5), rz), Vector3.new(rx, math.floor(origin.y - .5), rz);
		else
			return Vector3.new(rx, math.floor(origin.y - .5), rz), Vector3.new(rx, math.floor(origin.y + .5), rz);
		end
	elseif dz < .01 then
		if ray.Direction.z < 0 then
			return Vector3.new(rx, ry, math.floor(origin.z + .5)), Vector3.new(rx, ry, math.floor(origin.z - .5));
		else
			return Vector3.new(rx, ry, math.floor(origin.z - .5)), Vector3.new(rx, ry, math.floor(origin.z + .5));
		end
	else
		--We selected inside a cell.
		--The first returned result should be the cell itself.
		--The second should be the first cell which is pointed to by the ray.
		local qx = ray.Direction.x == 0 and math.huge or ((ray.Direction.x > 0 and math.ceil or math.floor)(origin.x) - origin.x) / ray.Direction.x;
		local qy = ray.Direction.y == 0 and math.huge or ((ray.Direction.y > 0 and math.ceil or math.floor)(origin.y) - origin.y) / ray.Direction.y;
		local qz = ray.Direction.z == 0 and math.huge or ((ray.Direction.z > 0 and math.ceil or math.floor)(origin.z) - origin.z) / ray.Direction.z;
		if qx < qy and qx < qz then
			return Vector3.new(rx, ry, rz), Vector3.new(rx + math.sign(ray.Direction.x), ry, rz);
		elseif qy < qz then
			return Vector3.new(rx, ry, rz), Vector3.new(rx, ry + math.sign(ray.Direction.y), rz);
		else
			return Vector3.new(rx, ry, rz), Vector3.new(rx, ry, rz + math.sign(ray.Direction.z));
		end
	end
end

function VoxelSpaceConverter:GetCellAtPoint(point)
	local pos = (point - self.Offset) / self.CellSize;
	return Vector3.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z));
end

function VoxelSpaceConverter:CellToWorldSpace(cell)
	return (cell + Vector3.new(.5, .5, .5)) * self.CellSize + self.Offset;
end

function VoxelSpaceConverter:CellToWorldRange(cell)
	local low = cell * self.CellSize + self.Offset;
	return low, low + Vector3.new(1, 1, 1) * self.CellSize;
end

function VoxelSpaceConverter.new()
	local self = setmetatable({}, VoxelSpaceConverter.Meta);
	return self;
end

Voxel.VoxelSpaceConverter = VoxelSpaceConverter;

--[[
VoxelOccupancy: can store whether or not a cell or cells are occupied.
This might turn out useless. :(
Methods:
	SetCellOccupied(cell, occupancyValue): sets a cell to be occupied. occupancyValue may take any value.
	IsCellOccupied(cell): returns the occupancy value for a given cell, or nil if none exists.
--]]

local VoxelOccupancy = Utils.new("Class", "VoxelOccupancy");

function VoxelOccupancy:SetCellOccupied(cell, occupancyValue)

end

function VoxelOccupancy:IsCellOccupied(cell)

end

function VoxelOccupancy.new()

end

Voxel.VoxelOccupancy = VoxelOccupancy;

return Voxel;
