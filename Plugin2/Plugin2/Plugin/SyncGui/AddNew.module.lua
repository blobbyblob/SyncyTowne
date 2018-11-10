--[[

Properties:
	Frame (Frame, read-only): the frame that contains all project info.
	SyncCallback (function(mode, project[, script])): a function which is called when the sync button is pressed. This is generic to whether it is a push/pull/auto-sync being set.
		mode: One of the following three strings: "push", "pull", "sync".
		project: The project which the button was pressed for.
		script: the script we should be syncing. If nil, it indicates that we should push/pull/sync everything. This must be nil if the mode is "sync".
	ConnectionStatus (boolean): set to true to indicate that we are connected.
	RefreshCallback (function(project)): a function which is called when the refresh button is pressed.
		project: the project which the user requested to refresh. This may be nil, indicating that the user wants to refresh everything.

Methods:
	Destroy(): cleans everything up.

Events:

Constructors:
	new(pm): creates a new SyncGui that uses a particular ProjectManager.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "AddNew: ", true);

local ADD_NEW_GUI = script.AddNewContents;

local AddNew = Utils.new("Class", "AddNew");

AddNew._Frame = false;

function AddNew.new()
	local self = setmetatable({}, AddNew.Meta);
	self._Frame = ADD_NEW_GUI:Clone();
	return self;
end

return AddNew;
