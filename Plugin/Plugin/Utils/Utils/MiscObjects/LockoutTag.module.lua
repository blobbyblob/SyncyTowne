--[[

Methods:
	Take(): returns a tag.
	Valid(ticket): Returns true if the tag is valid.
	InvalidateTags(): Invalidates all past tags.

Operation:
1. Take a tag.
2. Ask if tag is valid at some point in the future -- generally after a wait statement.

Asynchronously, another thread can invalidate your tag and validate a new tag.

Reason why a simple boolean doesn't work:
	local isAttacking = false;
	function doDamage(target)
		if isAttacking then return; end
		isAttacking = true;
		wait(1);
		if isAttacking then
			target:TakeDamage(20);
		end
	end
	function stopAttacking()
		isAttacking = false;
	end
	
	doDamage(myTarget); --> This succeeds
	wait(.5);
	stopAttacking();
	doDamage(myTarget); --> This succeeds too, dealing 40 damage instead of 20.

This example would be converted to the following:
	local LockoutTag = Utils.new("LockoutTag");
	function doDamage(target)
		local ticket = LockoutTag:Take();
		if not LockoutTag:Valid(ticket) then return; end
		wait(1);
		if LockoutTag:Valid(ticket) then return; end
		target:TakeDamage(20);
		LockoutTag:InvalidateTags();
	end
	function stopAttacking()
		LockoutTag:InvalidateTags();
	end

	doDamage(myTarget); --> This operation gets cancelled.
	wait(.5);
	stopAttacking();
	doDamage(myTarget); --> This, however, succeeds, dealing 20 damage.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local LockoutTag = Utils.new("Class", "LockoutTag");

LockoutTag._CurrentTally = 0; --! The current tag number. When this is even, all tags are invalid.
LockoutTag._ReturnEvent = false; --! A BindableEvent to call when returning a valid ticket.
LockoutTag._NextInLine = false; --! A LockoutTag for use within YieldTakeLimitOne.

function LockoutTag:Take()
	if self._CurrentTally % 2 == 0 then
		self._CurrentTally = self._CurrentTally + 1;
		return self._CurrentTally;
	else
		self._CurrentTally = self._CurrentTally + 2;
		return self._CurrentTally;
	end
end

--Take a tag if we aren't locked out; however, if we are locked out, wait until
--a tag is available.
--If another thread comes looking for a ticket, this function may return an invalid
--ticket.
function LockoutTag:YieldTakeLimitOne()
	if not self._NextInLine then
		self._NextInLine = LockoutTag.new();
	end
	if self._CurrentTally % 2 == 0 then
		self._CurrentTally = self._CurrentTally + 1;
		return self._CurrentTally;
	else
		local t = self._NextInLine:Take();
		self:_WaitForReturn();
		if self._NextInLine:Valid(t) then
			return self:Take();
		end
	end
end

function LockoutTag:_WaitForReturn()
	if not self._ReturnEvent then
		self._ReturnEvent = Instance.new("BindableEvent");
	end
	self._ReturnEvent.Event:wait();
	return;
end

function LockoutTag:Return(ticket)
	if self:Valid(ticket) then
		self:InvalidateTags();
		if self._ReturnEvent then
			self._ReturnEvent:Fire();
		end
	end
end

function LockoutTag:Valid(ticket)
	return ticket == self._CurrentTally;
end
LockoutTag.IsValid = LockoutTag.Valid;

function LockoutTag:InvalidateTags()
	if self._CurrentTally % 2 == 1 then
		self._CurrentTally = self._CurrentTally + 1;
	end
end
LockoutTag.InvalidateAll = LockoutTag.InvalidateTags;

function LockoutTag.new()
	local self = setmetatable({}, LockoutTag.Meta);
	return self;
end

function LockoutTag.test()
	local t = LockoutTag.new();
	local r = t:Take();
	Utils.Log.AssertEqual("r", true, t:Valid(r));
	local s = t:Take();
	Utils.Log.AssertEqual("r (voided)", false, t:Valid(r));
	Utils.Log.AssertEqual("s", true, t:Valid(s));
	spawn(function()
		t:Return(s);
	end)
	local q = t:YieldTakeLimitOne();
	Utils.Log.AssertEqual("q", true, t:Valid(q));

	local startTime = tick();
	spawn(function()
		wait();
		r = t:YieldTakeLimitOne();
		Utils.Log.Assert(tick() - startTime > .19, "Didn't yield long enough");
		Utils.Log.AssertEqual("r", false, t:Valid(r));
	end)
	spawn(function()
		wait(.1);
		s = t:YieldTakeLimitOne();
		Utils.Log.Assert(tick() - startTime > .19, "Didn't yield long enough");
		Utils.Log.AssertEqual("s", true, t:Valid(s));
	end)
	wait(.2);
	t:Return(q);
	print("done!");
end

return LockoutTag;
 