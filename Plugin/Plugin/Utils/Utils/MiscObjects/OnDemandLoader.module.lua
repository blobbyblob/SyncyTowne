--[[

This module allows you to pull dependencies as needed.
There are two classes: LibraryLoader, and ConstructorLoader.

LibraryLoader
	Properties:
		Submodules: a table mapping public library name to internal module name. E.g., "Math" --> "MathModuleScript".
		SearchDirectory: an object in which we search for modules.
		Recursive: whether we should search within our SearchDirectory recursively.
	Methods:
		__index(index): searches for a module & returns it if it exists; errors, otherwise.
	Constructors:
		new(): returns an object which allows indexing library components which are loaded on-demand.

ConstructorLoader:
	Properties:
		Classes: a table mapping ClassName --> {ModuleName, ConstructorName}. E.g., {Event = {"EventWrapper", "new"}}
			Alternately, ConstructorName can be true indicating that the module returns a function/functor which should serve as the constructor.
			Finally, the {ModuleName, CtorName} table can be simplified to just ModuleName if CtorName is just "new"
		SearchDirectory: an object in which we search for modules.
		Recursive: whether we should search within our SearchDirectory recursively.
	Constructors:
		new(): returns an object which allows constructing other classes which are loaded on-demand.

EventLoaderBuilder:
	This class allows you to configure an event loader once and create instantiations of it.
	Properties:
		Events: a list of event names.
		EventConstructor: a function which will generate a new event. By default, this is Utils.new["Event"].
	Methods:
		Instantiate(): returns an EventLoader with this configuration.
	Constructors:
		new(): returns a default EventLoaderBuilder.

EventLoader:
	This class will create events as needed.
	Methods:
		__index(index): if index matches an event name, it will be created, cached, and returned.
		FireEvent(event, ...): will trigger an event if it has been requested before.
		OnEventCreated(eventName): if an event is created for the first time, this callback is triggered.

The return value from this module contains the two constructors in this form:
	{newLibrary = LibraryLoader.new; newConstructor = ConstructorLoader.new; newEventLoader = EventLoaderBuilder.new}

--]]

local Class = require(script.Parent.Parent.Class);
local Log = require(script.Parent.Parent.Log);

local Debug = Log.new("OnDemandLoader: ", false);

local LibraryLoader = Class.new("LibraryLoader");

LibraryLoader._Submodules = false;
LibraryLoader._SearchDirectory = game;
LibraryLoader._Recursive = false;

LibraryLoader.Set.Submodules = "_Submodules";
LibraryLoader.Set.SearchDirectory = "_SearchDirectory";
LibraryLoader.Set.Recursive = "_Recursive";
LibraryLoader.Get.Submodules = "_Submodules";
LibraryLoader.Get.SearchDirectory = "_SearchDirectory";
LibraryLoader.Get.Recursive = "_Recursive";

function LibraryLoader:__index(index)
	if self._Submodules[index] then
		local moduleName = self._Submodules[index];
		local indexInModule;
		if type(moduleName) == "table" then
			moduleName, indexInModule = unpack(moduleName);
		end
		local module = self._SearchDirectory:FindFirstChild(moduleName, self._Recursive);
		if module then
			local retval = require(module);
			if retval then
				if indexInModule then
					rawset(self, index, retval[indexInModule]);
				else
					rawset(self, index, retval);
				end
				return rawget(self, index);
			else
				Log.Error("Module %s returned no values", moduleName);
			end
		else
			Log.Error("Could not find module %s in %s", moduleName, self._SearchDirectory);
		end
	else
		Log.Error("Unrecognized submodule: %s", index);
	end
end

function LibraryLoader:__newindex(index, value)
	rawset(self, index, value);
end

function LibraryLoader.new()
	local self = setmetatable({}, LibraryLoader.Meta);
	return self;
end

-----------------------
-- ConstructorLoader --
-----------------------

local ConstructorLoader = Class.new("ConstructorLoader");

ConstructorLoader._Classes = {};
ConstructorLoader._SearchDirectory = game;
ConstructorLoader._Recursive = false;

