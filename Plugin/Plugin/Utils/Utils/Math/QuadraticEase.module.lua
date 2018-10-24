--[[

Attempts to solve the problem of using constant acceleration to get to a destination point.

Graphically:

	    |     _
	    |   /   \
	    | /       \
	p_i |/         \
	v_i |           |
	    |           \
	    |            \
	    |              \
	    |________________\___
	                T      U

Ok, turns out the graph was a bust, but the main points:
	* p_i (initial position) and v_i (initial velocity) are known
	* acceleration is constant. In our graph, we accelerate at -a until T at which point we switch to +a.
	* When we reach our final position (time U, position 0), we have 0 velocity.

Some Scratch Work:

t <= T: f(t) = p + vt - a/2*t^2
t > T:  f(t) = f(T) + f'(T)(t - T) + a/2*(t - T)^2
             = [p + vT - a/2 * T^2] + [v - aT](t - T) + a/2*(t - T)^2

t <= T: f'(t) = v - at
t > T:  f'(t) = [v - aT] + a(t - T)

t <= T: f"(t) = -a
t > T:  f"(t) = a

f(U) = 0  <==> [p + vT - a/2 * T^2] + [v - aT](U - T) + a/2*(U - T)^2 = 0
           ==> T = U +- sqrt((aU^2 - 2p - 2Uv)/(2a))
           ==> U = [(2aT - v) +- sqrt(2a^2 T^2 - 2a(p + 2Tv) + v^2)] / a
f'(U) = 0 <==> [v - aT] + a(U - T) = 0
           ==> U = 2T - v/a
           ==> T = (aU+v)/(2a)

Combining:
	==> (aU+v)/(2a) = U +- sqrt((aU^2 - 2p - 2Uv)/(2a))
	==> U = v/a +- sqrt(2v^2 + 4ap)/a

What do the two solutions for U mean?
The current p_i and v_i values could be the result of having /started/ at
the origin with a velocity 0 and accelerating downward, then upward. Thus,
one of the U's should point behind the origin.

Then we can reuse f'(U) = 0 to solve for T.
WHAT A HAUL.
Special thanks to our friends at wolfram alpha who saved me from having to do tons of algebra.

Desmos graphing calculator is a pretty good way to visualize this.
	f\left(x\right)=\left\{x\le t:p+vx-\frac{ax^2}{2},\ x>t:p+vt-\frac{at^2}{2}+\left(v-at\right)\left(x-t\right)+\frac{a\left(x-t\right)^2}{2}\right\}
You can plug in that LaTeX and create sliders for p, v, a, and t to see what a graph of this sort looks like.

--]]

local Utils = require(script.Parent.Parent);

--[[ @brief Does the same thing as QuadraticEase except without variable checking.
--]]
local function QuadraticEaseHelper(p, v, a)
	local discriminant = math.sqrt(2*v*v + 4*a*p);
	local U1 = (v + discriminant) / a;
	local U2 = (v - discriminant) / a;
	local U = math.max(U1, U2);
	local T = (a*U+v)/(2*a)
	return T, U;
end

--[[ @brief Calculates the inflection point to ease to a target using quadratics.

     It's a decent idea to interpret T < 0 as "decelerate" and T > 0 as "accelerate"
     if you're calling this every frame to simulate a BodyPosition or similar.
     @param p The initial position.
     @param v The initial velocity.
     @param a The constant acceleration.
     @return The inflection time, T.
     @return The final time, U.
     @return The acceleration one should use for t < T.
--]]
function QuadraticEase(p, v, a)
	Utils.Log.Assert(a > 0, "acceleration must be positive");
	--If we're starting below the origin, we want to accelerate
	--upwards, then downwards, so flip a.
	if p < 0 then a = -a; end

	local T, U = QuadraticEaseHelper(p, v, a);

	if T < 0 then
		a = -a;
		T, U = QuadraticEaseHelper(p, v, a);
	end
	return T, U, -a;
