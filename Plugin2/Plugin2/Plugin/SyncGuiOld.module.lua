--[[

Creates a GUI to show active projects. A status indicator, if you will.
To test:
	require(game.ReplicatedStorage.Plugin:Clone().Plugin.SyncGui).Test();

Properties:
	Parent: the parent for the plugin elements. This can be a PluginGui, Frame, etc. The elements should fill the space they're placed in, so don't pass in a ScreenGui unless you want total screen takeover.
	ProjectManager: the thing which managers all the projects in a given game.

Methods:

Events:

Constructors:
	new(): creates a blank, new SyncGui.

--]]

local Utils = require(script.Parent.Utils);
local Debug = Utils.new("Log", "SyncGui: ", false);
local ImageButton = require(script.ImageButton);
local ProjectSync = require(script.Parent.ProjectSync);

local TOOLTIP_OFFSET = 5;
local PROPERTIES = {
	TextButton = {
		"Position", "Size", "AnchorPoint";
		"Text", "TextSize", "Font", "TextScaled";
		"LayoutOrder";
		"Parent", "Name";
	};
}

local function convertButton(button)
	local b = ImageButton.new(button.ClassName == "TextButton" and "Text" or "Image");
	local properties = PROPERTIES[button.ClassName];
	for i, property in pairs(properties) do
		b.Button[property] = button[property];
	end
	for i, v in pairs(button:GetChildren()) do
		v.Parent = b.Button;
	end
	button.Parent = nil;
	return b;
end

local function createGui(self)
	local root = script.Root:Clone();

	local UpdateElements; do --Buttons in the AddNew dialogue.
		local sel = convertButton(root.AddNew.SelectLocal);
		local ok = convertButton(root.AddNew.Frame.OK);
		local cancel = convertButton(root.AddNew.Frame.Cancel);
		cancel.OnClick = function()
			root.AddNew.Visible = false;
		end
		ok.OnClick = function()
			--add a new entry.
			table.insert(self._ProjectManager.Projects, {
				Local = self._SelectedLocal;
				Remote = self._SelectedRemote;
				Exceptions = {};
			});
			root.AddNew.Visible = false;
			self._SelectedLocal = nil;
			self._SelectedRemote = nil;
			self._ProjectManager.Projects = self._ProjectManager.Projects;
			self.ProjectManager = self._ProjectManager;
		end
		function UpdateElements()
			if self._SelectedRemote ~= "" and self._SelectedLocal then
				local desc;
				if not self._SelectedLocal then
					desc = "Example.module.lua";
				elseif self._SelectedLocal:IsA("ModuleScript") then
					desc = self._SelectedLocal.Name .. ".module.lua";
				elseif self._SelectedLocal:IsA("LocalScript") then
					desc = self._SelectedLocal.Name .. ".client.lua";
				elseif self._SelectedLocal:IsA("Script") then
					desc = self._SelectedLocal.Name .. ".server.lua";
				elseif self._SelectedLocal:IsA("Folder") then
					desc = self._SelectedLocal.Name;
				end
				root.AddNew.Example.Text = "Example: ~/" .. self._SelectedRemote .. "/" .. desc;
				ok.Enabled = true;
			else
				root.AddNew.Example.Text = "";
				ok.Enabled = false;
			end
			if self._SelectedLocal then
				sel.Button.Text = "Current Selection: " .. self._SelectedLocal:GetFullName();
			else
				sel.Button.Text = "Select a script/folder, then click this button";
			end
		end
		sel.OnClick = function()
			local selected = game:GetService("Selection"):Get();
			if #selected == 1 and (selected[1]:IsA("LuaSourceContainer") or selected[1]:IsA("Folder")) then
				self._SelectedLocal = selected[1];
			else
				self._SelectedLocal = nil;
			end
			UpdateElements();
		end
		root.AddNew.SelectRemote.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				self._SelectedRemote = root.AddNew.SelectRemote.Text;
			else
				root.AddNew.SelectRemote.Text = self._SelectedRemote;
			end
			UpdateElements();
		end)
	end

	do --"Top-level" buttons in the main gui.
		local header = root.Main.Header;
		local b1 = ImageButton.new();
		b1.Button.Image = "rbxassetid://1851196069";
		b1.Button.ImageRectOffset = Vector2.new();
		b1.Button.ImageRectSize = Vector2.new(32, 32);
		b1.Button.LayoutOrder = 2;
		b1.Button.Size = UDim2.new(0, 20, 0, 20);
		b1.Button.Name = "Add";
		b1.Button.Parent = header;
		b1.OnClick = function()
			root.AddNew.Visible = true;
			self._SelectedLocal = nil;
			self._SelectedRemote = "";
			UpdateElements();
		end
		b1.Hovered:Connect(function(h) self:_SetToolTip(h and "Add new project"); end);
		local b2 = ImageButton.new();
		b2.Button.Image = "rbxassetid://1851196069";
		b2.Button.ImageRectOffset = Vector2.new(32, 0);
		b2.Button.ImageRectSize = Vector2.new(32, 32);
		b2.Button.LayoutOrder = 3;
		b2.Button.Size = UDim2.new(0, 20, 0, 20);
		b2.Button.Name = "Settings";
		b2.Button.Parent = header;
		b2.Hovered:Connect(function(h) self:_SetToolTip(h and "Settings (not yet implemented)"); end);
	end

	do --The warning gui
		root.Warning.ButtonPanel.Cancel.MouseButton1Down:Connect(function()
			root.Warning.Visible = false;
			if self._CurrentWarning then
				coroutine.resume(self._CurrentWarning, false);
			end
		end);
		root.Warning.ButtonPanel.OK.MouseButton1Down:Connect(function()
			root.Warning.Visible = false;
			if self._CurrentWarning then
				coroutine.resume(self._CurrentWarning, true);
			end
		end);
	end
	return root;
