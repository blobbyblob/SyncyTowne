local Utils = require(script.Parent.Parent);
local Log = Utils.Log;

local Debug = Log.new("DelayOp:\t", false);

--This class defers running a particular function until the current thread terminates.
--This allows queueing a function to run without immediately running it, leading to
--performance improvements when called multiple times on a single thread.

--[[

To Require:
	local DelayOperation = require(path.to.DelayOperation);

Instantiation:
	DelayOperation.new(operation, arguments, canSignalOnTrigger);
		debugName: the debug name for this element.
		operation: the function to run when triggered.
		arguments: the arguments to pass when triggered.
		canSignalOnTrigger: a boolean which indicates whether this object is allowed to trigger itself while running its OnTrigger operation.

Properties:
	OnTrigger [printHelloWorld]: the operation to run when called up.
	Arguments [nil]: the arguments to pass to OnTrigger. This is a table which will be unpacked.
	CanSignalOnTrigger [false]: a boolean indicating whether OnTrigger is allowed to trigger itself.
	Dirty: a read-only boolean value which indicates whether this function is planning to run.
	DebugName [DelayOperation]: a name to prescribe to this instance so warning messages are more clear.

Methods:
	Trigger(): runs the OnTrigger function after this thread completes.
	RunIfReady(): runs the OnTrigger function *immediately* if it is slated to run.
	__call(): alias for Trigger()

--]]

local DelayOperation = Utils.new("Class", "DelayOperation");

DelayOperation._Operation = function() print("Hello, world!"); end
DelayOperation._Dirty = false;
DelayOperation._PermanentArgs = false;
DelayOperation._CanSignalOnCleanup = false;
DelayOperation._DebugName = "DelayOperation";

DelayOperation.Set.DebugName = "_DebugName";
DelayOperation.Set.OnTrigger = "_Operation";
DelayOperation.Set.Arguments = "_PermanentArgs";
DelayOperation.Set.CanSignalOnTrigger = "_CanSignalOnCleanup";

DelayOperation.Get.DebugName = "_DebugName";
DelayOperation.Get.OnTrigger = "_Operation";
DelayOperation.Get.Dirty = "_Dirty";
DelayOperation.Get.Arguments = "_PermanentArgs";
DelayOperation.Get.CanSignalOnTrigger = "_CanSignalOnCleanup";

local BenchmarkDebug = Log.new("Benchmark:\t", true);

for deprecated, better in pairs({OnCleanup = "OnTrigger", AllowSignalDuringCleanup = "CanSignalOnTrigger"}) do
	DelayOperation.Set[deprecated] = function(self, v)
		Log.Warn("Property %s deprecated in favor of %s", deprecated, better);
		self[better] = v;
	end
	DelayOperation.Get[deprecated] = function(self)
		Log.Warn("Property %s deprecated in favor of %s", deprecated, better);
		return self[better];
	end
end

--A flag which indicates if RunAllTriggered has been spawned, or if it yet needs to be.
local GlobalTriggered = false;
--A map of [DelayOperation] = {args...} elements
local Operations = {};
local function RunAllTriggered()
	local ops = Operations;
	Operations = {};
	GlobalTriggered = false;
	for operation, arguments in pairs(ops) do
		if operation._Dirty then
			operation._Dirty = false;
			operation._Operation(unpack(arguments));
			if not operation._CanSignalOnCleanup then
				if operation._Dirty then
					Debug("Wiping Dirty Bit");
				end
				operation._Dirty = false;
			elseif operation._Dirty then
				Log.Warn("Operation retriggered itself on execution: %s", operation._DebugName);
			end
		end
	end
	GlobalTriggered = false;
end

--[[ @brief Will signal a cleanup operation after the current thread yields.
     @details This class uses a dirty bit so the cleanup operation will only be run once even if it is signalled multiple times.
--]]
--deprecated
local callcount = 0;
function DelayOperation:Trigger(...)
	Debug("DelayOperation.Trigger(%s) called", self);
--	callcount = callcount + 1;
--	if callcount >= 100 then
--		Debug("Full Traceback:\n%s", debug.traceback());
--		Log.Error("DelayOperation.Cleanup() called too often.");
--	end
	local args = self._PermanentArgs or {...};
--	do
--		return self._Operation(unpack(args));
--	end
	if not self._Dirty then
		self._Dirty = true;
		Debug("Attempting to spawn new worker function.");
		spawn(function()
			BenchmarkDebug("Spawn function started at %s", tick());
			if not self._Dirty then
				BenchmarkDebug("    SPawned function started needlessly.");
			end
			Debug("Spawned function started running");
			if self._Dirty then
				self._Dirty = false;
				Debug("Delay operation running");
				self._Operation(unpack(args));
				Debug("Delay operation finished; Dirty bit: %s", self._Dirty);
				if not self._CanSignalOnCleanup then
					if self._Dirty then
						Debug("Wiping Dirty Bit");
					end
					self._Dirty = false;
				elseif self._Dirty then
					Log.Warn("Operation retriggered itself on execution: %s", self._DebugName);
				end
			end
			BenchmarkDebug("Spawned function ended at %s", tick());
		end)
	end
end

function DelayOperation:Trigger(...)
	if not self._Dirty then
		self._Dirty = true;
		Operations[self] = self._PermanentArgs or {...};
		if not GlobalTriggered then
			GlobalTriggered = true;
			spawn(RunAllTriggered);
		end
	end
end

function DelayOperation:Cleanup(...)
	Log.Warn(3, "DelayOperation.Cleanup deprecated in favor of DelayOperation.Trigger");
	self:Trigger(...);
end

--[[ @brief Forces the operation to run immediately IF it is flagged.
--]]
function DelayOperation:RunIfReady(...)
	if self._Dirty then
		self:Run(...);
	end
end

--[[ @brief Forces the operation to run immediately.
--]]
function DelayOperation:Run(...)
	if self._Dirty then
		self._Dirty = false;
		Operations[self] = nil;
	end
	local args = self._PermanentArgs or {...};
	self._Operation(unpack(args));
	if not self._CanSignalOnCleanup then
		if self._Dirty then
			Debug("Wiping Dirty Bit");
		end
		self._Dirty = false;
	end
end

--@brief Creates a debugging string for this instance.
function DelayOperation:__tostring()
	return string.format("DelayOperation: %s", self._DebugName);
end

function DelayOperation:__call(...)
	self:Trigger(...);
end

--[[ @brief Creates a new cleanup operation.
--]]
function DelayOperation.new(debugName, operation, arguments, cansignalontrigger)
	local self = setmetatable({}, DelayOperation.Meta);
	self.DebugName = debugName;
	self.OnTrigger = operation;
	self.Arguments = arguments;
	self.CanSignalOnTrigger = cansignalontrigger;
	return self;
end

return DelayOperation;
