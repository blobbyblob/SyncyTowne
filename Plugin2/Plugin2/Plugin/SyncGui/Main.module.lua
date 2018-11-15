--[[


Properties:
	Frame (Frame, read-only): the frame that contains all project info.
	SyncCallback (function(mode, project[, script])): a function which is called when the sync button is pressed. This is generic to whether it is a push/pull/auto-sync being set.
		mode: One of the following three strings: "push", "pull", "sync".
		project: The project which the button was pressed for.
		script: the script we should be syncing. If nil, it indicates that we should push/pull/sync everything. If the mode is "sync", this can be true or false (indicating whether we want auto-sync on or off).
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
local Debug = Utils.new("Log", "Main: ", true);
local AddNew = require(script.Parent.AddNew);
local SubscreenWrapper = require(script.Parent.SubscreenWrapper);
local ProjectDetails = require(script.Parent.ProjectDetails);
local Helpers = require(script.Parent.Helpers);

local FixImageButtons = Helpers.FixImageButtons;

local MAIN_GUI = script.Main;
MAIN_GUI.Visible = true;
local PROJECT_ENTRY = MAIN_GUI.ScrollContent.ProjectEntry;
PROJECT_ENTRY.Parent = nil; --We will instantiate these later -- one per project.
local PAGE_TIME = .2;

local LIST_BACKGROUND_COLORS = {
	[0] = Color3.fromRGB(255, 255, 255);
	Color3.fromRGB(199, 246, 255);
};

local Main = Utils.new("Class", "Main");

Main._Frame = false;
Main._SyncCallback = function(mode, project, script) Debug("SyncCallback(%s, %s, %s) invoked", mode, project, script); end;
Main._ConnectionStatus = false;
Main._RefreshCallback = function(project) Debug("RefreshCallback(%s) invoked", project); end;
Main._CloseSubpage = function() end;

Main._Maid = false;
Main._ProjectGuis = {};

Main.Get.Frame = "_Frame";
Main.Get.SyncCallback = "_SyncCallback";
Main.Set.SyncCallback = "_SyncCallback";
Main.Get.ConnectionStatus = "_ConnectionStatus";
Main.Set.ConnectionStatus = "_ConnectionStatus";
Main.Get.RefreshCallback = "_RefreshCallback";
Main.Set.RefreshCallback = "_RefreshCallback";
Main.Get.DeleteCallback = "_DeleteCallback";
Main.Set.DeleteCallback = "_DeleteCallback";

function Main:_CreateAllProjects(pm)
	for i, v in pairs(self._ProjectGuis) do
		v:Destroy();
	end
	self._ProjectGuis = {};
	for i, project in pairs(pm.Projects) do
		Debug("Creating Gui for %s", project);
		local g, buttons = FixImageButtons(PROJECT_ENTRY:Clone(), self._Maid);
		table.insert(self._ProjectGuis, g);
		g.FilePath.Text = project.Remote;
		g.ScriptPath.Text = project.Local:GetFullName();
		g.BackgroundColor3 = LIST_BACKGROUND_COLORS[(i-1)%2];
		g.LayoutOrder = i;
		g.Parent = self._Frame.ScrollContent;
		buttons.Sync.OnClick = function()
			--If the project has any differences, first open the sync screen. Otherwise, just start auto-sync.
			if project.ProjectSync.DifferenceCount > 0 then
				local pd = ProjectDetails.new(project, true);
				pd.SyncCallback = self._SyncCallback;
				pd.RefreshCallback = self._RefreshCallback;
				self:_SetSubpage(pd, "Resolve Conflicts");

				--Listen for all conflicts being resolved.
				self._Maid.Subpage.CloseWhenDifferenceCountDropsToZero = project.ProjectSync.Changed:Connect(function(property)
					if property == "DifferenceCount" then
						if project.ProjectSync.DifferenceCount == 0 then
							self._CloseSubpage();
							self._Maid.Subpage.CloseWhenDifferenceCountDropsToZero = nil;
							self._SyncCallback("sync", project, true);
						end
					end
				end);
			else
				self._SyncCallback("sync", project, not project.ProjectSync.AutoSync);
			end
		end;
		self._Maid[g] = Utils.new("Maid");
		self._Maid[g].AutoSyncChanged = project.ProjectSync.Changed:Connect(function(property)
			if property == "AutoSync" then
				buttons.Sync.Selected = project.ProjectSync.AutoSync;
			end
		end);
		self._Maid[g].BackdropClicked = g.MouseButton1Click:Connect(function()
			local pd = ProjectDetails.new(project, false);
			pd.SyncCallback = self._SyncCallback;
			pd.RefreshCallback = self._RefreshCallback;
			pd.DeleteCallback = function(...)
				self._CloseSubpage();
				self._DeleteCallback(...);
			end;
			self:_SetSubpage(pd, "Project Details");
		end);
	end
	local function GetRequiredHeight(first, last)
		if not first or not last then return 0; end
		return (last.AbsolutePosition - first.AbsolutePosition + last.AbsoluteSize).y
	end
	self._Frame.ScrollContent.CanvasSize = UDim2.new(0, 0, 0, GetRequiredHeight(self._ProjectGuis[1], self._Frame.ScrollContent.Add));
	Debug("Required Height: %s", self._Frame.ScrollContent.CanvasSize.Y.Offset);
end

function Main:Destroy()
	self._Frame:Destroy();
	self._Maid:Destroy();
end

--[[ @brief "Opens" a subpage for viewing.

	This page will slide in from the right.

	As a postcondition, when this function is complete, the main frame (project list) will not be
	visible. A function "self._CloseSubpage" will be assigned which nicely tweens Main back into
	position. `self._Maid.Subpage` will be set to a maid that gets cleaned up when the subpage
	completely exits the view.

	@param subpage The subpage to open. It should have:
		* Property "Frame"
		* Method "Destroy"
	@param title The title of this subpage.
--]]
function Main:_SetSubpage(subpage, title)
	self._Maid.Subpage = nil;

	local sub = SubscreenWrapper.new();
	sub.Title = title;
	self._Frame:TweenPosition(UDim2.new(-self._Frame.Size.X, UDim.new()), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
	sub.Frame.Position = UDim2.new(sub.Frame.Size.X, UDim.new());
	sub.Frame.Parent = self._Frame.Parent;
	sub.Frame:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);

	sub.SubscreenFrame = subpage.Frame;

	local function TweenBack()
		self._Frame:TweenPosition(UDim2.new(), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
		sub.Frame:TweenPosition(UDim2.new(self._Frame.Size.X, UDim.new()), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
		local subscreen = self._Maid.Subpage;
		spawn(function()
			wait(PAGE_TIME);
			if self._Maid.Subpage == subscreen then
				self._Maid.Subpage = nil;
			end
		end);
	end
	self._CloseSubpage = function()
		if TweenBack then
			local f = TweenBack;
			TweenBack = nil;
			f();
		end
	end;
	sub.ExitCallback = self._CloseSubpage;

	self._Maid.Subpage = Utils.new("Maid");
	self._Maid.Subpage.DestroyFrames = function()
		sub:Destroy();
		subpage:Destroy();
	end;
	self._Maid.Subpage.ClearTweenFunction = function()
		TweenBack = nil;
	end;
end

function Main:_WatchConnections(pm)
	local function AggregateConnectedStatus()
		local connected, disconnected = 0, 0;
		for i, project in pairs(pm.Projects) do
			if project.ProjectSync.Connected then
				connected = connected + 1;
			else
				disconnected = disconnected + 1;
			end
		end
		Debug("%s projects are connected; %s are disconnected", connected, disconnected);
		if disconnected == 0 then
			--We're good. Or we're trivially good (nothing connected because we don't have any projects).
			self._Frame.TopBar.Refresh.CenteredImage.ImageRectOffset = Vector2.new(17, 0);
		elseif connected ~= 0 then
			--We're somewhat good. Something's disconnected.
			self._Frame.TopBar.Refresh.CenteredImage.ImageRectOffset = Vector2.new(34, 0);
		elseif connected == 0 then
			--We're very bad. Everything's disconnected.
			self._Frame.TopBar.Refresh.CenteredImage.ImageRectOffset = Vector2.new(34, 0);
		end
	end
	self._Maid.Connections = Utils.new("Maid");
	for i, project in pairs(pm.Projects) do
		self._Maid.Connections[project] = project.ProjectSync.Changed:Connect(function(property)
			if property == "Connected" then
				AggregateConnectedStatus();
			end
		end);
	end
	AggregateConnectedStatus();
end

function Main.new(pm)
	local self = setmetatable({}, Main.Meta);
	self._Frame, self._Buttons = FixImageButtons(MAIN_GUI:Clone(), self._Maid);
	self._Maid = Utils.new("Maid");
	self._ProjectGuis = {};

	self:_CreateAllProjects(pm);
	self:_WatchConnections(pm);
	self._Maid.ProjectManagerChanged = pm.Changed:Connect(function(property)
		if property == "Projects" then
			self:_CreateAllProjects(pm);
			self:_WatchConnections(pm);
		end
	end);
	self._Buttons.Add.OnClick = function()
		local add = AddNew.new();
		self:_SetSubpage(add, "Add New");
		add.ExitCallback = self._CloseSubpage;
		add.AddCallback = function(script, filepath)
			table.insert(pm.Projects, {
				Local = script;
				Remote = filepath;
				Exceptions = {};
			});
			pm.Projects = pm.Projects;
		end;
	end
	self._Buttons.Refresh.OnClick = function()
		self._RefreshCallback();
	end
	return self;
end

return Main;
