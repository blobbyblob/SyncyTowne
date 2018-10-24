local HelpDocs = {
	Weld = [[
Weld takes several parts and welds them all together. The weld will be placed in part0. It can be used in the following ways:
	Weld(part0, part1): will weld two parts together where they currently stand.
	Weld(part0, part1, C0, C1): will weld two parts together using specific C0 and C1 values.
	Weld(model): will weld all parts in model to the primary part based on their current positions, or a randomly chosen part if none exists.
	Weld(model0, part1): welds all parts in model to the part in their current positions.
	Weld(part0, model1): welds all parts in model to the part in their current positions.
]]
};

local Log = require(script.Parent.Log);

local WeldLib = setmetatable({}, {});
getmetatable(WeldLib).__call = function(self, ...) return WeldLib.Weld(...); end

local function WeldParts(p0, p1, c0, c1, name)
	local w = Instance.new("Weld");
	w.Part0 = p0;
	w.Part1 = p1;
	w.C0 = c0;
	w.C1 = c1;
	if name then
		w.Name = name;
	end
	w.Parent = p0;
	return w;
end

local function GetOffsets(p0, p1)
	return CFrame.new(), p1.CFrame:inverse() * p0.CFrame;
end

local function Recurse(root, maxDepth, t)
	if not t then t = {}; end
	if not maxDepth then maxDepth = math.huge; else maxDepth = maxDepth - 1; end
	table.insert(t, root);
	if maxDepth >= 0 then
		for i, v in pairs(root:GetChildren()) do
			Recurse(v, maxDepth, t);
		end
	end
	return t;
end

function WeldModel(model, primary, switch)
	for i, v in pairs(Recurse(model)) do
		if v:IsA("BasePart") and v ~= primary then
			if switch then
				WeldParts(primary, v, GetOffsets(primary, v));
			else
				WeldParts(v, primary, GetOffsets(v, primary));
			end
		end
	end
end

local function GetLargestPart(model)
	local largestPart;
	local largestSize = 0;
	for _, SeekDepth in pairs({1, 2, 3, math.huge}) do
		for i, v in pairs(Recurse(model, SeekDepth)) do
			if v:IsA("BasePart") and v:GetMass() > largestSize then
				largestPart = v;
				largestSize = v:GetMass();
			end
		end
		if largestPart then
			return largestPart;
		end
	end
	return false, "No largest part exists in model " .. model.Name;
end

function WeldLib.Weld(a, b, c, d, e)
	if a and b and (c or d) then
		if typeof(a)~='Instance' or not a:IsA("BasePart") then
			Log.AssertNonNilAndType("Argument 1", "BasePart", a);
		elseif typeof(b)~='Instance' or not b:IsA("BasePart") then
			Log.AssertNonNilAndType("Argument 2", "BasePart", b);
		elseif not (c == nil or typeof(c) == "CFrame") then
			Log.AssertNonNilAndType("Argument 3", "CFrame or nil", c);
		elseif not (d == nil or typeof(d) == "CFrame") then
			Log.AssertNonNilAndType("Argument 4", "CFrame or nil", d);
		else
			return WeldParts(a, b, c or CFrame.new(), d or CFrame.new(), e);
		end
	elseif a and b then
		if not (a:IsA("Model") or a:IsA("BasePart")) then
			Log.AssertNonNilAndType("Argument 1", "Model or BasePart", a);
		elseif not (b:IsA("Model") or b:IsA("BasePart")) then
			Log.AssertNonNilAndType("Argument 2", "Model or BasePart", b);
		elseif (a:IsA("Model") and b:IsA("Model")) then
			Log.Error("Only one of argument 1 and 2 may be a model; got %s, %s", a, b);
		else
			if a:IsA("Model") then
				return WeldModel(a, b);
			elseif b:IsA("Model") then
				return WeldModel(b, a, true);
			else
				return WeldParts(a, b, GetOffsets(a, b));
			end
		end
	elseif a then
		if not a:IsA("Model") then
			Log.AssertNonNilAndType("Argument 1", "Model", a);
		else
			if a.PrimaryPart and a.PrimaryPart:IsA("BasePart") then
				return WeldModel(a, a.PrimaryPart);
			else
				return WeldModel(a, GetLargestPart(a));
			end
		end
	end
end

function WeldLib.CharacterToSeat(character, seat)
	WeldLib.Weld(seat, character.HumanoidRootPart, CFrame.new(0, .125, 0), CFrame.new(0, -1.5, 0), "SeatWeld");
end

return WeldLib
