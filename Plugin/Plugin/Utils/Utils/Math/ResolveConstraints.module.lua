local Utils = require(script.Parent.Parent);
local Debug = Utils.new("Log", "ResolveConstraints: ", true);

local module = {};

--[[ @brief Resets all constraints so that none should be exerting forces.
     @param parts A list of parts which may participate in the relaxation. The first part is the anchor. Parts may be duplicated in this list.
     @param constraints A list of constraints which may participate in the relaxation.
--]]
function module.ResolveConstraints(parts, constraints)
	--Assign every part to a group based on its connected parts.
	local groupsByPart = {};
	local partsByGroup = {};
	local nextIndex = 1;
	local function AssignPartGroup(part)
		assert(not groupsByPart[part]);
		groupsByPart[part] = nextIndex;
		partsByGroup[nextIndex] = {part};
		for i, v in pairs(part:GetConnectedParts(true)) do
			Debug("Part %s is connected to %s", part, v);
			assert(not groupsByPart[v]);
			groupsByPart[v] = nextIndex;
			table.insert(partsByGroup[nextIndex], v);
		end
		nextIndex = nextIndex + 1;
	end
	for i = 1, #parts do
		if not groupsByPart[parts[i]] then
			AssignPartGroup(parts[i]);
		end
	end
	Debug("groupsByPart: %t", groupsByPart);

	--Create a mapping of group -> constraint.
	local constraintsByGroups = {};
	for i, c in pairs(constraints) do
		if c.Attachment0 and c.Attachment0.Parent and c.Attachment1 and c.Attachment1.Parent then
			local g0 = groupsByPart[c.Attachment0.Parent];
			local g1 = groupsByPart[c.Attachment1.Parent];
			if g0 and g1 then
				local g0, g1 = math.min(g0, g1), math.max(g0, g1);
				constraintsByGroups[g0] = {g1, c};
				constraintsByGroups[g1] = {g0, c};
			end
		end
	end
	Debug("constraintsByGroups: %t", constraintsByGroups);
	for index0, v in pairs(constraintsByGroups) do
		table.sort(v, function(a, b) return a[1] < b[1] or a[1] == b[1] and a[2].ClassName < b[2].ClassName; end);
	end

	local connectedGroups = {1}; --group index 1 is the root.
	local queuedGroups = {[1] = true};
	local i = 1;
	while i <= #connectedGroups do
		Debug("Handling Group %s", connectedGroups[i]);
		local group = connectedGroups[i];
		--get all constraints which connect this group to another group. We have to handle constraints together sometimes.
		local constr = constraintsByGroups[group];
		local lastOther;
		local collectedConstraints = {};
		for j = 1, #constr do
			local other, constraint = constr[j][1], constr[j][2];
			--If our group index switched, invoke the resolver & clear the temporary list.
			if lastOther and lastOther ~= other then
				local offset = PlaceGroups(collectedConstraints);
				--Translate the "other" group by offset.
				--TODO
				collectedConstraints = {};
			end
			--If we just encountered a new group, add it to the queue to process later.
			if lastOther ~= other and not queuedGroups[other] then
				lastOther = other;
				queuedGroups[other] = true;
				table.insert(connectedGroups, other);
			end
			--Always add the current constraint to our collection.
			if groupsByPart[constr[j][2].Attachment0.Parent] == group then
				local anchorCf = constr[j][2].Attachment0.Parent.CFrame * constr[j][2].Attachment0.CFrame;
				local leafCf = constr[j][2].Attachment1.Parent.CFrame * constr[j][2].Attachment1.CFrame;
				table.insert(collectedConstraints, {constr[j][2], anchorCf, leafCf});
			end
		end
		i = i + 1;
	end
end

function module.ResolveConstraintsInModel(model)
	local parts, constraints = {}, {};
	for i, v in pairs(model:GetDescendants()) do
		if v:IsA("BasePart") then
			table.insert(parts, v);
		elseif v:IsA("Constraint") then
			table.insert(constraints, v);
		end
	end
	return module.ResolveConstraints(parts, constraints);
end

function module.Test()
	local p0 = Instance.new("Part");
	local p1 = p0:Clone();
	local p2 = p0:Clone();
	local p3 = p0:Clone();
	Utils.Weld(p0, p1);
	Utils.Weld(p2, p3);
	local c = Instance.new("BallSocketConstraint", p0);
	c.Attachment0 = Instance.new("Attachment", p0);
	c.Attachment1 = Instance.new("Attachment", p2);
	module.ResolveConstraints({p0, p1, p2, p3}, {c});
end

return module;
