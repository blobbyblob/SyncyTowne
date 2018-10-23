Log = {};
Log.__index = Log;
Log.ClassName = 'LogStream';

local WARN_WARNING_STREAM = print;
local WARN_STACK_STREAM = print;
local REPAIR_TABS = true;
local typeof = type;

Log.Prefix = '';
Log.Shown = false;
Log.PrintStream = print; --Change this to use a different print stream.
Log.AppendNewline = false; --Set to true if all messages should have a newline automatically appended.

local function TableIsArray(t)
	local j = 0;
	for i, v in pairs(t) do
		if i ~= j + 1 then
			return false;
		end
		j = i;
	end
	return true;
end
local function TableHasSubTables(t)
	for i, v in pairs(t) do
		if type(v)=='table' then
			return true;
		end
	end
	return false;
end
local INDENT='    ';
local function TableToString(t, depth, mode, prefix, loopMap, tableName)
	depth = depth or 1;
	mode = mode or 1;
	prefix = prefix or '';
	loopMap = loopMap or {};
	tableName = tableName or 'root';
	if loopMap[t] then
		return 'table: ' .. loopMap[t];
	else
		loopMap[t] = tableName;
	end
	local s = {"{"};
	if TableIsArray(t) and (not TableHasSubTables(t) or depth==1) then
		local s2 = {};
		for i = 1, #t do
			table.insert(s2, tostring(t[i]));
		end
		s2 = table.concat(s2, ', ');
		if #s2 < 30 then
			table.insert(s, s2);
			table.insert(s, "}");
			return table.concat(s, ' ');
		end
	end
	for i, v in pairs(t) do
		if type(v) == 'table' then
			local hasToString = getmetatable(v) and getmetatable(v).__tostring;
			if mode == 1 and hasToString then
				--Mode = 1 means stop when we have a well-defined tostring.
			elseif mode == 0 and depth == 1 and hasToString then
				--Mode = 0 with depth = 1 means we're not planning to descend any farther. If we have a well-defined tostring, prefer it over a table-ish tostring.
			else
				if depth ~= 1 then
					v = TableToString(v, depth-1, mode, prefix..INDENT, loopMap, tableName .. '.' .. tostring(i));
				elseif loopMap[v] then
					v = 'table: ' .. loopMap[t];
				else
					local tableLen = #v;
					v = tostring(v);
					if v:sub(1,5)=='table' then
						v = string.format('table [%d]', tableLen) .. v:sub(6);
					end
				end
			end
		end
		table.insert(s, INDENT .. tostring(i) .. ' = ' .. tostring(v) .. ';');
	end
	table.insert(s, "}");
	return table.concat(s, "\n" .. prefix);
end

--[[ @brief Updates arguments in the args list to be strings if they are not.
     @details This function allows %s to be used in string s even if the corresponding argument is not a string or is nil.
     @param s The format string to consider.
     @param args The list of arguments we are substituting.
     @return The new format string to use.
--]]
function CorrectArguments(s, args)
	local i = 0;
	local function update(prefix, v)
		if v~="%" then
			i = i + 1;
			if v == "s" then
				if args[i]~=nil and type(args[i])~="string" then
					args[i] = tostring(args[i]);
				elseif args[i]==nil then
					args[i] = 'nil';
				end
			elseif v=="t" then
				local size, precision = string.gmatch(prefix, "%%(%d*)%.?(%d*)$")();
				local v = args[i];
				if v and type(v) == 'table' then
					args[i] = TableToString(v, tonumber(size), tonumber(precision));
				elseif v==nil then
					args[i] = 'nil';
				elseif typeof(v) == "Instance" and v:IsA("InputObject") then
					local base = string.format("InputObject<Type: %s, State: %s%%s>", v.UserInputType.Name, v.UserInputState.Name);
					if v.UserInputType == Enum.UserInputType.MouseButton1
							or v.UserInputType == Enum.UserInputType.MouseButton2
							or v.UserInputType == Enum.UserInputType.MouseButton3 then
						args[i] = string.format(base, "; " .. string.format("Position: <%s>", tostring(v.Position)));
					elseif v.UserInputType == Enum.UserInputType.MouseWheel
							or v.UserInputType == Enum.UserInputType.MouseMovement then
						args[i] = string.format(base, "; " .. string.format("Delta: <%s>, Position: <%s>", tostring(v.Delta), tostring(v.Position)));
					elseif v.UserInputType == Enum.UserInputType.Keyboard then
						args[i] = string.format(base, "; " .. string.format("KeyCode: %s", tostring(v.KeyCode.Name)));
					else
						args[i] = string.format(base, "");
					end
				elseif type(args[i]) ~= "string" then
					args[i] = tostring(args[i]);
				end
				return "%s";
			end
		end
		return prefix .. v;
	end
	return (string.gsub(s, "(%%%d*%.?%d*)([a-zA-Z%%])", update));
