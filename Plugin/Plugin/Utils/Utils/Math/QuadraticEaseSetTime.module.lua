--[[

Solves the problem of picking a velocity and acceleration to get from point A to point B
in a set amount of time.

https://www.desmos.com/calculator/ktksix2swa

y\left(t\right)=-p_0+v_0t+\frac{at^2}{2}
v_0=-t_0a
a=-\frac{2p_0}{t_0^2}

Input is the desired delta-p and time to target. Output is the current velocity you should have,
and current acceleration you should follow.

E.g.,
f(1 stud, 1 second) = 2 studs/s, -2 studs/s/s

--]]

local Utils = require(script.Parent.Parent);

function QuadraticEaseSetTime(dp, dt)
	local a = -2*dp / dt^2;
	return -dt*a, a;
end

function Test()
	local v, a = QuadraticEaseSetTime(1, 1)
	Utils.Log.AssertEqual("v", 2, v);
	Utils.Log.AssertEqual("a", -2, a);
end

return setmetatable({
	Test = Test;
}, {
	__call = function(t, ...)
		return QuadraticEaseSetTime(...);
	end
});