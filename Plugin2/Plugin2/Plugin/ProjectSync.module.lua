--[[

Represents a project and provides sync-across-HTTP functionality.

Properties:
	Project (read-only, table): the project definition as given by ProjectManager.
	DifferenceCount (read-only, number): the number of scripts which are different from the remote.
	AutoSync (read-only, boolean): whether or not the project is being auto-synced at the moment.
	PullingWillCreateFolders (read-only, boolean|table): this will be set to false if pulling the remote logs will not result in folder creation in studio. Otherwise, it will be a table of strings representing each folder that will be created.
	PushingWillDeleteFiles (read-only, boolean): this is set to true if pushing scripts to the remote will result in files being deleted.

Events:
	Changed(): fires when any property changes.

Methods:
	CheckSync(): determines which scripts disagree with the remote.
	Push(script): updates the remote's scripts with the sources from studio. If script is provided, this will be the script which is synced; otherwise, all scripts in the project are synced.
	Pull(script): updates studio scripts with the sources from the remote. If script is provided, this will be the script which is synced; otherwise, all scripts in the project are synced.
	SetAutoSync(value): enables/disables auto-sync. This will automatically invoke CheckSync and throw an error if DifferenceCount > 0, so it's wise to check this in advance (or pcall).
	Iterate(): iterates over all files in this combined studio/filesystem client. Each invocation to the returned function gives: FilePath, ScriptInStudio, DifferenceType
	Destroy(): cleans up this object.

Constructors:
	new(project): construct with default settings. Argument `project` is a table with keys Local and Remote.

TODO: wire up the changed event properly. We'll have to update DifferenceCount after CheckSync and any time it updates. We may want to avoid updating it if we're planning to respond immediately to the update, but this isn't critical.

--]]

local Utils = require(script.Parent.Parent.Utils);
local Debug = Utils.new("Log", "ProjectSync: ", false);
local Compare = require(script.Compare).Compare;
local FilesystemModel = require(script.FilesystemModel);
local StudioModel = require(script.StudioModel);

local SCREEN_TIME= .3;
local LOCAL_UPDATE_DELAY = 3; --You have to stop editing a script for this many seconds before it gets synced to the remote.

local ProjectSync = Utils.new("Class", "ProjectSync");

--Publicly readable entries.
ProjectSync._Project = { Local = Instance.new("Folder"); Remote = "path/to/project"; };
ProjectSync._DifferenceCount = 0;
ProjectSync._AutoSync = false;
ProjectSync.PullingWillCreateFolders = false;
ProjectSync.PushingWillDeleteFiles = false;

--Internal structures
ProjectSync._Maid = false;
ProjectSync._StudioModel = false;
ProjectSync._FilesystemModel = false;
ProjectSync._RemoteScreenTime = 0; --If tick() is greater than this value, we will ignore changed events from the remote.
ProjectSync._LocalScreenTime = 0; --If tick() is greater than this value, we will ignore changed events locally.

--Events
ProjectSync._ChangedEvent = false;
ProjectSync._ScriptChangeEvent = false;

ProjectSync.Get.Project = "_Project";
ProjectSync.Get.DifferenceCount = "_DifferenceCount";
ProjectSync.Get.AutoSync = "_AutoSync";
ProjectSync.Get.Changed = function(self) return self._ChangedEvent.Event; end;

--[[ @brief Forces a refresh of the models.
--]]
function ProjectSync:CheckSync()
	self._FilesystemModel = FilesystemModel.fromRoot(self._Project.Remote);
	self._Maid._FilesystemModel = self._FilesystemModel;
	self._StudioModel = StudioModel.fromInstance(self._Project.Local);
	self._Maid._StudioModel = self._StudioModel;
	local function CheckDifferenceCount(self)
		local differenceCount = 0;
		for i, diff in pairs(Compare(self._FilesystemModel, self._StudioModel)) do
			if diff.Comparison ~= "synced" then
				differenceCount = differenceCount + 1;
			end
		end
		Debug("Setting DifferenceCount to %s", differenceCount);
		if self._DifferenceCount ~= differenceCount then
			self._DifferenceCount = differenceCount;
			self._ChangedEvent:Fire("DifferenceCount");
		end
	end
	CheckDifferenceCount(self);
	self._Maid.FilesystemChanged = self._FilesystemModel.Changed:Connect(function(file)
		CheckDifferenceCount(self);
		if tick() > self._RemoteScreenTime then
			self._ScriptChangeEvent:Fire("Remote", file);
		end
	end);
	self._Maid.StudioChanged = self._StudioModel.Changed:Connect(function(script)
		CheckDifferenceCount(self);
		if tick() > self._LocalScreenTime then
			self._ScriptChangeEvent:Fire("Local", script);
		end
	end);