end

local Gui = Utils.new("Class", "SyncGui");

Gui._Gui = false;
Gui._ProjectManager = false;
Gui._SelectedLocal = false;
Gui._SelectedRemote = "";
Gui._Cxns = false;
Gui._ToolTip = false;
Gui._ListElements = false; --a cache of "ListElement" (see children)
Gui._SelectedProject = false;
Gui._CurrentWarning = false

function Gui.Set:Parent(v)
	self._Gui.Parent = v;
end
function Gui.Get:Parent()
	return self._Gui.Parent;
end

function Gui.Set:ProjectManager(v)
	self._ProjectManager = v;
	self:_BuildList();
end
Gui.Get.ProjectManager = "_ProjectManager";

local function SetButtonActive(button, active)
	local currentYOffset = button.Button.ImageRectOffset.Y % 64;
	button.Button.ImageRectOffset = Vector2.new(button.Button.ImageRectOffset.X, currentYOffset + (active and 0 or 64));
	button.Enabled = active;
end
local function CreateListElement(self, listIndex)
	local gui = script.ListElement:Clone();
	gui.LayoutOrder = listIndex;
	if listIndex%2 == 0 then
		gui.BackgroundColor3 = Utils.Math.HexColor(0xdbe8ff);
	end
	local sync = ImageButton.new();
	sync.Button.Name = "Sync";
	sync.Button.Image = "rbxassetid://1851196069";
	sync.Button.ImageRectOffset = Vector2.new(64, 32);
	sync.Button.ImageRectSize = Vector2.new(32, 32);
	sync.Button.LayoutOrder = 1;
	sync.Button.Size = UDim2.new(1, 0, 1, 0);
	sync.Button.SizeConstraint = Enum.SizeConstraint.RelativeYY;
	sync.Button.Parent = gui;
	local pull = ImageButton.new();
	pull.Button.Name = "Pull";
	pull.Button.Image = "rbxassetid://1851196069";
	pull.Button.ImageRectOffset = Vector2.new(32, 32);
	pull.Button.ImageRectSize = Vector2.new(32, 32);
	pull.Button.LayoutOrder = 3;
	pull.Button.Size = UDim2.new(1, 0, 1, 0);
	pull.Button.SizeConstraint = Enum.SizeConstraint.RelativeYY;
	pull.Button.Parent = gui;
	local push = ImageButton.new();
	push.Button.Name = "Push";
	push.Button.Image = "rbxassetid://1851196069";
	push.Button.ImageRectOffset = Vector2.new(96, 0);
	push.Button.ImageRectSize = Vector2.new(32, 32);
	push.Button.LayoutOrder = 4;
	push.Button.Size = UDim2.new(1, 0, 1, 0);
	push.Button.SizeConstraint = Enum.SizeConstraint.RelativeYY;
	push.Button.Parent = gui;
	self._ListElements[listIndex] = {gui, sync, pull, push};
	return gui, sync, pull, push;
end

local function UpdateButtons(pull, push, differenceType, project)
	if not differenceType then
		differenceType = "SourceEqual";
		for FilePath, ScriptInStudio, DifferenceType in project.ProjectSync:Iterate() do
			if FilePath == filePath then
				differenceType = DifferenceType;
				break;
			end
		end
	end
	if differenceType == "OnlyInStudio" or differenceType == "OnlyOnFilesystem" or differenceType == "SourceMismatch" then
		SetButtonActive(pull, true);
		SetButtonActive(push, true);
	elseif differenceType == "SourceEqual" then
		SetButtonActive(pull, false);
		SetButtonActive(push, false);
	else
		Utils.Log.Error("Unexpected `differenceType`: %s", differenceType);
	end
