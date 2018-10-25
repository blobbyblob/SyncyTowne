--[[

A library through which requests to the webserver can be made.



--]]

local module = {}

function module.RegisterCommand(commandDef)
	local name = commandDef.Name;
	local args = commandDef.Arguments;
	local responseArgs = commandDef.ResponseArguments;
	--validate the input and throw them into some sort of registry.
end



return module
