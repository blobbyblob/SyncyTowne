--[[

Allows defining a group of functions as tests.
Each function can be described with a list of tags (these are underscore-separated).

Test functions can be dispatched. Either all functions can be run, or only ones which meet tag requirements.

Constructor:
	new()
Property:
	BetweenFunction: a function called before every test. If this returns a value, it will be passed into each test.
	Init: a function that runs before the very first test.
	DelayTime: a number of seconds to wait between tests.
Methods:
	__newindex(functionTags, function): registers a function with a set of tags. The tag set is a single string with underscore-separated tags.
	__call(tags...): invokes all functions which meet the tag requirement. tags... can either be a single string with underscore-separated tags, or a table of strings.

--]]

local lib = script.Parent;
local Class = require(lib.Class);
local Log = require(lib.Log);

local TestDebug = Log.new("Test:\t", true);
local Debug = Log.new("Test (Internals):\t", false);

local TestRegistry = Class.new();
TestRegistry.DelayTime = 0; --Amount of time to wait between tests.
TestRegistry._PrecedingFunction = function() end;
TestRegistry._InitializeFunction = function() end;

function TestRegistry.Set:BetweenFunction(v)
	if v==nil then
		self._PrecedingFunction = nil;
	elseif type(v)=='function' then
		self._PrecedingFunction = v;
	else
		Log.AssertNonNilAndType("BetweenFunction", "function", v);
	end
end
TestRegistry.Set.Init = "_InitializeFunction";

--[[ @brief Loops through a list of tags and expands single strings separated with underscores into separate array elements.
     @details To make it easier to copy/paste a function name as an execution argument, we separate Test_Tags separated by an underscore as if they were entered as different list arguments, e.g., {"Test_Tags"} --> {"Test", "Tags"}
     @param[in,out] tags A list of strings.
--]]
function ExpandTags(tags)
	local i = 1;
	while i <= #tags do
		local multitag = tags[i];
		table.remove(tags, i);
		Log.AssertNonNilAndType('tag', 'string', multitag);
		for tag in string.gmatch(multitag, "[^_]+") do
			table.insert(tags, i, tag);
			i = i + 1;
		end
	end
end

--[[ @brief Filters a list of functions based on their tags.
     @param functions An map of [function] = name entries to start with.
     @param tags An array of tags. Only functions which match all tags will be run.
     @param associations A map of the form [tag] = {functions...} indicating which tags are associated with which functions.
     @return A map of [function] = name entries.
--]]
function FilterList(functions, tags, associations)
	for _, tag in pairs(tags) do
		assert(associations[tag] ~= nil, string.format("Unrecognized tag: %s", tostring(tag)));
		local intersectedFunctions = {};
		for j, f in pairs(associations[tag]) do
			if functions[f] then
				intersectedFunctions[f] = functions[f];
			end
		end
		functions = intersectedFunctions;
	end
	return functions;
end

--[[ @brief Add a new function to this registry.
     @param i The list of tags associated with this function.
     @param v The function.
--]]
function TestRegistry:__newindex(i, v)
	assert(type(v)=='function', "Elements added to a test registry must be functions");
	Debug("Registering Function %s", i);
	self.FunctionNames[v] = i;
	for tag in string.gmatch(i, "[^_]+") do
		if self.Tags[tag] == nil then
			self.Tags[tag] = {};
		end
		table.insert(self.Tags[tag], v);
	end
end

--[[ @brief Executes the functions which match all given tags.
     @param tags... A list of tags to run.
--]]
function TestRegistry:__call(...)
	self._InitializeFunction();
	local tags = {...};
	local functions = self.FunctionNames;
	--If tags were provided, filter functions which don't match all tags.
	ExpandTags(tags);
	functions = FilterList(functions, tags, self.Tags);

	--Run all collected functions.
	for func, name in pairs(functions) do
		local args = {self._PrecedingFunction(name)};
		TestDebug("Running %s", name);
		func(unpack(args));
		TestDebug("Completed %s", name);
		if self.DelayTime > 0 then wait(self.DelayTime); end
	end
end

--[[ @brief Creates a new test registry.
     @details Add tests to a registry by creating new indices mapped to functions. For example: MyRegistry = TestRegistry.new(); MyRegistry.Test_Basic = function() ... end. In this example, "Test", and "Basic" are both tags belonging to this function. One could run it via: MyRegistry(), MyRegistry("Test"), MyRegistry("Test", "Basic"), MyRegistry("Basic"), or MyRegistry("Test_Basic").
--]]
function TestRegistry.new()
	return setmetatable({Tags = {--[[tag = {function, function, ...}]]}, FunctionNames = {--[[function = name]]}}, TestRegistry.Meta);
end

--[[ @brief Tests the TestRegistry framework.
     @details So meta.
--]]
function TestRegistry.test()
	local reg = TestRegistry.new();
	local x = 0;
	function reg.Test_Me()
		x = x + 1;
	end
	function reg.Nope()
		return;
	end
	Log.AssertEqual('x', 0, x);
	reg();
	Log.AssertEqual('x', 1, x);
	reg("Test");
	Log.AssertEqual('x', 2, x);
	reg("Me");
	Log.AssertEqual('x', 3, x);
	reg("Test", "Me");
	Log.AssertEqual('x', 4, x);
	reg("Test_Me");
	Log.AssertEqual('x', 5, x);
	reg("Nope");
	Log.AssertEqual('x', 5, x);
end

return TestRegistry;