end

local function CreateListElementForProject(self, project, listIndex, updateSubelements)
	local gui, sync, pull, push = CreateListElement(self, listIndex);
	sync.OnClick = function()
		project.ProjectSync:SetAutoSync(not project.ProjectSync.AutoSync);
	end
	pull.OnClick = function()
		if not project.ProjectSync.PullingWillCreateFolders or self:_WarnUser(string.format("Pulling from the remote will create folders in studio: %s", table.concat(project.ProjectSync.PullingWillCreateFolders, "\n"))) then
			project.ProjectSync:Pull();
		end
	end
	push.OnClick = function()
		project.ProjectSync:Push();
	end
	local HOVER_TEXT = {
		["Sync-true"] = "Keep files synchronized";
		["Sync-false"] = "Cannot turn on auto-sync when files mismatch";
		["Pull-true"] = "Update scripts in studio to match file system";
		["Pull-false"] = "Cannot pull; all scripts are synchronized";
		["Push-true"] = "Update file system to match studio";
		["Push-false"] = "Cannot push; all scripts are synchronized";
	};
	local function CheckDifferenceCount()
		if project.ProjectSync.DifferenceCount > 0 then
			SetButtonActive(pull, true);
			SetButtonActive(push, true);
			SetButtonActive(sync, false);
		else
			SetButtonActive(pull, false);
			SetButtonActive(push, false);
			SetButtonActive(sync, true);
		end
		for i, v in pairs({sync, pull, push}) do
			local text = HOVER_TEXT[v.Button.Name .. "-" .. tostring(v.Enabled)];
			self._Cxns[v] = v.Hovered:Connect(function(h) self:_SetToolTip(h and text); end);
		end
		updateSubelements();
	end
	CheckDifferenceCount();
	local function CheckAutoSync()
		sync.Selected = project.ProjectSync.AutoSync;
	end
	project.ProjectSync.Changed:Connect(function(property)
		if property == "DifferenceCount" then
			CheckDifferenceCount();
		elseif property == "AutoSync" then
			CheckAutoSync();
		end
	end)
	Debug("Formatting element %s for project %s", listIndex, project.Remote);
	gui.Descriptor.Local.Text = project.Local:GetFullName();
	gui.Descriptor.Remote.Text = project.Remote;
	gui.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			if self._SelectedProject == project then
				self._SelectedProject = nil;
			else
				self._SelectedProject = project;
			end
			self:_BuildList();
		end
	end);
	return gui;
end
local function CreateListElementForScript(self, filePath, script, differenceType, listIndex, project)
	local gui, sync, pull, push = CreateListElement(self, listIndex);
	sync.Button.Image = "";
	sync.Button.BackgroundTransparency = 1;
	gui.Descriptor.Local.Text = (script and script:GetFullName() or "");
	gui.Descriptor.Remote.Text = filePath;
	pull.OnClick = function()
		project.ProjectSync:Pull(filePath);
		wait(.1);
		UpdateButtons(pull, push, nil, project);
	end
	push.OnClick = function()
		project.ProjectSync:Push(filePath);
		wait(.1);
		UpdateButtons(pull, push, nil, project);
	end
	UpdateButtons(pull, push, differenceType);
	return gui;
end

--[[ @brief Creates the list of projects.
--]]
function Gui:_BuildList()
	for i = 1, #self._ListElements do
		Debug("More elements than needed exist; destroying %s", i);
		local gui = unpack(self._ListElements[i]);
		gui:Destroy();
		self._ListElements[i] = nil;
	end
	if self._ProjectManager then
		local scrollingFrame = self._Gui.Main.ScrollingFrame;
		local j = 1;
		for i, project in pairs(self._ProjectManager.Projects or {}) do
			local k = j;
			local function UpdateChildren()
				if self._SelectedProject == project then
					local filepathMap = {};
					for filepath, script, differenceType in project.ProjectSync:Iterate() do
						filepathMap[filepath] = differenceType;
					end
					for j = k + 1, #self._ListElements do
						local gui, sync, pull, push = unpack(self._ListElements[j]);
						if sync.Button.BackgroundTransparency ~= 1 then
							break;
						end
						if filepathMap[gui.Descriptor.Remote.Text] then
							UpdateButtons(pull, push, filepathMap[gui.Descriptor.Remote.Text]);
						end
					end
				end
			end
			CreateListElementForProject(self, project, j, UpdateChildren).Parent = scrollingFrame;
			j = j + 1;
			if project == self._SelectedProject then
				for filePath, script, differenceType in project.ProjectSync:Iterate() do
					CreateListElementForScript(self, filePath, script, differenceType, j, project).Parent = scrollingFrame;
					j = j + 1;
				end
			end
		end
		scrollingFrame.CanvasSize = UDim2.new(1, 0, 0, 30 * j);
		Debug("Provided %s space to scroll", scrollingFrame.CanvasSize);
	end
