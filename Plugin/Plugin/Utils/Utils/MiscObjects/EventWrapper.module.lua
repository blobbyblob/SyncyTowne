--[[

A small wrapper on events which allows cyclic tables to be passed through.

Events cannot be passed across environment boundaries, e.g., server to client.

Use in the same way as a BindableEvent.
	local b = EventWrapper.new();
Trigger the event with "Fire":
	spawn(function() wait(1); b:Fire('bar'); end);
Connect using b.Event:connect or b:connect:
	b:connect(function(arg) print('foo: ', arg); end); --> foo bar
	b.Event:connect(function(arg) print('baz: ', arg); end); --> baz bar
Wait using b.Event:wait or b:wait:
	print('bax: ', b:wait()); --> bax bar

--]]

local Utils = require(script.Parent.Parent);

local Debug = Utils.new("Log", "Event: ", false);

local EventWrapper = Utils.new("Class", "EventWrapper");

EventWrapper._Event = false;
EventWrapper._Index = 1;
EventWrapper._Arguments = false;
EventWrapper._CreationStamp = false;

function EventWrapper.Get:Event()
	return self;
end

function EventWrapper:connect(func)
	Debug("Connecting on function %s", func);
	local cxn = self._Event.Event:connect(function(index)
		Debug("Event fired with index %d", index);
		func(unpack(self._Arguments[index]));
	end);
	return cxn;
end

function EventWrapper:wait()
	local index = self._Event.Event:wait();
	return unpack(self._Arguments[index]);
end

function EventWrapper:Fire(...)
	Debug("Firing event with arguments: %t", {...});
	local ExpiryTime = tick() - 1;
	for i, v in pairs(self._CreationStamp) do
		if v < ExpiryTime then
			self._CreationStamp[i] = nil;
			self._Arguments[i] = nil;
		end
	end
	local i = self._Index;
	self._Index = self._Index + 1;
	self._Arguments[i] = {...};
	self._CreationStamp[i] = tick();
	self._Event:Fire(i);
end

function EventWrapper:Destroy()
	self._Event:Destroy();
	self._Arguments = nil;
	self._CreationStamp = nil;
end

function EventWrapper.new()
	local self = setmetatable({}, EventWrapper.Meta);
	self._Event = Instance.new("BindableEvent");
	self._Arguments = {};
	self._CreationStamp = {};
	return self;
end

return EventWrapper;
