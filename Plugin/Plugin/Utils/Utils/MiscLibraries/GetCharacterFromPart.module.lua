--[[

A function which gets the character given one part in that character.

--]]

return function(p)
	while p and not p:FindFirstChild("Humanoid") do
		p = p.Parent;
	end
	return p;
end
