--[[

CFrames a whole bunch of parts relative to one "master" part which will attain some desired CFrame.

--]]

local Utils = require(script.Parent.Parent);
local Debug = Utils.new("Log", "CFrameGroupRelative: ", true);

local function GroupParts(parts)
	local groupsByPart = {};
	local partsByGroup = {};
	local nextIndex = 1;
	for i, v in pairs(parts) do
		if v:IsA("BasePart") and not groupsByPart[v] then
			partsByGroup[nextIndex] = v:GetConnectedParts(true);
			for i, v in pairs(partsByGroup[nextIndex]) do
				groupsByPart[v] = nextIndex;
			end
			nextIndex = nextIndex + 1;
		end
	end
	for i, v in pairs(partsByGroup) do
		table.sort(v, function(a, b) return a.Anchored and not b.Anchored; end);
	end
	return partsByGroup;
end

--[[ @brief This solution CFrames only what is necessary.
     @details All anchored parts must be CFramed, and in any connected body, at least one part must be CFramed.
     @todo This needs to be fixed w.r.t. CFraming a Character if we are to replace the following with it.
--]]
local CFRAME_FEWEST_PARTS = false;
function CFrameGroupRelative(referencePart, targetCFrame, listOfParts)
--	local offset = referencePart.CFrame:inverse() * targetCFrame;
	local partsByGroup = GroupParts(listOfParts);
	local rootOffset;
	if referencePart:IsA("BasePart") then
		rootOffset = referencePart.CFrame:inverse();
	elseif referencePart:IsA("Attachment") then
		rootOffset = referencePart.WorldCFrame:inverse();
	else
		Utils.Log.Assert("ReferencePart must be BasePart or Attachment; got %s", referencePart.ClassName);
	end
	for i, v in pairs(partsByGroup) do
		if CFRAME_FEWEST_PARTS then
			--for each group, CFrame all Anchored parts or one unanchored part.
			if v[1].Anchored then
				for i, v in pairs(v) do
	--				v.CFrame = v.CFrame * offset;
					v.CFrame = targetCFrame * (rootOffset * v.CFrame);
				end
			else
	--			v[1].CFrame = v[1].CFrame * offset;
				v[1].CFrame = targetCFrame * (rootOffset * v[1].CFrame);
			end
		else
			local offset = {};
			for i, v in pairs(v) do
				offset[v] = targetCFrame * rootOffset * v.CFrame;
			end
			for v, cf in pairs(offset) do
				v.CFrame = cf;
			end
		end
	end
end

--[[ @brief This solution anchors everything, CFrames them all, then unanchors.
     @details This is meant to get around a handful of problems, not the least of which being that the character is CFramed in a magical(ly painful) way.
--]]
function CFrameGroupRelative(referencePart, targetCFrame, listOfParts)
	local originalCFrames = {};
	local originalAnchored = {};
	for i, v in pairs(listOfParts) do
		if v:IsA("BasePart") then
			if not originalCFrames[v] then
				originalCFrames[v] = v.CFrame;
				originalAnchored[v] = v.Anchored;
				v.Anchored = true;
			end
		end
	end
	local referenceCFrame;
	if referencePart:IsA("BasePart") then
		referenceCFrame = referencePart.CFrame;
	elseif referencePart:IsA("Attachment") then
		referenceCFrame = referencePart.WorldCFrame;
	else
		Utils.Log.Assert("ReferencePart must be BasePart or Attachment; got %s", referencePart.ClassName);
	end
	Debug("Original CFrame %s", referenceCFrame);
	Debug("Desired CFrame %s", targetCFrame);
	local offset = targetCFrame * referenceCFrame:inverse();
	Debug("Offset: %s", offset);
	for v, cf in pairs(originalCFrames) do
		Debug("Moving %s to %s", v, offset * cf);
		v.CFrame = offset * cf;
		v.Velocity = Vector3.new();
		v.RotVelocity = Vector3.new();
		Debug("Ended up at: %s", v.CFrame);
	end
	for v, anchored in pairs(originalAnchored) do
		v.Anchored = anchored;
	end
end

return CFrameGroupRelative;
