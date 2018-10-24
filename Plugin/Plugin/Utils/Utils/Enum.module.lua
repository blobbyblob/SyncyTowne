local lib = script.Parent;
local Class = require(lib.Class);
local Log = require(lib.Log);

local Debug = Log.new("Benchmark:\t", true);

----------------
-- EnumOption --
----------------

local EnumOption = Class.new("EnumOption");

EnumOption._Name = "Enum"; --! A string associated with this EnumOption.
EnumOption._Value = 0; --! An integer for this EnumOption.
EnumOption._EnumType = false; --! The EnumClass associated with this EnumOption.

EnumOption.Get.Name = "_Name";
EnumOption.Get.Value = "_Value";
EnumOption.Get.EnumType = "_EnumType";

function EnumOption:Equals(other)
	if type(other) == 'string' then
		return other == self._Name;
	elseif type(other) == 'number' then
		return other == self._Value;
	else
		return other == self;
	end
end

function EnumOption:__tostring()
	return string.format("Enum.%s.%s", self._EnumType._Name, self._Name);
end

function EnumOption.new(string, number, parent)
	Log.AssertNonNilAndType("Name", "string", string);
	Log.AssertNonNilAndType("Value", "number", number);
	Log.AssertNonNilAndType("EnumType", "table", parent);
	local self = setmetatable({}, EnumOption.Meta);
	self._Name = string;
	self._Value = number;
	self._EnumType = parent;
	return self;
end

---------------
-- EnumClass --
---------------

local EnumClass = Class.new("EnumClass");

EnumClass._Name = "EnumClass"; --! The name of this EnumClass.
EnumClass._NameMap = false; --! A table mapping name --> EnumOption.
EnumClass._IndexMap = false; --! A table mapping number --> EnumOption.
EnumClass._OptionMap = false; --! A table mapping EnumOption --> EnumOption.

function EnumClass:__tostring()
	return self._Name;
end

function EnumClass:__index(i)
	return self._NameMap[i];
end

function EnumClass:GetEnumItems()
	local s = {};
	for i, v in pairs(self._IndexMap) do
		table.insert(s, v);
	end
	return s;
end

function EnumClass:InterpretEnum(name, input)
	if type(input) == 'number' then
		local retval = self._IndexMap[input];
		if retval then return retval; end
		Log.Error(2, "invalid number for enum %s; expected 1-%s, got %s", self._Name, #self._IndexMap, input);
	elseif type(input) == 'string' then
		local retval = self._NameMap[input];
		if retval then return retval; end
		local allValues = {};
		for name in pairs(self._NameMap) do
			table.insert(allValues, name);
		end
		Log.Error(2, "invalid string for enum %s; possible values {%s}, got %s", self._Name, table.concat(allValues, ", "), input);
	elseif type(input) == 'table' then
		local retval = self._OptionMap[input];
		if retval then return retval; end
		Log.Error(2, "invalid enum option for enum %s; got %s", self._Name, input);
	else
		Log.Error(2, "invalid value for enum %s; got %s (type %s)", self._Name, input, type(input));
	end
end

function EnumClass:ValidateEnum(input, name)
	Log.Warn("ValidateEnum(input, name) is deprecated in favor of InterpretEnum(name, input)")
	return self:InterpretEnum(name, input);
end

function EnumClass.new(name, ...)
	Log.AssertNonNilAndType("Name", "string", name);
	local args = {...};
	for i = 1, #args do
		Log.AssertNonNilAndType("Option " .. tostring(i), "string", args[i]);
	end
	local self = setmetatable({}, EnumClass.Meta);
	self._Name = name;
	self._NameMap = {};
	self._IndexMap = {};
	self._OptionMap = {};
	for i = 1, #args do
		local option = EnumOption.new(args[i], i, self);
		self._NameMap[args[i]] = option;
		self._IndexMap[i] = option;
		self._OptionMap[option] = option;
	end
	return self;
end

------------------------
-- EnumClassContainer --
------------------------

local EnumClassContainer = Class.new("EnumClassContainer");

EnumClassContainer._Enums = {}; --! A map of name --> enum.

function EnumClassContainer:GetEnums()
	local s = {};
	for i, v in pairs(self._Enums) do
		table.insert(s, v);
	end
	return s;
end

function EnumClassContainer:newEnumClass(name, ...)
	self:_RegisterEnumClass(EnumClass.new(name, ...));
end

function EnumClassContainer:_RegisterEnumClass(class)
	self._Enums[class._Name] = class;
end

function EnumClassContainer:__index(i)
	return self._Enums[i];
end

function EnumClassContainer:__tostring()
	return "Enums";
end

local x = EnumClassContainer.Meta;

function EnumClassContainer.new()
	local self = setmetatable({}, EnumClassContainer.Meta);
	self._Enums = {};
	return self;
end

function EnumClassContainer.newEnumClass(...)
	return EnumClass.new(...);
end

---------------
-- Test Code --
---------------

function EnumClassContainer.Test()
	local function subarray(t, i, j)
		local s = {};
		for k = i, j do
			table.insert(s, t[k]);
		end
		return s;
	end
	local Debug = Log.new("Enum:\t", true);

	Debug("Enum: %s", Enum);
	Debug("Enum:GetEnums(): %t", subarray(Enum:GetEnums(), 1, 1));
	Debug("Enum.AASamples: %s", Enum.AASamples);
	for i, v in pairs(Enum:GetEnums()) do
		Debug("%s: %t", v, v:GetEnumItems());
		break;
	end
	Debug("Enum.AASamples.None: %s", Enum.AASamples.None);

	Debug("SWITCHING TO CUSTOM ENUM CLASS");

	local Enum = EnumClassContainer.new();
	Enum:newEnumClass("AASamples", "None", "4", "8");

	Debug("Enum: %s", Enum);
	Debug("Enum:GetEnums(): %t", subarray(Enum:GetEnums(), 1, 1));
	Debug("Enum.AASamples: %s", Enum.AASamples);
	for i, v in pairs(Enum:GetEnums()) do
		Debug("%s: %t", v, v:GetEnumItems());
		break;
	end
	Debug("Enum.AASamples.None: %s", Enum.AASamples.None);
end


return EnumClassContainer;
