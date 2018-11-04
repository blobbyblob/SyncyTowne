--[[

The main driver for the plugin. This is the glue that holds everything together.

FilesystemModel: represents the truth of the filesystem.
StudioModel: represents the truth of studio.

When pulling, FilesystemModel is converted to a StudioModel and they are synced that way. When pushing, the reverse happens. Each model is responsible for doing its own Changed event to watch for changes.



--]]

wait(2);

local Utils = require(script.Parent.Utils);
local SyncGui = require(script.SyncGui);
local ProjectManager = require(script.ProjectManager);

local gui = plugin:CreateDockWidgetPluginGui("SyncyTowne2", DockWidgetPluginGuiInfo.new());
gui.Title = "SyncyTowne";

local syncGui = SyncGui.new();
syncGui.Parent = gui;

local pm = ProjectManager.Load(game.ServerStorage:FindFirstChild("SyncyTowneData_Test"));
pm.Changed:Connect(function()
	pm:Save(game.ServerStorage, "SyncyTowneData_Test");
end);

syncGui.ProjectManager = pm;
