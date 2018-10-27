--[[

Contains functions to execute all relevant commands against the command server.

--]]

local Utils = require(script.Parent.Parent.Utils);
local RequestWrapper = require(script.RequestWrapper);
local Debug = Utils.new("Log", "ServerRequests: ", true);

local ServerRequests = {};

local requestWrapper = RequestWrapper.new();
commands = game:GetService("HttpService"):JSONDecode(require(script.Commands));
for i, v in pairs(commands.Commands) do
	requestWrapper:RegisterCommand(v);
	ServerRequests[v.Name] = requestWrapper.Commands[v.Name];
end

function ServerRequests.Test()
	ServerRequests.read{File="foo"}
end

return ServerRequests;

