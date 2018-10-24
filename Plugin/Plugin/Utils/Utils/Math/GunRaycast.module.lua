--[[

The following represents a raycast function suitable for guns.

The ray passes through all CanCollide = false parts unless they belong to a Humanoid.

--]]

local Utils = require(script.Parent.Parent);

local FindCharacterAncestor = Utils.Misc.GetCharacterFromPart;

function Raycast(lookRay, ignoreList)
	ignoreList = ignoreList or {};
    local target, point, normal, targetCharacter;
    repeat
        target, point, normal = workspace:FindPartOnRayWithIgnoreList(lookRay, ignoreList);
        targetCharacter = FindCharacterAncestor(target);
        if target and not target.CanCollide and not targetCharacter then
            table.insert(ignoreList, target);
            target = nil;
        else
			return target, point, normal;
        end
    until target;
end

return Raycast;
