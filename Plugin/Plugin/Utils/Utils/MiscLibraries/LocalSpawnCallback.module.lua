local Utils = require(script.Parent.Parent);

local function FireCallbackWhenReady(player, character, onSpawn)
	local GiveUpTime = tick() + 10;
	while (not character or not character:FindFirstChild("Humanoid") or character.Humanoid.Health == 0) and tick() < GiveUpTime do
		wait();
	end
	if tick() < GiveUpTime then
		local humanoid = character:FindFirstChild("Humanoid");
		if not humanoid then
			Utils.Log.Warning("LocalSpawnCallback nearly completed, but could not find Humanoid");
			return;
		end
		local root = character:WaitForChild("HumanoidRootPart", GiveUpTime - tick());
		if not root then
			Utils.Log.Warning("LocalSpawnCallback nearly completed, but could not find HumanoidRootPart");
			return;
		end
		onSpawn(player, character, humanoid, root);
	end
end

function LocalSpawnCallback(onSpawn, checkIfSpawned)
	local player = game.Players.LocalPlayer;
	if checkIfSpawned and player.Character then
		FireCallbackWhenReady(player, player.Character, onSpawn);
	end
	player:GetPropertyChangedSignal("Character"):connect(function()
		FireCallbackWhenReady(player, player.Character, onSpawn);
	end)
end

return LocalSpawnCallback;
