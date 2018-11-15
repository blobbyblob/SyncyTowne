--[[

Displays information for a single project.

Properties:
	Frame (read-only): the top-level frame which hosts all the information.

Methods:
	Destroy(): cleans everything up.

Constructors:
	new(project, syncMode): creates a new ProjectDetails screen for a particular project (containing keys Remote, Local, and ProjectSync).
		project: the project to display.
		syncMode: when true, only mismatching files will be displayed.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "ProjectDetails: ", false);
local Helpers = require(script.Parent.Helpers);

local PROJECT_DETAILS_GUI = script.ProjectDetailsContents;
local SCRIPT_ENTRY = PROJECT_DETAILS_GUI.Scroller.ScriptEntry;
SCRIPT_ENTRY.Parent = nil;

local LIST_BACKGROUND_COLORS = {
	[0] = Color3.fromRGB(199, 246, 255);
	Color3.fromRGB(255, 255, 255);
};

local ProjectDetails = Utils.new("Class", "ProjectDetails");

ProjectDetails._Frame = false;
ProjectDetails._Maid = false;
ProjectDetails._Project = false;
ProjectDetails._ShowDifferencesOnly = false;
ProjectDetails._FilePathMap = false; --maps [filepath] -> [gui row]
ProjectDetails.SyncCallback = function(mode, project, script)
	Debug("SyncCallback(%s, %s, %s) invoked", mode, project, script);
end;
ProjectDetails.RefreshCallback = function(project)
	Debug("RefreshCallback(%s) invoked", project);
end;
ProjectDetails.DeleteCallback = function(project)
	Debug("DeleteCallback(%s) invoked", project);
end;
ProjectDetails._Buttons = {};
ProjectDetails._FileGuis = {};

ProjectDetails.Get.Frame = "_Frame";

function ProjectDetails:Destroy()
	self._Maid:Destroy();
end

function ProjectDetails:_UpdateButtons()
	Debug("DifferenceCount: %s", self._Project.ProjectSync.DifferenceCount);
	local differenceExists = self._Project.ProjectSync.DifferenceCount ~= 0;
	self._Buttons.AutoSync.Selected = self._Project.ProjectSync.AutoSync;
	self._Buttons.AutoSync.Enabled = not differenceExists;
	self._Buttons.Push.Enabled = differenceExists;
	self._Buttons.Pull.Enabled = differenceExists;
	self:_RecreateRows();
end

function ProjectDetails:_RecreateRows()
	for i, v in pairs(self._FileGuis) do
		v:Destroy();
	end

	local j = 2;
	self._FileGuis = {};
	for i, file, script, difference in self._Project.ProjectSync:Iterate() do
		if not self._ShowDifferencesOnly or difference ~= "SourceEqual" then
			local entry, buttons = Helpers.FixImageButtons(SCRIPT_ENTRY:Clone());
			entry.FilePath.Text = file or "";
			entry.ScriptPath.Text = script and script:GetFullName() or "";
			entry.Parent = self._Frame.Scroller;
			entry.LayoutOrder = j;
			entry.BackgroundColor3 = LIST_BACKGROUND_COLORS[j % 2]
			buttons.Pull.OnClick = function( )
				self.SyncCallback("pull", self._Project, file or script);
			end;
			buttons.Push.OnClick = function()
				self.SyncCallback("push", self._Project, file or script);
			end;
			Debug("Difference: %s", difference);
			if difference == "SourceEqual" then
				buttons.Pull.Enabled = false;
				buttons.Push.Enabled = false;
			end
			self._FileGuis[#self._FileGuis + 1] = entry;
			j = j + 1;
		end
	end
	local function GetRequiredHeight(first, last)
		if not first or not last then return 0; end
		return (last.AbsolutePosition - first.AbsolutePosition + last.AbsoluteSize).y
	end
	self._Frame.Scroller.CanvasSize = UDim2.new(0, 0, 0, GetRequiredHeight(self._Frame.Scroller.SyncHelp, self._FileGuis[#self._FileGuis]));
end

function ProjectDetails.new(ps, syncMode)
	local self = setmetatable({}, ProjectDetails.Meta);
	self._Maid = Utils.new("Maid");
	self._Frame, self._Buttons = Helpers.FixImageButtons(PROJECT_DETAILS_GUI:Clone());
	self._Project = ps;
	self._FilePathMap = {};
	self._ShowDifferencesOnly = syncMode;
	if syncMode then
		self._Buttons.AutoSync.Button:Destroy();
		self._Buttons.Delete.Button:Destroy();
		self._Frame.Scroller.SyncHelp.Visible = true;
		for i, v in pairs({"Refresh", "Push", "Pull"}) do
			self._Buttons[v].Button.Position = self._Buttons[v].Button.Position + UDim2.new(0, 34, 0, 0);
		end
	end
	self._Buttons.AutoSync.OnClick = function()
		self.SyncCallback("sync", self._Project, not self._Project.ProjectSync.AutoSync);
	end;
	self._Buttons.Refresh.OnClick = function()
		self.RefreshCallback(self._Project);
	end;
	self._Buttons.Pull.OnClick = function( )
		self.SyncCallback("pull", self._Project);
	end;
	self._Buttons.Push.OnClick = function()
		self.SyncCallback("push", self._Project);
	end;
	self._Buttons.Delete.OnClick = function()
		self.DeleteCallback(self._Project);
	end;
	self._Frame.Header.Title.Text = ps.Remote;
	self._Maid.ProjectSyncChanged = ps.ProjectSync.Changed:Connect(function(property)
		Debug("ProjectSync.%s Changed to %s", property, ps.ProjectSync[property]);
		if property == "DifferenceCount" then
			self:_UpdateButtons();
		elseif property == "AutoSync" then
			self:_UpdateButtons();
		end
	end);
	self:_UpdateButtons();
	return self;
end

return ProjectDetails;

