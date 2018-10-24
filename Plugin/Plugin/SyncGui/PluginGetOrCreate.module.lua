--[[

When you're developing a plugin in studio, you launch your plugin dozens of times using the command bar.
So as to not create dozens of buttons, PluginGuis, etc., this module will act as a go-between to create
all of the necessary parts of a plugin, or fetch them if they have been created before.

Properties:
	Plugin: the Plugin object.
	Toolbar: the first Toolbar object.
	Toolbars: all Toolbar objects. These are indexed both by number & name.
	Button: the first Button object.
	Buttons: all Button objects. These are indexed both by number & name.
	Gui: the first PluginGui object.
	Guis: all PluginGui objects.

Methods:

Events:

Constructors:
	new(): construct with default settings.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "PluginGOC: ", true);

local PluginGOC = Utils.new("Class", "PluginGOC");

PluginGOC.Plugin = false;
PluginGOC.Toolbars = false;
PluginGOC.Toolbar = false;
PluginGOC.Buttons = false;
PluginGOC.Button = false;
PluginGOC.Guis = false;
PluginGOC.Gui = false;

function PluginGOC.new(identity, toolbars, guis)
	Utils.Log.AssertNonNilAndType("identity", "string", identity);
	Utils.Log.AssertNonNilAndType("toolbars", "table", toolbars);
	local self = setmetatable({}, PluginGOC.Meta);
	self.Toolbars = {};
	self.Buttons = {};
	self.Guis = {};

	if not _G.PluginGetOrCreateCache then
		_G.PluginGetOrCreateCache = {};
	end

	local get = _G.PluginGetOrCreateCache[identity];
	if not get then
		get = { Guis = {}; Toolbars = {}; };
		_G.PluginGetOrCreateCache[identity] = get;
	end

	--Whatever we didn't get, we have to create.
	if not get.Plugin then
		Debug("Identity %s: Creating Plugin", identity);
		get.Plugin = getfenv(0).PluginManager():CreatePlugin();
	end
	for i, toolbar in pairs(toolbars) do
		Utils.Log.AssertNonNilAndType("toolbar[?].Name", "string", toolbar.Name);
		Utils.Log.AssertNonNilAndType("toolbar[?].Buttons", "table", toolbar.Buttons);

		--Create this toolbar if need be.
		if not get.Toolbars[i] then
			Debug("Identity %s: Creating Toolbar %s", identity, toolbar.Name);
			get.Toolbars[i] = {};
			get.Toolbars[i].Toolbar = get.Plugin:CreateToolbar(toolbar.Name);
		end

		--Add this toolbar to the Toolbars list.
		table.insert(self.Toolbars, get.Toolbars[i].Toolbar);
		self.Toolbars[toolbar.Name] = get.Toolbars[i].Toolbar;

		for j, button in pairs(toolbar.Buttons) do
			Utils.Log.AssertNonNilAndType("toolbar[?].Buttons[?].Text", "string", button.Text);
			if button.ToolTip then
				Utils.Log.AssertNonNilAndType("toolbar[?].Buttons[?].ToolTip", "string", button.ToolTip);
			end
			if button.IconName then
				Utils.Log.AssertNonNilAndType("toolbar[?].Buttons[?].IconName", "string", button.IconName);
			end

			--If we don't have a button ready, create one.
			if not get.Toolbars[i][j] then
				get.Toolbars[i][j] = get.Toolbars[i].Toolbar:CreateButton(button.Text, button.ToolTip or "", button.IconName or "");
			else
				get.Toolbars[i][j].Icon = button.IconName or "";
			end

			--Add this button to the Buttons list.
			table.insert(self.Buttons, get.Toolbars[i][j]);
			self.Buttons[button.Text] = get.Toolbars[i][j];
		end

		--Disable all buttons which we don't want.
		--These may exist because we launched the tool with more buttons requested than we need right now.
		for j = #toolbar.Buttons + 1, #get.Toolbars[i] do
			get.Toolbars[i][j].Enabled = false;
		end
	end

	--Iterate through the requested Guis. If they exist, they should be cleared.
	for i, gui in pairs(guis) do
		Utils.Log.AssertNonNilAndType("guis[?].Name", "string", gui.Name);
		if gui.Parameters ~= nil then
			Utils.Log.AssertNonNilAndType("guis[?].Parameters", "userdata", gui.Parameters);
		end

		--Create the PluginGui if it doesn't already exist.
		if not get.Guis[gui.Name] then
			get.Guis[gui.Name] = get.Plugin:CreateDockWidgetPluginGui(gui.Name, gui.Parameters or DockWidgetPluginGuiInfo.new());
		end
		get.Guis[gui.Name]:ClearAllChildren();
		get.Guis[gui.Name].Title = gui.Title or gui.Name;
		get.Guis[gui.Name].Name = gui.Name;

		self.Guis[i] = get.Guis[gui.Name];
		self.Guis[gui.Name] = get.Guis[gui.Name];
	end

	--The common case is single Toolbar & single Button, so make that easy.
	self.Toolbar = self.Toolbars[1];
	self.Button = self.Buttons[1];
	self.Gui = self.Guis[1];

	return self;
end

return PluginGOC;