end

--[[ @brief Replaces tabs with four periods.
     @param str The string to fix.
--]]
local function RepairTabs(str)
	return (string.gsub(str, "\t", "...."));
end

--[[ @brief An iterator for a string which iterates at newlines.
     @param str The string to iterate on.
     @return A function which, each time it's called, returns a new line.
--]]
local function newlines(str)
	local index = 1;
	return function()
		if index > #str then
			return nil;
		end
		local i, j = string.find(str, "\r?\n", index);
		if not i then
			i, j = #str+1, #str;
		end
		local low = index;
		index = j+1;
		return string.sub(str, low, i - 1);
	end;
end

--[[ @brief Prepends the prefix to all lines.
     @param s String to prepend to.
     @param prefix String to prepend before each line.
     @return A string with prefix prepended to all lines.
--]]
function PrependPrefix(s, prefix)
	local t = {};
	for s in newlines(s) do
		table.insert(t, prefix .. s);
	end
	return table.concat(t, '\n');
end

--[[ @brief If the log is enabled, prints a message.
     @details Take note that this function will accept all string-type arguments for string.format. For example, Log("%s", nil) will print "nil" (it will not error), and Log("%s", {}) will print table: 0x01234567.
     @param str The format string to print.
     @param args... The arguments to pass to string.format.
--]]
function Log:__call(str, ...)
	if not self.Shown then
		return;
	end

	local args = {...};
	--Fix all nil/non-string arguments (where strings are expected).
	str = CorrectArguments(str, args);
	--Format the string.
	str = string.format(str, unpack(args));
	--Replace tabs with four periods if requested.
	if REPAIR_TABS then
		RepairTabs(str);
	end
	--Add the prefix to every line.
	str = PrependPrefix(str, self.Prefix);
	--Add a newline if necessary.
	if self.AppendNewline then
		str = str .. "\n";
	end
	--Print this ish.
	for s in newlines(str) do
		self.PrintStream(s);
	end
end

--[[ @brief Creates a new log stream. This can be enabled separately from all other streams, and all messages will be emitted with a prefix.
     @param prefix The prefix to add to all print messages.
     @shown Whether or not this is shown.
--]]
function Log.new(prefix, shown)
	local self = setmetatable({}, Log);
	self.Prefix = prefix;
	self.Shown = shown;
	return self;
end

--[[ @brief Emits an error if condition is false.
     @param condition The condition to check.
     @param message The message to throw if false.
     @return When condition evaluates truthily, all input will be returned.
--]]
function Log.Assert(condition, message, ...)
	if not condition then
		Log.Error(2, message, ...);
	else
		return condition, message, ...;
	end
end

--[[ @brief Emits an error if obj is nil or is not of type objType.
     @details This function is useful for input validation. Note: if a value can be of two types, type checking should occur outside of the function. It is still worth calling this function so that the error messages all align.
     @example function round(n, m) Log.AssertNonNilAndType("value", "number", n); Log.AssertNonNilAndType("rounding", "number", m or 1); ... end
     @example function variableInput(x) if type(x)~="number" and type(x)~="table" then Log.AssertNonNilAndType("x", "number or table", x); end ... end
     @param name The description to emit if this obj is not valid.
     @param objType The type we expect.
     @param obj The value we are checking.
--]]
function Log.AssertNonNilAndType(name, objType, obj)
	if obj==nil then
		Log.Error(2, "%s is nil", name);
	end
	if type(obj)~=objType then
		Log.Error(2, "invalid type for %s; expected %s, got %s", name, objType, type(obj));
	end
end

--[[ @brief Emits an error if expected does not equal actual.
     @details This function is useful for testing, as we know what values our elements should take.
     @param name The description of the object we are checking.
     @param expected The expected value for an object.
     @param actual The value we actually obtained.
--]]
function Log.AssertEqual(name, expected, actual)
	if expected ~= actual then
		Log.Error(2, "invalid value for %s; expected %s, got %s", name, expected, actual);
	end
