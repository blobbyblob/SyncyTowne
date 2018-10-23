--[[

Boots the plugin. To test:
	local _=(_G.SyncWhole and _G.SyncWhole:DoCleaning()); local m = game.ReplicatedStorage.Plugin:Clone(); local f = assert(loadstring(m.Plugin.Source)); getfenv(f).script = m.Plugin; f();

--]]

local Utils = require(game.ReplicatedStorage.Utils);
local SyncGui = require(script.SyncGui);
local PluginGetOrCreate = require(script.SyncGui.PluginGetOrCreate);
local ProjectManager = require(script.ProjectManager);

_G.SyncWhole = Utils.new("Maid");

--create a new button
local PGOC = PluginGetOrCreate.new(
	"SyncyTowne",
	{},
	{
		{ Name = "SyncyTowne"; Title = "Welcome aboard the HMS SyncyTowne!"};
	}
);
local gui = PGOC.Gui;
local syncGui = SyncGui.new();
syncGui.Parent = gui;

--Load the projects from game.ServerStorage.SyncyTowneData
local pm = ProjectManager.Load();
_G.SyncWhole.PM = pm;
pm.Changed:Connect(function()
	pm:Save();
end)

syncGui.ProjectManager = pm;
