--[[

Hangs onto the list of projects which we're tracking.

Properties:
	Projects: a list of projects which we're tracking. Each project should be of the following form:
		{
			Local = <the root instance>;
			Remote = <the folder which we should sync to>;
			Exceptions = {<instance in which we shouldn't search for scripts>, ...}; --this will be created (empty table) if it doesn't exist.
			ProjectSync = <ProjectSync reference for this project>; --this will be created if it doesn't exist.
		}
		Note: this table should not be changed without also setting ProjectManager.Projects = ProjectManager.Projects;

Methods:
	Save(parent = game.ServerStorage, name = "SyncyTowneData"): saves the list of projects we're tracking to the data model.
	Load(parent = game.ServerStorage.SyncyTowneData): loads the list of projects we're tracking from the data model.

Events:
	Changed(property): fires when a property is changed.

Constructors:
	new(): construct with default settings.

--]]

local Utils = require(game.ReplicatedStorage.Utils);
local Debug = Utils.new("Log", "ProjectManager: ", true);
local ProjectSync = require(script.Parent.ProjectSync);

local ProjectManager = Utils.new("Class", "ProjectManager");

ProjectManager._Projects = false;
ProjectManager._ChangedEvent = false;

local function ValidateEntry(v, name)
	Utils.Log.AssertNonNilAndType(name..".Local", "userdata", v.Local);
	Utils.Log.AssertNonNilAndType(name..".Remote", "string", v.Remote);
	if v.Exceptions then
		Utils.Log.AssertNonNilAndType(name..".Exceptions", "table", v.Exceptions);
	else
		v.Exceptions = {};
	end
	if v.ProjectSync then
		Utils.Log.AssertNonNilAndType(name..".ProjectSync", "table", v.ProjectSync);
	else
		v.ProjectSync = ProjectSync.new(v);
	end
end

function ProjectManager.Set:Projects(list)
	local s = {};
	local j = 1;
	for i, v in pairs(list) do
		Utils.Log.Assert(i == j, "Projects list should be an array without gaps; found index %s", i);
		j = j + 1;
		local success, errmsg = pcall(ValidateEntry, v, "list["..i.."]")
		if success then
			table.insert(s, v)
		else
			Utils.Log.Warn("%s", errmsg)
		end
	end
	self._Projects = s;
	self._ChangedEvent:Fire("Projects");
end
ProjectManager.Get.Projects = "_Projects";

function ProjectManager.Get:Changed()
	return self._ChangedEvent.Event;
end

function ProjectManager:Save(parent, name)
	if not parent then parent = game.ServerStorage; end
	if not name then name = "SyncyTowneData"; end
	local folder = Instance.new("Folder");
	folder.Name = name;
	for i, v in pairs(self._Projects) do
		local name = v.Local:GetFullName()
		local project = Instance.new("Folder", folder);
		project.Name = name;
		local loc = Instance.new("ObjectValue", project);
		loc.Name = "Local";
		loc.Value = v.Local;
		--Create a reference (textual) to the remote folder.
		local rem = Instance.new("StringValue", project);
		rem.Name = "Remote";
		rem.Value = v.Remote;
		--Create a list of ObjectValues for each exception.
		if v.Exceptions and #v.Exceptions > 0 then
			local exc = Instance.new("Folder", project);
			exc.Name = "Exceptions";
			for i, v in pairs(v.Exceptions) do
				local ref = Instance.new("ObjectValue", exc);
				ref.Name = tostring(i);
				ref.Value = v;
			end
		end
	end

	--If there exist folders with this name already, delete them.
	while parent:FindFirstChild(name) do
		parent:FindFirstChild(name):Destroy();
	end
	folder.Parent = parent;
end

function ProjectManager:__eq(other)
	local function CompareProject(a, b)
		if a.Local ~= b.Local then return false; end
		if a.Remote ~= b.Remote then return false; end
		--Make a map out of the exceptions.
		local m = {};
		for i, v in pairs(a.Exceptions) do
			m[v] = true;
		end
		for i, v in pairs(b.Exceptions) do
			if m[v] then
				m[v] = nil;
			else
				--We found something in b that isn't in a.
				return false;
			end
		end
		if next(m) then
			--There was something in a which wasn't in b.
			return false;
		end
		return true;
	end
	--Compare the list of projects.
	local selfKeys = Utils.Table.Keys(self._Projects);
	local otherKeys = Utils.Table.Keys(self._Projects);
	table.sort(selfKeys);
	table.sort(otherKeys);
	for i = 1, math.max(#selfKeys, #otherKeys) do
		if selfKeys[i] ~= otherKeys[i] then return false; end
		if not selfKeys[i] or not otherKeys[i] then return false; end
		if not CompareProject(self._Projects[selfKeys[i]], self._Projects[otherKeys[i]]) then
			return false;
		end
	end
	return true;
end

function ProjectManager:__tostring()
	return string.format("<ProjectManager: %d projects>", #self._Projects)
end

function ProjectManager.Load(folder)
	if not folder then
		folder = game.ServerStorage:FindFirstChild("SyncyTowneData");
	end
	if not folder then
		return ProjectManager.new()
	end
	local projects = {};
	for i, sync in pairs(folder:GetChildren()) do
		local project = {};
		local l = sync:FindFirstChild("Local");
		project.Local = l.Value;
		local r = sync:FindFirstChild("Remote");
		project.Remote = r.Value;
		local except = sync:FindFirstChild("Exceptions");
		if except then
			project.Exceptions = {};
			for i, v in pairs(except:GetChildren()) do
				if v.Value then
					table.insert(project.Exceptions, v.Value);
				end
			end
		end
		table.insert(projects, project);
	end
	local x = ProjectManager.new();
	x.Projects = projects;
	return x;
end

function ProjectManager.new()
	local self = setmetatable({}, ProjectManager.Meta);
	self._ChangedEvent = Instance.new("BindableEvent");
	return self;
end

function ProjectManager.TestSave()
	local x = ProjectManager.new();
	x.Projects = {
		{
			Local = workspace;
			Remote = "foobar";
			Exceptions = {workspace:GetChildren()[1]};
		};
		{
			Local = Instance.new("Folder");
			Remote = "yea-boi";
		};
	}
	local FolderStructure = {
		{	ClassName = "Folder"; Name = "Folder";
			{	ClassName = "ObjectValue"; Name = "Local"; Value = x.Projects[2].Local; };
			{	ClassName = "StringValue"; Name = "Remote"; Value = "yea-boi"; };
		};
		{	ClassName = "Folder"; Name = "Workspace";
			{	ClassName = "Folder"; Name = "Exceptions";
				{	ClassName = "ObjectValue"; Name = "1"; Value = x.Projects[1].Exceptions[1]; };
			};
			{	ClassName = "ObjectValue"; Name = "Local"; Value = workspace; };
			{	ClassName = "StringValue"; Name = "Remote"; Value = "foobar"; };
		};
	};
	local function Compare(expected, actual)
		for i, v in pairs(expected) do
			if type(i) == "string" then
				Utils.Log.AssertEqual(i, v, expected[i]);
			end
		end
		local children = actual:GetChildren();
		table.sort(children, function(a, b) return a.Name < b.Name; end);
		Utils.Log.AssertEqual("Lengths", #expected, #children);
		for i = 1, #expected do
			Compare(expected[i], children[i]);
		end
	end
	local function ValidateFolder()
		local children = game.ServerStorage.SyncyTowneTestData:GetChildren();
		table.sort(children, function(a, b) return a.Name < b.Name; end);
		Utils.Log.AssertEqual("Lengths", #FolderStructure, #children);
		for i = 1, #FolderStructure do
			Compare(FolderStructure[i], children[i]);
		end
	end
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	ValidateFolder();
	--Add a garbage project and ensure it gets deleted.
	Instance.new("Folder", game.ServerStorage.SyncyTowneTestData).Name = "FakeProject!";
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	ValidateFolder();
	--Screw with the Remote name and ensure it gets fixed.
	game.ServerStorage.SyncyTowneTestData.Folder.Remote.Value = "trololol";
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	ValidateFolder();
	--Delete the exceptions folder and ensure it returns.
	game.ServerStorage.SyncyTowneTestData.Workspace.Exceptions:Destroy();
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	ValidateFolder();
	--Add junk files to a project and ensure they're deleted.
	Instance.new("TextLabel", game.ServerStorage.SyncyTowneTestData.Folder).Name = "lel";
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	ValidateFolder();

	game.ServerStorage:FindFirstChild("SyncyTowneTestData"):Destroy();
end

function ProjectManager.TestLoad()
	local x = ProjectManager.new();
	x.Projects = {
		{
			Local = workspace;
			Remote = "foobar";
			Exceptions = {workspace:GetChildren()[1]};
		};
		{
			Local = Instance.new("Folder");
			Remote = "yea-boi";
		};
	}
	x:Save(game.ServerStorage, "SyncyTowneTestData");
	local y = ProjectManager.Load(game.ServerStorage.SyncyTowneTestData);
	--Compare x and y for equality.
	Utils.Log.AssertEqual("ProjectManagers", x, y);
end

function ProjectManager.Test()
	ProjectManager.TestSave();
	ProjectManager.TestLoad();
end

return ProjectManager;