ConstructorLoader.Set.Classes = "_Classes";
ConstructorLoader.Set.SearchDirectory = "_SearchDirectory";
ConstructorLoader.Set.Recursive = "_Recursive";
ConstructorLoader.Get.Classes = "_Classes";
ConstructorLoader.Get.SearchDirectory = "_SearchDirectory";
ConstructorLoader.Get.Recursive = "_Recursive";

function ConstructorLoader:__index(index)
	local ctorDescriptor = self._Classes[index];
	if ctorDescriptor then
		--moduleName be one of the following forms:
		--{"SubmoduleName", "ConstructorName"}
		--"SubmoduleName"
		--{"SubmoduleName", true}
		local submoduleName, constructorName, moduleReturnsFunction, inferType = "", "new", false, false;
		if type(ctorDescriptor) == 'table' then
			Log.AssertNonNilAndType(string.format("Classes[%s]", index), "string", ctorDescriptor[1]);
			submoduleName = ctorDescriptor[1];
			if type(ctorDescriptor[2]) == 'string' then
				constructorName = ctorDescriptor[2];
			elseif type(ctorDescriptor[2]) == 'boolean' then
				moduleReturnsFunction = ctorDescriptor[2];
			else
				Log.AssertNonNilAndType(string.format("Classes[%s][2]", index), "string or boolean", ctorDescriptor[2]);
			end
		elseif type(ctorDescriptor) == 'string' then
			submoduleName = ctorDescriptor;
			inferType = true;
		else
			Log.AssertNonNilAndType(string.format("Classes[%s]", index), "table or string", ctorDescriptor);
		end

		local module = self._SearchDirectory:FindFirstChild(submoduleName, self._Recursive);
		if module then
			local retval = require(module);
			if retval then
				if inferType then
					if type(retval) == 'function' then
						moduleReturnsFunction = true;
					end
				end
				if moduleReturnsFunction then
					rawset(self, index, retval);
				elseif type(retval) == 'table' and retval[constructorName] then
					rawset(self, index, retval[constructorName]);
				else
					Log.Error("Module %s returns object of type %s which has no constructor %s", submoduleName, type(retval), constructorName);
				end
				return rawget(self, index);
			else
				Log.Error("Module %s returned no values", submoduleName);
			end
		else
			Log.Error("Could not find module %s in %s", submoduleName, self._SearchDirectory);
		end
	else
		Log.Error("Unrecognized ClassName: %s", index);
	end
end

function ConstructorLoader:__call(index, ...)
	return self[index](...);
end

function ConstructorLoader.new()
	local self = setmetatable({}, ConstructorLoader.Meta);
	self.new = function(index, ...)
		return self[index](...);
	end;
	return self;
end

-----------------
-- EventLoader --
-----------------

local EventLoader = Class.new("EventLoader");

EventLoader._EventMap = false; --! A map of [name] --> true for event names which are acceptable.
EventLoader._Ctor = false; --! The constructor to create new events.
EventLoader._BindableEvents = false; --! A map of [name] --> BindableEvent.
EventLoader._OnEventCreated = function() end --! A function called every time an event is created.

EventLoader.Get.OnEventCreated = "_OnEventCreated";
EventLoader.Set.OnEventCreated = "_OnEventCreated";

function EventLoader:__index(index)
	if self._EventMap[index] then
		local event = self._Ctor();
		rawset(self, index, event.Event);
		self._BindableEvents[index] = event;
		self._OnEventCreated(index);
		return rawget(self, index);
	else
		Log.Error("Invalid Event Name: %s", index);
	end
end

function EventLoader:FireEvent(eventName, ...)
	Debug("FireEvent(%s, %s, %t) called", self, eventName, {...});
	local event = self._BindableEvents[eventName];
	if event then
		event:Fire(...);
	end
end

function EventLoader:pairs()
	return pairs(self._BindableEvents);
end

function EventLoader.new(map, ctor)
	return setmetatable({_EventMap = map; _Ctor = ctor; _BindableEvents = {}}, EventLoader.Meta);
end

------------------------
-- EventLoaderBuilder --
------------------------

local EventLoaderBuilder = Class.new("EventLoaderBuilder");
EventLoaderBuilder._Events = false;
EventLoaderBuilder._EventConstructor = function() return Instance.new("BindableEvent"); end;
EventLoaderBuilder._EventMap = false;

