--[[

Creates a GUI to show active projects. A status indicator, if you will.

Properties:
	Frame (read-only): the top-level frame that this UI is placed in.
	ProjectManager (read-only): the thing which manages all the projects in a given game.
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

Free Functions:
	Test(): self-tests the class.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "SyncGui: ", false);
local ProjectManager = require(script.Parent.ProjectManager);
local Main = require(script.Main);
--local AddNew = require(script.AddNew);
--local Options = require(script.Options);
--local ProjectDetails = require(script.ProjectDetails);

local TOP_LEVEL_FRAME = Instance.new("Frame");
TOP_LEVEL_FRAME.Name = "SyncGui";
TOP_LEVEL_FRAME.BackgroundTransparency = 1;
TOP_LEVEL_FRAME.ClipsDescendants = true;
TOP_LEVEL_FRAME.Size = UDim2.new(1, 0, 1, 0);

local SyncGui = Utils.new("Class", "SyncGui");

SyncGui._Frame = false;
SyncGui._ProjectManager = false;
SyncGui._Maid = false;

SyncGui._Main = false;

SyncGui.Get.Frame = "_Frame";
SyncGui.Get.ProjectManager = "_ProjectManager";

--Pass-through properties for Main.
SyncGui.Set.SyncCallback = function(self, v) self._Main.SyncCallback = v; end;
SyncGui.Get.SyncCallback = function(self) return self._Main.SyncCallback; end;
SyncGui.Set.ConnectionStatus = function(self, v) self._Main.ConnectionStatus = v; end;
SyncGui.Get.ConnectionStatus = function(self) return self._Main.ConnectionStatus; end;
SyncGui.Set.RefreshCallback = function(self, v) self._Main.RefreshCallback = v; end;
SyncGui.Get.RefreshCallback = function(self) return self._Main.RefreshCallback; end;
SyncGui.Set.DeleteCallback = function(self, v) self._Main.DeleteCallback = v; end;
SyncGui.Get.DeleteCallback = function(self) return self._Main.DeleteCallback; end;

function SyncGui:Destroy()
	self._Frame:Destroy();
	self._Maid:Destroy();
end

function SyncGui.new(pm)
	local self = setmetatable({}, SyncGui.Meta);
	self._Frame = TOP_LEVEL_FRAME:Clone();
	self._Maid = Utils.new("Maid");
	self._ProjectManager = pm;
	self._Main = Main.new(pm);
	self._Main.Frame.Parent = self._Frame;
	return self;
end

function SyncGui.Test()
	--We'll create a new SyncGui & throw it in StarterGui for viewing.
	wait(.1);
	local pm = ProjectManager.Load(game.ServerStorage:FindFirstChild("SyncyTowneData")); --TODO: make this constant.
	while game.StarterGui:FindFirstChild("SyncyTowneGui") do
		game.StarterGui.SyncyTowneGui:Destroy();
	end
	local sgui = Instance.new("ScreenGui");
	sgui.Name = "SyncyTowneGui";
	sgui.Archivable = false;
	sgui.Parent = game.CoreGui;

	local f = Instance.new("Frame");
	local sg = SyncGui.new(pm);
	if false then
		f.Size = UDim2.new(.8, 0, .8, 0);
		f.Position = UDim2.new(.5, 0, .5, 0);
		f.AnchorPoint = Vector2.new(.5, .5);
		f.Parent = sgui;
		sg.Frame.Parent = f;
	else
		sg.Frame.Size = UDim2.new(.8, 0, .8, 0);
		sg.Frame.Position = UDim2.new(.5, 0, .5, 0);
		sg.Frame.AnchorPoint = Vector2.new(.5, .5);
		sg.Frame.Parent = sgui;
	end

	sg.RefreshCallback = function(project)
		project.ProjectSync:CheckSync();
	end;
	sg.SyncCallback = function(mode, project, script)
		if mode == "sync" then
			project.ProjectSync:SetAutoSync(script);
		elseif mode == "pull" then
			project.ProjectSync:Pull(script);
		elseif mode == "push" then
			project.ProjectSync:Push(script);
		end
	end;
end

return SyncGui;