end

--[[ @brief Sets the ToolTip text to display, or hides the ToolTip.
	@param text The text to display. If nil, this will hide the gui.
--]]
function Gui:_SetToolTip(text)
	if text then
		local requiredSize = game:GetService("TextService"):GetTextSize(text, 14, Enum.Font.Arial, Vector2.new(100, 50))
		self._ToolTip.Size = UDim2.new(0, requiredSize.X, 0, requiredSize.Y);
		self._ToolTip.Text = text;
		self._ToolTip.Visible = true;
		self._Cxns.RootMovement = self._Gui.InputChanged:connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseMovement then
				local pos = Vector2.new(io.Position.X, io.Position.Y);
				--if we are within 100 pixels of the right & have more space on the left, switch AnchorPoint. Likewise for top/bottom.
				local opp = self._Gui.AbsoluteSize - pos;
				self._ToolTip.AnchorPoint = Vector2.new(
					(opp.x < 100 and opp.x < pos.x) and 1 or 0,
					(pos.y < 50 and opp.y > pos.y) and 0 or 1
				);
				local fromCorner = self._ToolTip.AnchorPoint * 2 - Vector2.new(1, 1);
				self._ToolTip.Position = UDim2.new(0, pos.x, 0, pos.y) -UDim2.new(0, fromCorner.x * TOOLTIP_OFFSET, 0, fromCorner.y * TOOLTIP_OFFSET);
			end
		end);
	else
		self._ToolTip.Visible = false;
		self._Cxns:Disconnect("RootMovement");
	end
end

--[[ @brief Creates a ToolTip gui & parents it to self.Gui.
--]]
function Gui:_CreateToolTip()
	local t = Instance.new("TextLabel");
	t.Visible = false;
	t.Parent = self._Gui;
	t.Size = UDim2.new(0, 80, 0, 20);
	t.AnchorPoint = Vector2.new(0, 1);
	t.TextWrapped = true;
	t.BackgroundColor3 = Color3.fromRGB(255, 251, 176);
	self._ToolTip = t;
end

--[[ @brief Enables the warning screen & yields until an answer is shown.
	@param details The details of the warning to show to the user.
	@return True if "continue" is selected; false if "cancel" is selected.
--]]
function Gui:_WarnUser(details)
	if self._CurrentWarning then
		--If there are any warnings in-progress, cancel them.
		coroutine.resume(self._CurrentWarning, false);
	end
	self._Gui.Warning.Visible = true;
	self._CurrentWarning = coroutine.running();
	local retval = coroutine.yield();
	self._CurrentWarning = nil;
	return retval;
end

function Gui:Destroy()
	self._Cxns:DisconnectAll();
end

function Gui.new()
	local self = setmetatable({}, Gui.Meta);
	self._Cxns = Utils.new("ConnectionHolder");
	self._ListElements = {};
	self._Gui = createGui(self);
	self:_CreateToolTip();
	return self;
end

function Gui.Test()
	while game.StarterGui:FindFirstChild("SyncGui") do game.StarterGui.SyncGui:Destroy(); end
	local PGOC = require(script.PluginGetOrCreate).new(
		"SyncyTowne",
		{},
		{
			{ Name = "SyncyTowne"; Title = "Welcome aboard the HMS SyncyTowne!"};
		}
	)
	local s = PGOC.Gui;
	local g = Gui.new();
	g.Parent = s;
--	g.Parent = Instance.new("ScreenGui", game.StarterGui);

	--Create a test directory to verify the list building works.
	local ProjectManager = require(script.Parent.ProjectManager);
	local p = ProjectManager.new();
	local function CreateFolder(name)
		local folder = Instance.new("Folder");
		folder.Name = name;
		Instance.new("Script", folder).Name = "Test1";
		Instance.new("LocalScript", folder).Name = "Test2";
		local folder2 = Instance.new("Folder", folder);
		folder2.Name = "Folder2";
		Instance.new("ModuleScript", folder2).Name = "Test1";
		return folder;
	end
	p.Projects = {
		{ Local = CreateFolder("First Project"); Remote = "test 1"; };
		{ Local = CreateFolder("Second Project"); Remote = "test 2"; };
		{ Local = CreateFolder("Third Project"); Remote = "test 3"; };
	};
	g.ProjectManager = p;
end

return Gui;
