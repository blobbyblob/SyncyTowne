--[[

The main driver for the plugin. This is the glue that holds everything together.

FilesystemModel: represents the truth of the filesystem.
StudioModel: represents the truth of studio.

When pulling, FilesystemModel is converted to a StudioModel and they are synced that way. When pushing, the reverse happens. Each model is responsible for doing its own Changed event to watch for changes.



--]]

--require(script.ProjectSync.StudioModel).Test();
--
--do return; end

local Utils = require(script.Parent.Utils);
local Debug = Utils.new("Log", "Plugin: ", true);
local SyncGui = require(script.SyncGui);
local ProjectManager = require(script.ProjectManager);

local gui = plugin:CreateDockWidgetPluginGui("SyncyTowne2", DockWidgetPluginGuiInfo.new());
gui.Title = "SyncyTowne";

local pm = ProjectManager.Load(game.ServerStorage:FindFirstChild("SyncyTowneData"));
pm.Changed:Connect(function()
	pm:Save(game.ServerStorage, "SyncyTowneData");
end);

local syncGui = SyncGui.new(pm);
syncGui.Frame.Parent = gui;
syncGui.RefreshCallback = function(project)
	Debug("RefreshCallback(%s) called", project);
	project.ProjectSync:CheckSync();
end;
syncGui.SyncCallback = function(mode, project, script)
	Debug("SyncCallback(%s, %s, %s) called", mode, project, script);
	if mode == "sync" then
		project.ProjectSync:SetAutoSync(script);
	elseif mode == "pull" then
		project.ProjectSync:Pull(script);
	elseif mode == "push" then
		project.ProjectSync:Push(script);
	end
end;
syncGui.DeleteCallback = function(project)
	Debug("DeleteCallback(%s) called", project);
	for i, v in pairs(pm.Projects) do
		if v == project then
			table.remove(pm.Projects, i);
			break;
		end
	end
	pm.Projects = pm.Projects;
end;
