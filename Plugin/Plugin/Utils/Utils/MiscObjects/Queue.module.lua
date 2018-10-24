local Utils = require(script.Parent.Parent);

local Queue = Utils.new("Class", "Queue");

function Queue.push(t, v)
	t.last = t.last + 1;
	t[t.last] = v;
	if t.last - 1 == t.first then
		t.Changed();
	end
end
function Queue.pop(t)
	if t.first == t.last then
		return nil;
	end
	t.first = t.first + 1;
	return t[t.first];
end
function Queue.flush(self)
	for i = self.first + 1, self.last do
		self[i] = nil;
	end
	self.first = 0;
	self.last = 0;
end
function Queue.size(t)
	return t.last - t.first;
end
function Queue.peek(t)
	return t[t.first + 1];
end
function Queue.iterator(t)
	local i = t.first;
	return function()
		if i == t.last then
			return nil;
		end
		i = i + 1;
		return t[i], i;
	end;
end
function Queue.swap(t, a, b)
	assert(t[a] and t[b], "Must provide valid indices.");
	t[a], t[b] = t[b], t[a];
end

function Queue.Get:Changed()
	rawset(self, "Changed", Utils.new("Event"));
end

function Queue.new()
	return setmetatable({first = 0, last = 0}, Queue.Meta);
end

return Queue;