end

function Test()
	--These values were all visually inspected by plugging them
	--into the starting equations and checking if they were about right.
	TestGraphical();

	--Positive position, positive velocity
	local inflect, final, acceleration = QuadraticEase(2.2, .3, 1);
	Utils.Log.AssertAlmostEqual("T", 1.79, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 3.30, .01, final);
	Utils.Log.AssertAlmostEqual("a", -1, .001, acceleration);

	--Positive position, negative velocity
	local inflect, final, acceleration = QuadraticEase(2.2, -.3, 1);
	Utils.Log.AssertAlmostEqual("T", 1.20, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 2.70, .01, final);
	Utils.Log.AssertAlmostEqual("a", -1, .001, acceleration);

	--Positive position, overshooting velocity
	local inflect, final, acceleration = QuadraticEase(2.2, -3, 1);
	Utils.Log.AssertAlmostEqual("T", 4.52, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 6.03, .01, final);
	Utils.Log.AssertAlmostEqual("a", 1, .001, acceleration);

	--Negative position, negative velocity
	local inflect, final, acceleration = QuadraticEase(-2.2, -.3, 1);
	Utils.Log.AssertAlmostEqual("T", 1.79, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 3.30, .01, final);
	Utils.Log.AssertAlmostEqual("a", 1, .001, acceleration);

	--Negative position, positive velocity
	local inflect, final, acceleration = QuadraticEase(-2.2, .3, 1);
	Utils.Log.AssertAlmostEqual("T", 1.20, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 2.70, .01, final);
	Utils.Log.AssertAlmostEqual("a", 1, .001, acceleration);

	--Origin, positive velocity.
	local inflect, final, acceleration = QuadraticEase(0, 3, 1);
	Utils.Log.AssertAlmostEqual("T", 5.12, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 7.24, .01, final);
	Utils.Log.AssertAlmostEqual("a", -1, .001, acceleration);

	--Origin, negative velocity.
	local inflect, final, acceleration = QuadraticEase(0, -3, 1);
	Utils.Log.AssertAlmostEqual("T", 5.12, .01, inflect);
	Utils.Log.AssertAlmostEqual("U", 7.24, .01, final);
	Utils.Log.AssertAlmostEqual("a", 1, .001, acceleration);
end

function TestGraphical()
	local function PositionMap(xMin, xMax, yMin, yMax)
		local xRange = xMax - xMin;
		local yRange = yMax - yMin;
		local xMid = (xMax + xMin) / 2;
		local yMid = (yMax + yMin) / 2;
		if xRange == 0 then xRange = 1; end
		if yRange == 0 then yRange = 1; end
		local cf = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, -25);
		local sz = Vector3.new(48, 30, 0);
		return function(x, y)
			local p = cf * CFrame.new(sz.X * (x - xMid) / xRange, sz.Y * (y - yMid) / yRange, 0);
			Utils.Draw{p.p};
		end
	end

	local pos = 5;
	local vel = 3;
	local acc = 2;

	local inflect, final, acceleration = QuadraticEase(pos, vel, acc);

	--Create a list of points.
	local points = {};
	local dt = final / 100;
	for i = 0, 100 do
		local t = dt * i;
		pos = pos + vel * dt;
		if t > inflect then
			vel = vel - acceleration * dt;
		else
			vel = vel + acceleration * dt;
		end
		points[i + 1] = pos;
	end

	local xMin, xMax = 1, #points;
	local yMin, yMax = points[1], points[1];
	for i = 1, #points do
		yMin = math.min(points[i], yMin);
		yMax = math.max(points[i], yMax);
	end

	local map = PositionMap(xMin, xMax, yMin, yMax);
	for i, v in pairs(points) do
		map(i, v);
	end
end

return setmetatable({Test = Test}, {__call = function(t, ...) return QuadraticEase(...); end});
