function PlayerJoinCallback(onPlayerAdded)
	game.Players.PlayerAdded:connect(function(player)
		onPlayerAdded(player)
	end)
	for i, v in pairs(game.Players:GetPlayers()) do
		onPlayerAdded(v);
	end
end

return PlayerJoinCallback;