local Log = require(script.Parent.Log);

local HelpDocs = {
	Draw = [[
Renders a point or ray as a part in the workspace.
	Draw{point1, point2, ..., property=value, ...}: draws point with a set of properties. Note the use of curly brackets.
Possible properties include:
	Size: the size of the ball which indicates a single point. Default is 1.
	Color: the BrickColor to make the point. Default is red, green, blue, yellow, white, white, ... when several points are specified.
	Lifetime: the number of seconds this point should persist before being automatically cleaned up. Default is 3 seconds.
	Parent: where this point should be placed. Default is workspace.
]]
};

local DrawLib = setmetatable({}, {});
getmetatable(DrawLib).__call = function(self, ...) return DrawLib.Draw(...); end

local COLORS = {
	BrickColor.Red();
	BrickColor.Green();
	BrickColor.Blue();
	BrickColor.new("Cyan");
	BrickColor.new("Magenta");
	BrickColor.Yellow();
	BrickColor.White();
};
local function GetColor(preferredColor, colorIndex)
	if preferredColor and typeof(preferredColor) == "BrickColor" then
		return preferredColor.Color;
	elseif preferredColor and typeof(preferredColor) == "Color3" then
		return preferredColor;
	else
		return COLORS[colorIndex].Color;
	end
end
function DrawLib.Draw(properties, ...)
	if type(properties) ~= 'table' then return DrawLib.Draw{properties, ...}; end
	properties = properties or {};
	local colorIndex = 1;
	for i = 1, #properties do
		local obj = properties[i];
		if typeof(obj) == "Vector3" then
			local p = Instance.new("Part");
			p.Size = Vector3.new(properties.Size or 1, properties.Size or 1, properties.Size or 1);
			p.CanCollide = false;
			p.Anchored = true;
			p.Shape = Enum.PartType.Ball;
			p.Color = GetColor(properties.Color, colorIndex);
			colorIndex = colorIndex + 1;
			game:GetService("Debris"):AddItem(p, properties.Lifetime or 3);
			p.CFrame = CFrame.new(obj);
			p.Parent = properties.Parent or workspace;
		elseif typeof(obj) == "Ray" then
			local desiredLength = (properties.Length or obj.Direction.magnitude) - 1;
			if desiredLength < .2 then
				properties.Arrow = false;
				desiredLength = desiredLength + 1;
			end
			local p = Instance.new("Part");
			p.Size = Vector3.new(.2, .2, desiredLength);
			p.CanCollide = false;
			p.Anchored = true;
			p.Color = GetColor(properties.Color, colorIndex);
			colorIndex = colorIndex + 1;
			game:GetService("Debris"):AddItem(p, properties.Lifetime or 3);
			p.CFrame = CFrame.new(obj.Origin+obj.Direction.unit*p.Size.z/2, obj.Origin);
			p.Parent = properties.Parent or workspace;
			
			if properties.Mode == "Plane" then
				local plane = p:Clone();
				plane.Size = Vector3.new(properties.Size or 4, properties.Size or 4, 0);
				plane.CFrame = CFrame.new(obj.Origin, obj.Origin + obj.Direction);
				game:GetService("Debris"):AddItem(plane, properties.Lifetime or 3);
				plane.Parent = properties.Parent or workspace;
				Instance.new("BlockMesh", plane).Scale = Vector3.new(1, 1, 0);
			end

			if properties.Arrow == nil or properties.Arrow then
				local p2 = p:Clone();
				local m = Instance.new("SpecialMesh");
				m.MeshId = "rbxassetid://1778999";
				m.Scale = Vector3.new(0.525, 0.6, 0.525);
				m.Parent = p2;
				p2.Size = Vector3.new(.7, 1, 0.7);
				game:GetService("Debris"):AddItem(p2, properties.Lifetime or 3);
				p2.Parent = properties.Parent or workspace;
				p2.CFrame = p.CFrame * CFrame.new(0, 0, p.Size.z/2+0.5) * CFrame.Angles(math.pi/2, 0, 0);
			end
		elseif typeof(obj) == "CFrame" then
			for i = 1, 3 do
				local DrawCommand = {
					Color = properties.Color or COLORS[math.min(colorIndex, #COLORS)],
					Length = properties.Length or 5;
					Lifetime = properties.Lifetime or 3;
					Parent = properties.Parent or workspace;
				};
				if i == 1 then
					table.insert(DrawCommand, Ray.new(obj.p, obj.rightVector));
				elseif i == 2 then
					table.insert(DrawCommand, Ray.new(obj.p, obj.upVector));
				elseif i == 3 then
					table.insert(DrawCommand, Ray.new(obj.p, -obj.lookVector));
				end
				DrawLib.Draw(DrawCommand);
				colorIndex = colorIndex + 1;
			end
		else
			Log.Error("Unknown type for %s (%s)", obj, typeof(obj));
		end
	end
end

return DrawLib;