EventLoaderBuilder.Set.Events = "_Events";
EventLoaderBuilder.Get.Events = "_Events";
EventLoaderBuilder.Set.EventConstructor = "_EventConstructor";
EventLoaderBuilder.Get.EventConstructor = "_EventConstructor";

function EventLoaderBuilder:Instantiate()
	if not self._EventMap then
		if self._Events then
			self._EventMap = {};
			for i, v in pairs(self._Events) do
				self._EventMap[v] = true;
			end
		else
			self._EventMap = setmetatable({}, {__index = function() return true; end});
		end
	end
	return EventLoader.new(self._EventMap, self._EventConstructor);
end

function EventLoaderBuilder:PopulateGetters(t, eventLoaderIndex)
	for i, eventName in pairs(self._Events) do
		t[eventName] = function(this)
			return this[eventLoaderIndex][eventName];
		end
	end
end

function EventLoaderBuilder.new()
	return setmetatable({}, EventLoaderBuilder.Meta);
end

----------
-- Test --
----------

function Test()
	--Test LibraryLoader
	local testLibLoader = LibraryLoader.new();
	testLibLoader.Submodules = {
		Math = "FunTimeLib";
		String = "BoringLib";
	};
	testLibLoader.SearchDirectory = Instance.new("Folder");
	local mathLib = Instance.new("ModuleScript", testLibLoader.SearchDirectory);
	mathLib.Source = "return {};";
	mathLib.Name = "FunTimeLib";
	local stringLib = Instance.new("ModuleScript", testLibLoader.SearchDirectory);
	stringLib.Source = "return {};";
	stringLib.Name = "BoringLib";
	Log.AssertEqual("testLibLoader.Math", require(testLibLoader.SearchDirectory.FunTimeLib), testLibLoader.Math);
	Log.AssertEqual("testLibLoader.String", require(testLibLoader.SearchDirectory.BoringLib), testLibLoader.String);

	--Test ConstructorLoader
	local lib = Instance.new("Folder");
	local libA = Instance.new("ModuleScript");
	libA.Name = "A";
	libA.Source = "return {new = function() return 'A'; end}";
	libA.Parent = lib;
	local libB = Instance.new("ModuleScript");
	libB.Name = "B";
	libB.Source = "return function() return 'B'; end";
	libB.Parent = lib;
	local libC = Instance.new("ModuleScript");
	libC.Name = "C";
	libC.Source = "return {customCtor = function() return 'C'; end; customCtor2 = function() return 'E'; end}";
	libC.Parent = lib;
	local libD = Instance.new("ModuleScript");
	libD.Name = "D";
	libD.Source = "return function() return 'D'; end";
	libD.Parent = lib;

	local testCtorLoader = ConstructorLoader.new();
	testCtorLoader.Classes = {
		a = "A";
		b = "B";
		c = {"C", "customCtor"};
		d = {"D", true};
		e = {"C", "customCtor2"};
	}
	testCtorLoader.SearchDirectory = lib;
	Log.AssertEqual('testCtorLoader.new("a")', "A", testCtorLoader.new("a"));
	Log.AssertEqual('testCtorLoader.new("b")', "B", testCtorLoader.new("b"));
	Log.AssertEqual('testCtorLoader.new("c")', "C", testCtorLoader.new("c"));
	Log.AssertEqual('testCtorLoader.new("d")', "D", testCtorLoader.new("d"));
	Log.AssertEqual('testCtorLoader.new("e")', "E", testCtorLoader.new("e"));

	--Test EventLoaderBuilder & EventLoader.
	local elb = EventLoaderBuilder.new();
	elb.Events = {"foo", "bar"};
	local el = elb:Instantiate();
	local fireCount = 0;
	el.foo:connect(function(...)
		fireCount = fireCount + 1;
	end)
	el:FireEvent("foo", "hello, world");
	el:FireEvent("bar", "leedle leedle leedle");
	el:FireEvent("foo", "hello, world");
	Log.AssertEqual("Calls to el.foo", 2, fireCount);
end

return {
	Test = Test;
	newLibrary = LibraryLoader.new;
	newConstructor = ConstructorLoader.new;
	newEventLoader = EventLoaderBuilder.new;
};

