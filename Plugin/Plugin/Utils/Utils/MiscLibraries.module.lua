--[[

Consolidates a lot of small classes.

--]]

local ODL = require(script.Parent.MiscObjects.OnDemandLoader).newLibrary();

ODL.SearchDirectory = script;
ODL.Submodules = {
	ToolTip = "ToolTip";
	PlayerJoinCallback = "PlayerJoinCallback";
	SpawnCallback = "SpawnCallback";
	LocalSpawnCallback = "LocalSpawnCallback";
	WaitForPlayerToSpawn = "WaitForPlayerToSpawn";
	GetCharacterFromPart = "GetCharacterFromPart";
	NumberSensitiveSort = "NumberSensitiveSort";
	CFrameConstraintBody = "CFrameConstraintBody";
	GetUsernameColor = "GetUsernameColor";
	Search = {"Search", "Search"};
}

function ODL.UnpackingIterator(t, i)
	local j = next(t, i);
	if j then
		return j, unpack(t[j]);
	else
		return nil;
	end
end

return ODL;
