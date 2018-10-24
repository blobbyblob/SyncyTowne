--[[


Properties:

Methods:

Constructors:


--]]

local Utils = require(game.ReplicatedStorage.Utils);
local Debug = Utils.new("Log", "Countdown: ", true);

local Countdown = Utils.new("Class", "Countdown");

Countdown._FinalTime = 0;
Countdown.Callback = function(secondsRemaining) end
Countdown._Ticket = false;
Countdown._Paused = false;

function Countdown.Set:Paused(v)
	if v and not self._Paused then
		self._FinalTime = self._FinalTime - tick();
		self._Ticket:InvalidateTags();
	elseif not v and self._Paused then
		self:Set(self._FinalTime);
	end
	self._Paused = v;
end

function Countdown:Set(timeLeft)
	self._FinalTime = tick() + timeLeft;
	local t = self._Ticket:Take();
	spawn(function()
		while self._Ticket:IsValid(t) do
			local timeLeft = self._FinalTime - tick();
			self.Callback(math.ceil(timeLeft));
			if timeLeft < 0 then
				self._Ticket:Return(t);
				break;
			end
			wait(timeLeft % 1);
		end
	end);
end

function Countdown.new()
	local self = setmetatable({}, Countdown.Meta);
	self._Ticket = Utils.new("LockoutTag");
	return self;
end

return Countdown;
