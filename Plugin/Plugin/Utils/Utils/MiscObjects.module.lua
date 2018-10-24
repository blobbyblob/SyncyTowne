--[[

Consolidates a lot of small classes.

--]]

local ODL = require(script.OnDemandLoader).newConstructor();

ODL.SearchDirectory = script;
ODL.Classes = {
	Benchmarker = "Benchmarker";
	ConnectionHolder = "ConnectionHolder";
	DelayOperation = "DelayOperation";
	EventWrapper = "EventWrapper";
	FunctionQueue = "FunctionQueue";
	LockoutTag = "LockoutTag";
	WhileLoopLimiter = "WhileLoopLimiter";
	newConstructor = {"OnDemandLoader", "newConstructor"};
	newLibrary = {"OnDemandLoader", "newLibrary"};
	newEventLoader = {"OnDemandLoader", "newEventLoader"};
	Heap = "Heap";
	NetworkIO = "NetworkIO";
	Bits = "Bits";
	Countdown = "Countdown";
	MultiSet = "MultiSet";
	Maid = "Maid";
}

return ODL;
