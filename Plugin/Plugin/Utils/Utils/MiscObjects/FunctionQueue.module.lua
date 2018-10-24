--[[

This class allows queueing up functions to be run at once.

Constructor:
	new()
Methods:
	Add(func, args...): adds a function to the queue with corresponding arguments.
	Dispatch(): fires all functions in order.

Note: a failed function will not impact the remainder of the functions.

--]]

local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local FunctionQueue = Utils.new("Class", "FunctionQueue");

--A table holding elements of the form {func, {args}}.
FunctionQueue._Functions = false;

--[[ @brief Add a function to be run when requested.
     @param func The function to run.
     @param args... The arguments to pass to the function.
--]]
function FunctionQueue:Add(func, ...)
	local arguments = {...};
	table.insert(self._Functions, {func, arguments});
end

--[[ @brief Runs all currently queued functions.
--]]
function FunctionQueue:Dispatch()
	for i, v in pairs(self._Functions) do
		local f = v[1];
		local args = v[2];
		local co = coroutine.create(f);
		local success, error = coroutine.resume(co, unpack(args));
		if not success then
			Log.Warn("Function %s terminated with an error: %s", f, error);
		end
	end
	self._Functions = {};
end

--[[ @brief Creates a new FunctionQueue object.
--]]
function FunctionQueue.new()
	local self = setmetatable({}, FunctionQueue.Meta);
	self._Functions = {};
	return self;
end

return FunctionQueue;
