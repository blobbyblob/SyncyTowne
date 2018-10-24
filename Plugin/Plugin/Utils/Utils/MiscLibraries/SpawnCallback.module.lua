--[[** Registers a callback to be invoked any time a player spawns.
	
This is meant to be called on the server.

@param onSpawn (function(player, character)) a function called whenever a player spawns.
**--]]
function SpawnCallback(onSpawn)
	local function onPlayerAdded(player)
		player:GetPropertyChangedSignal("Character"):connect(function()
			local character = player.Character;
			local GiveUpTime = tick() + 10;
			while (not character or not character:FindFirstChild("Humanoid") or character.Humanoid.Health == 0) and tick() < GiveUpTime do
				wait();
			end
			if tick() < GiveUpTime then
				wait();
				onSpawn(player, character);
			end
		end)
		if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
			onSpawn(player, player.Character);
		end
	end
	game.Players.PlayerAdded:connect(function(player)
		onPlayerAdded(player)
	end)
	for i, v in pairs(game.Players:GetPlayers()) do
		onPlayerAdded(v);
	end
end

return SpawnCallback;

