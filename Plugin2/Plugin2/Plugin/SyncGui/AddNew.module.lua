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
local Debug = Utils.new("Log", "AddNew: ", false);
local ProjectSyncHelpers = require(script.Parent.Parent.ProjectSync.Helpers);
local GetPath = ProjectSyncHelpers.GetPath;
local SAVEABLE_SERVICES = ProjectSyncHelpers.SAVEABLE_SERVICES;
local Helpers = require(script.Parent.Helpers);

local ADD_NEW_GUI = script.AddNewContents;
local TOP_LEVEL_CLASSES = {
	Script = "Script";
	LocalScript = "Script";
	ModuleScript = "Script";
	Folder = true;
	Model = true;
};

local function GetFirstScript(root)
	--breadth first search for a script, module script, or local script.
	local t = {root};
	while #t > 0 do
		local v = t[1];
		if TOP_LEVEL_CLASSES[v.ClassName] == "Script" then
			return GetPath(root, v);
		end
		if v == game then
			for i, serviceName in pairs(SAVEABLE_SERVICES) do
				if game:GetService(serviceName) then
					table.insert(t, game:GetService(serviceName));
				end
			end
		else
			for i, v in pairs(v:GetChildren()) do
				table.insert(t, v);
			end
		end
		table.remove(t, 1);
	end
	return "";
end

local function ScrubRemote(text)
	--Remove leading and trailing slashes.
	return string.match(text, "^/*(.-)/*$");
end

local AddNew = Utils.new("Class", "AddNew");

AddNew._Frame = false;
AddNew._Maid = false;
AddNew._Local = false;
AddNew._Remote = false;
AddNew.ExitCallback = function()
	Debug("ExitCallback() invoked");
end;
AddNew.AddCallback = function(script, path)
	Debug("AddCallback(%s, %s) invoked", script, path);
end;
AddNew._Buttons = false;

AddNew.Get.Frame = "_Frame";

function AddNew:Destroy()
	self._Frame:Destroy();
end

function AddNew:_UpdateExample()
	if self._Remote and self._Local then
		self._Frame.Scroller.Example.Text = "Example: ~/" .. self._Remote .. "/" .. GetFirstScript(self._Local);
		self._Buttons.OK.Enabled = true;
	else
		self._Frame.Scroller.Example.Text = "";
		self._Buttons.OK.Enabled = false;
	end
end

function AddNew.new()
	local self = setmetatable({}, AddNew.Meta);
	self._Frame, self._Buttons = Helpers.FixImageButtons(ADD_NEW_GUI:Clone());
	self._Maid = Utils.new("Maid");
	local main = self._Frame.Scroller;
	self._Buttons.SelectLocal.OnClick = function()
		local selected = Utils.Table.Filter(game:GetService("Selection"):Get(), function(x) return TOP_LEVEL_CLASSES[x.ClassName]; end);
		self._Local = selected[1] or game;
		main.SelectLocal.Text = "Current Selection: " .. self._Local:GetFullName();
		self:_UpdateExample();
	end;
	self._Buttons.SelectLocal.OnClick();
	self._Maid.SelectRemoteCxn = main.SelectRemote.FocusLost:Connect(function(enterPressed)
		self._Remote = ScrubRemote(main.SelectRemote.Text);
		self:_UpdateExample();
	end);
	self._Buttons.OK.OnClick = function()
		if self._Local and self._Remote then
			self.AddCallback(self._Local, self._Remote);
			self.ExitCallback();
		end
	end;
	self._Buttons.Cancel.OnClick = function()
		self.ExitCallback();
	end;
	self:_UpdateExample();
	return self;
end

return AddNew;
