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
local Debug = Utils.new("Log", "Main: ", true);
local AddNew = require(script.Parent.AddNew);
local SubscreenWrapper = require(script.Parent.SubscreenWrapper);
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
Main._Subpage = false;

Main._Maid = false;
Main._ProjectGuis = {};

Main.Get.Frame = "_Frame";
Main.Get.SyncCallback = "_SyncCallback";
Main.Set.SyncCallback = "_SyncCallback";
Main.Get.ConnectionStatus = "_ConnectionStatus";
Main.Set.ConnectionStatus = "_ConnectionStatus";
Main.Get.RefreshCallback = "_RefreshCallback";
Main.Set.RefreshCallback = "_RefreshCallback";

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
		buttons.OnClick = function()
			self._SyncCallback("sync", project);
		end;
	end
	self._Frame.ScrollContent.CanvasSize = UDim2.new(0, 0, 0, (self._ProjectGuis[#self._ProjectGuis].AbsolutePosition - self._Frame.ScrollContent.AbsolutePosition + self._ProjectGuis[#self._ProjectGuis].AbsoluteSize).y);
end

function Main:Destroy()
	self._Frame:Destroy();
	self._Maid:Destroy();
end

function Main.new(pm)
	local self = setmetatable({}, Main.Meta);
	self._Frame, self._Buttons = FixImageButtons(MAIN_GUI:Clone(), self._Maid);
	self._Maid = Utils.new("Maid");
	self._ProjectGuis = {};

	self:_CreateAllProjects(pm);
	self._Maid.ProjectManagerChanged = pm.Changed:Connect(function(property)
		if property == "Projects" then
			self:_CreateAllProjects(pm);
		end
	end);
	self._Buttons.Add.OnClick = function()
		local sub = SubscreenWrapper.new();
		sub.Title = "Add New";
		sub.ExitCallback = function()
			self._Frame:TweenPosition(UDim2.new(), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
			sub.Frame:TweenPosition(UDim2.new(self._Frame.Size.X, UDim.new()), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
			spawn(function()
				wait(PAGE_TIME);
				self._Maid.Subscreen = nil;
			end);
		end;
		self._Frame:TweenPosition(UDim2.new(-self._Frame.Size.X, UDim.new()), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);
		sub.Frame.Position = UDim2.new(sub.Frame.Size.X, UDim.new());
		sub.Frame.Parent = self._Frame.Parent;
		sub.Frame:TweenPosition(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, PAGE_TIME, true);

		local add = AddNew.new();
		self._Subpage = add;
		sub.SubscreenFrame = add.Frame;
		add.ExitCallback = sub.ExitCallback;
		add.AddCallback = function(script, filepath)
			table.insert(pm.Projects, {
				Local = script;
				Remote = filepath;
				Exceptions = {};
			});
			pm.Projects = pm.Projects;
		end;

		self._Maid.Subscreen = function()
			sub:Destroy();
			add:Destroy();
		end;
	end
	return self;
end

return Main;