end

--[[ @brief Emits an error if expected strays too far from actual.
     @param name The description of the object we are checking.
     @param expected The expected value for an object.
     @param tolerance The amount of variation from expected we will permit.
     @param actual The value we actually obtained.
]]
function Log.AssertAlmostEqual(name, expected, tolerance, actual)
	if type(expected)=='number' then
		if math.abs(expected - actual) > tolerance then
			Log.Error(2, "invalid value for %s; expected %s (+- %s), got %s", name, expected, tolerance, actual);
		end
	elseif type(expected)=='userdata' then
		if typeof(expected)=='Vector2' then
			return Log.AssertAlmostEqual(name..".x", expected.x, tolerance, actual.x) and Log.AssertAlmostEqual(name..".y", expected.y, tolerance, actual.y);
		end
	end
end

--[[ @brief Halts the program with a given error message.
     @param level The stack level to which the blame should be given. 1 is the function calling Error, 2 is the function calling that function, etc.
     @param str The error message to report (string formatting accepted)
     @param args... The string substitutions to make.
--]]
function Log.Error(level, str, ...)
	if type(level)=='string' then
		return Log.Error(2, level, str, ...);
	end
	Log.AssertNonNilAndType('Error level', 'number', level);
	Log.AssertNonNilAndType('Format string', 'string', str);
	local args = {...};
	str = CorrectArguments(str, args);
	error(string.format(str, unpack(args)), level+1);
end

--[[ @brief Emits a warning message.
     @param level The stack level to which the blame should be given. 1 is the function calling Error, 2 is the function calling that function, etc. A value of 0 means do not print the stack. This may be left out, in which case a default of 1 will be used.
     @param str The error message to report (string formatting accepted)
     @param args... The string substitutions to make.
--]]
function Log.Warn(level, str, ...)
	if type(level)=='string' then
		return Log.Warn(2, level, str, ...);
	end
	Log.AssertNonNilAndType('Error level', 'number', level);
	Log.AssertNonNilAndType('Format string', 'string', str);
	local tb = debug.traceback();
	local pos = 1;
	for i = 1, level+1 do
		pos = string.find(tb, '\n', pos, true);
		if pos then pos = pos + 1; else break; end
	end
	local args = {...};
	str = CorrectArguments(str, args);
	str = string.format(str, unpack(args));
	WARN_WARNING_STREAM(str);
	if level > 0 and pos then
		WARN_STACK_STREAM(tb:sub(pos));
	end
end

--[[ @brief Tests this module.
--]]
function Log.Test()
	local Debug = Log.new("Debug:\t", true);

	--These five lines have to be visually inspected.
	Debug("%s", nil);
	Debug("%s", 5.3);
	Debug("%s", {});
	Log.Warn(0, "A warning! %s", "warn");
	Log.Warn("A warning! %s", "warn");
	Debug("%t", {foo = "bar"});

	--Verify AssertEqual throws an error when the input arguments are not equal (error message doesn't so much matter); additionally, it should not throw an error message when input arguments are equal.
	local success, errorMsg = pcall(Log.AssertEqual, "NOPE", 1, 2);
	if success then error("AssertEqual did not throw an expected error."); end
	local success, errorMsg = pcall(Log.AssertEqual, "YEP", 1, 1);
	if not success then error("AssertEqual threw an unexpected error."); end

	--Verify AssertNonNilAndType responds appropriately to different styles of failure/success.
	local success, errorMsg = pcall(Log.AssertNonNilAndType, "a value", "number", "not a number, lol");
	if success then error("AssertNonNilAndType did not throw an expected error."); end
	local success, errorMsg = pcall(Log.AssertNonNilAndType, "a value", "number", nil);
	if success then error("AssertNonNilAndType did not throw an expected error."); end
	local success, errorMsg = pcall(Log.AssertNonNilAndType, "a value", "string", "yep, this is definitely a string.");
	if not success then error("AssertNonNilAndType threw an unexpected error."); end

	--Verify Error will actually stop execution.
	local success, errorMsg = pcall(Log.Error, "Error code: %s", nil)
	if success then error("Error did not throw an expected error."); end
end

Log.Debug = Log.new("Debug:\t", true);

return Log;
