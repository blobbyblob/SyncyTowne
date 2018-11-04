--[[

The main driver for the plugin. This is the glue that holds everything together.

FilesystemModel: represents the truth of the filesystem.
StudioModel: represents the truth of studio.

When pulling, FilesystemModel is converted to a StudioModel and they are synced that way. When pushing, the reverse happens. Each model is responsible for doing its own Changed event to watch for changes.



--]]

wait(2);
require(script.ProjectSync.FilesystemModel).Test();

--Terminate early -- we're just here for the above test.
do return; end

local Utils = require(script.Parent.Utils);
local SyncGui = require(script.SyncGui);
local ProjectManager = require(script.ProjectManager);

local gui = get.Plugin:CreateDockWidgetPluginGui("SyncyTowne", DockWidgetPluginGuiInfo.new());
gui.Title = "SyncyTowne";

local syncGui = SyncGui.new();
syncGui.Parent = gui;

local pm = ProjectManager.Load();
pm.Changed:Connect(function()
	pm:Save();
end);