end

--[[ @brief Updates the remote's scripts with the sources from studio.
	@param script The script which should be synced; if omitted, all scripts in the project are synced.
--]]
function ProjectSync:Push(script)
	Debug("ProjectSync:Push(%s) called", script);
	local differenceCount = 0;
	for i, diff in pairs(Compare(self._FilesystemModel, self._StudioModel)) do
		if diff.Comparison ~= "synced" then
			differenceCount = differenceCount + 1;
			if not script or (script == (diff.File and diff.File.FullPath) or script == (diff.Script and diff.Script.Object)) then
				self._RemoteScreenTime = tick() + SCREEN_TIME;
				diff.Push();
				differenceCount = differenceCount - 1;
			end
		end
	end
	Debug("Setting DifferenceCount to %s", differenceCount);
	if self._DifferenceCount ~= differenceCount then
		self._DifferenceCount = differenceCount;
		self._ChangedEvent:Fire("DifferenceCount");
	end
end

--[[ @brief Updates studio scripts with the sources from the remote.
	@param script The script which should be synced; if omitted, all scripts in the project are synced.
--]]
function ProjectSync:Pull(script)
	Debug("ProjectSync:Pull(%s) called", script);
	local differenceCount = 0;
	for i, diff in pairs(Compare(self._FilesystemModel, self._StudioModel)) do
		if diff.Comparison ~= "synced" then
			differenceCount = differenceCount + 1;
			if not script or (script == (diff.File and diff.File.FullPath) or script == (diff.Script and diff.Script.Object)) then
				self._LocalScreenTime = tick() + SCREEN_TIME;
				diff.Pull();
				differenceCount = differenceCount - 1;
			end
		end
	end
	Debug("Setting DifferenceCount to %s", differenceCount);
	if self._DifferenceCount ~= differenceCount then
		self._DifferenceCount = differenceCount;
		self._ChangedEvent:Fire("DifferenceCount");
	end
end

--[[ @brief enables/disables auto-sync.

	This will automatically invoke CheckSync and throw an error if DifferenceCount > 0, so it's wise to check this in advance (or pcall).
--]]
function ProjectSync:SetAutoSync(value)
	--Whenever the changed event fires, sync from one side to another.
	if value then
		local UpdateBuffer = {};
		self._Maid.AutoSyncCxn = self._ScriptChangeEvent.Event:Connect(function(origin, obj)
			Debug("Script changed: %s, %s", origin, obj);
			if origin == "Local" then
				UpdateBuffer[obj] = (UpdateBuffer[obj] or 0) + 1;
				local b = UpdateBuffer[obj];
				wait(LOCAL_UPDATE_DELAY);
				if b == UpdateBuffer[obj] then
					self:Push(obj);
				end
			elseif origin == "Remote" then
				self:Pull(obj);
			end
		end);
	else
		self._Maid.AutoSyncCxn = nil;
	end
	self._AutoSync = value;
	self._ChangedEvent:Fire("AutoSync");
end

local COMPARISON_MAP = {
	scriptOnly = "OnlyInStudio";
	fileOnly = "OnlyOnFilesystem";
	desynced = "SourceMismatch";
	synced = "SourceEqual";
};

--[[ @brief Iterates over all files in this combined studio/filesystem client
	@return A function which, for each invocation, will return a FilePath, ScriptInStudio, DifferenceType for each script maintained in this project. DifferenceType can be "fileOnly", "scriptOnly", "synced", or "desynced".
--]]
function ProjectSync:Iterate()
	local diff = Compare(self._FilesystemModel, self._StudioModel);
	local iter, inv, i = pairs(diff);
	local diff;
	return function()
		i, diff = iter(inv, i);
		if not diff then
			return;
		end
		local script = diff.Script and diff.Script.Object;
		local file = diff.File and diff.File.FullPath;
		return file, script, COMPARISON_MAP[diff.Comparison];
	end;
end

--[[ @brief Cleans up this instance.
--]]
function ProjectSync:Destroy()
	self._Maid:Destroy();
end

--[[ @brief Creates a new ProjectSync instance which connects a local script/folder to a remote path.
--]]
function ProjectSync.new(project)
	local self = setmetatable({}, ProjectSync.Meta);
	self._Project = {
		Local = project.Local;
		Remote = project.Remote;
	};
	self._Maid = Utils.new("Maid");
	self._ChangedEvent = Instance.new("BindableEvent");
	self._ScriptChangeEvent = Instance.new("BindableEvent");
	spawn(function()
		self:CheckSync();
	end);
	return self;
end

function ProjectSync.Test()

end

return ProjectSync;

