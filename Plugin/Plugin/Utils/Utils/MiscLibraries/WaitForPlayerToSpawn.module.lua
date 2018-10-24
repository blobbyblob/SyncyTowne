--[[ @brief Waits for a live player to spawn and returns it. This only works locally.
     @return The player object
     @return The character
     @return The humanoid
     @return The HumanoidRootPart
--]]
function WaitForPlayerToSpawn(timeout)
	timeout = timeout or 5;
	local timeoutTime = tick() + timeout;
	while not game.Players.LocalPlayer and tick() < timeoutTime do
		wait();
	end
	if tick() >= timeoutTime then
		error("Failed to load player");
	end
	local player = game.Players.LocalPlayer;
	while (not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health == 0) and tick() < timeoutTime do
		wait();
	end
	if tick() >= timeoutTime then
		error("Failed to load character");
	end
	local character = player.Character;

	--We know Humanoid is there because we just tested it when waiting for the character to load.
	local humanoid = character:FindFirstChild("Humanoid");
	assert(not not humanoid, "Unexpectedly could not find Humanoid");

	--We are fairly confident HumanoidRootPart is there because the character is alive.
	local hrp = character:FindFirstChild("HumanoidRootPart");
	assert(not not hrp, "Unexpectedly could not find HumanoidRootPart");

	while not humanoid:IsDescendantOf(game) and tick() < timeoutTime do
		wait();
	end

	return player, character, humanoid, hrp;
end

return WaitForPlayerToSpawn;
