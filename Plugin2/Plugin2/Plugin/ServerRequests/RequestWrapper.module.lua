--[[

A command registry for HTTP request/response operations.

This provides argument verification to/from.

Properties:
	Commands (read-only): a map of [commandName] -> [function to send the
		command]. This gets populated by RegisterCommand. The function takes
		one argument which is a table that has key/value pairs for the command's
		arguments. The function's return values are: (boolean, table) where the
		boolean indicates if the request succeeded & the table provides all
		arguments returned by the server. If boolean is false, table will
		instead be an error string.
	DestinationAddress (string): the URL on which our webserver is running.
	DestinationPort (number): the port on which our webserver is running.

Methods:
	RegisterCommand(commandDefinition): registers a command so it can be sent
		out.

Events:

Constructors:
	new(): basic default constructor.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "RequestWrapper: ", true);

--A mapping of acceptable outgoing property type to a function that converts it
--to a string.
local REQUEST_ARG_TYPES = {};

--A mapping of acceptable incoming property type to a function that converts it
--from a string to a native value.
local RESPONSE_ARG_TYPES = {};

--[[ @brief Verifies that a definition for a command's arguments is suitable.

	Primary, this means that there are no two arguments with the same name, and
	the types are all valid.

	This function will throw if any errors occur.

	@param def The definition of the arguments that this function takes.
	@param validArgs A map of [valid arg types] -> [something truthy] which is
		used to determine if an argument type is supported. Sensible choices for
		this value are the two maps above (REQUEST_ARG_TYPES and
		RESPONSE_ARG_TYPES).
--]]
local function ValidateArgDef(def, validArgs)

end
--[[ @brief Verifies that arguments are all correct & turns them into a string.
	@param def The arguments definition (a list of tables, each containing
		"Name" and "Type" keys).
	@param args The arguments to be converted to strings.
	@return[1] true
	@return[1] A block of text representing all the arguments.
	@return[2] false
	@return[2] The error string.
--]]
local function ArgumentsToString(def, args)

end
--[[ @brief Converts a block of text into distinct arguments.
	@param def The argument definition used to uncode the text.
	@param text A block of text containing all arguments.
	@return[1] true
	@return[1] A table with keys for each return argument.
	@return[2] false
	@return[2] The error string.
--]]
local function StringToArguments(def, text)

end
--[[ @brief Issues a command against the remote HTTP server.
	@param cmd The command we are issuing.
	@param args The arguments for this command.
	@return[1] true
	@return[1] A string response provided by the server.
	@return[2] false
	@return[2] The error string.
--]]
local function IssueCommand(cmd, args)

end

local RequestWrapper = Utils.new("Class", "RequestWrapper");

RequestWrapper._Commands = {};
RequestWrapper.DestinationAddress = "localhost";
RequestWrapper.DestinationPort = 605;

RequestWrapper.Get.Commands = "_Commands";

--[[ @brief Registers a command so it may be sent to the server.
	@param commandDef A definition of a command. This is a Lua table
		representation of one of the command definitions that can be found in
		commands.json.
		It should have three keys:
		 * Name: the name of the command.
		 * Arguments: a list of the arguments sent to the server.
		 * ResponseArguments: a list of the arguments received by the server.
		Each argument is defined as a map with the following two keys.
		 * Name: the name of the argument.
		 * Type: the type of the argument. This can have the following values
		   (all are strings):
			 * FilePath: the path to a file. Directory separators are given as
			   forward slashes "/" and no hidden directories are permitted
			   (those beginning in "."). Additionally, one can't traverse up a
			   directory using ".."
			 * Number: a number.
			 * Boolean: a true/false value.
			 * String: a string.
			 * *: an argument meaning "a multi-line string".
	@post A command will be found at self.Commands[commandName] to issue this
		command to the server.
--]]
function RequestWrapper:RegisterCommand(commandDef)
	local name = commandDef.Name;
	local argsDef = commandDef.Arguments;
	local responseArgsDef = commandDef.ResponseArguments;
	ValidateArgDef(argsDef, REQUEST_ARG_TYPES);
	ValidateArgDef(responseArgsDef, RESPONSE_ARG_TYPES)
	--validate the input and throw them into some sort of registry.
	self._Commands[name] = function(args)
		local success, argsString = ArgumentsToString(argsDef, args);
		if not success then
			local errString = argsString;
			Debug("Failure to send command %s due to invalid arguments: %s", name, errString);
			return success, errString;
		end

		--Issue the call to the server.
		local success, response = IssueCommand(name, argsString);
		if not success then
			local errString = argsString;
			Debug("Failure to send command %s due to HTTP failure: %s", name, errString);
			return success, errString;
		end

		--Parse what the server provided back into table form.
		local success, responseArgs = StringToArguments(responseArgsDef, response);
		if not success then
			local errString = argsString;
			Debug("Failure to send command %s due to bad arguments from server: %s", name, errString);
			return success, errString;
		end

		return success, responseArgs;
	end
end

function RequestWrapper.new()
	local self = setmetatable({}, RequestWrapper.Meta);
	self._Commands = {};
	return self;
end

function RequestWrapper.Test()

end

return module
