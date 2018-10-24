--[[

Aggregates a set of libraries into one interface.

Consult the constants near the top to determine what libraries are contained.

Operations:
	Utils[index]: returns a library whose name matches index, e.g., "Log", "Draw", "Math", etc.
	Utils.new("ClassName", ...): constructs a new object with a given class name. Examples include "Log", "TestRegistry", "Event", etc.
		Some functions require additional parameters.

--]]

local OnDemandLoader = require(script.MiscObjects.OnDemandLoader);

local Utils = OnDemandLoader.newLibrary();
Utils.SearchDirectory = script;
Utils.new = OnDemandLoader.newConstructor();
Utils.new.SearchDirectory = script;

Utils.Submodules = {
	Weld = "Weld";
	Recurse = "Recurse";
	Log = "Log";
	Draw = "Draw";
	Source = "Source";
	Math = "Math";
	Table = "Table";
	Gui = "Gui3";
	Animate = "Animate";
	Mouse = "Mouse";
	Misc = "MiscLibraries";
};
Utils.new.Classes = {
	ConnectionHolder = {"MiscObjects", "ConnectionHolder"};
	LockoutTag = {"MiscObjects", "LockoutTag"};
	Benchmarker = {"MiscObjects", "Benchmarker"};
	DelayOperation = {"MiscObjects", "DelayOperation"};
	Event = {"MiscObjects", "EventWrapper"};
	FunctionQueue = {"MiscObjects", "FunctionQueue"};
	WhileLoopLimiter = {"MiscObjects", "WhileLoopLimiter"};
	Constructor = {"MiscObjects", "newConstructor"};
	Library = {"MiscObjects", "newLibrary"};
	ConstructorLoader = {"MiscObjects", "newConstructor"};
	LibraryLoader = {"MiscObjects", "newLibrary"};
	EventLoaderBuilder = {"MiscObjects", "newEventLoader"};
	Heap = {"MiscObjects", "Heap"};
	NetworkIO = {"MiscObjects", "NetworkIO"};
	Countdown = {"MiscObjects", "Countdown"};
	MultiSet = {"MiscObjects", "MultiSet"};
	Maid = {"MiscObjects", "Maid"};

	LayeredTable = {"Table", "newLayeredTable"};
	ReadOnlyWrapper = {"Table", "newReadOnlyWrapper"};

	EnumContainer = "Enum";
	Enum = {"Enum", "newEnumClass"};
	Class = "Class";
	Log = "Log";
	Margin = "Margin";
	TestRegistry = "TestRegistry";
	CFrame2D = "CFrame2D";

	VoxelSpaceConverter = {"Math", "VoxelSpaceConverter"};
	VoxelOccupancy = {"Math", "VoxelOccupancy"};
};

return Utils;
 