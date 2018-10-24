--[[

Gets the velocity of a point on a given part.

I'm really bummed I made this a separate module under the assumption it was going to be tough.
Oh well.

--]]

return function(part, point)
	return part.Velocity + (point - part.CFrame.p):Cross(-part.RotVelocity);
end;
