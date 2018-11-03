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

--]]


local Utils = require(script.Parent.Parent.Utils);
local ProjectSync = Utils.new("Class", "ProjectSync");
local Debug = Utils.new("Log", "ProjectSync: ", true);

ProjectSync._Project = { Local = Instance.new("Folder"); Remote = "path/to/project"; };
ProjectSync._DifferenceCount = 0;
ProjectSync._AutoSync = false;
ProjectSync.PullingWillCreateFolders = false;
ProjectSync.PushingWillDeleteFiles = false;
ProjectSync._Maid = false;

--[[ @brief Determines which scripts disagree with the remote.
--]]
function ProjectSync:CheckSync()

end

--[[ @brief Updates the remote's scripts with the sources from studio.
	@param script The script which should be synced; if omitted, all scripts in the project are synced.
--]]
function ProjectSync:Push(script)

end

--[[ @brief Updates studio scripts with the sources from the remote.
	@param script The script which should be synced; if omitted, all scripts in the project are synced.
--]]
function ProjectSync:Pull(script)

end

--[[ @brief enables/disables auto-sync.

	This will automatically invoke CheckSync and throw an error if DifferenceCount > 0, so it's wise to check this in advance (or pcall).
--]]
function ProjectSync:SetAutoSync(value)

end

--[[ @brief Iterates over all files in this combined studio/filesystem client
	@return A function which, for each invocation, will return a FilePath, ScriptInStudio, DifferenceType for each script maintained in this project. DifferenceType can be "fileOnly", "scriptOnly", "synced", or "desynced".
--]]
function ProjectSync:Iterate()

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
	self._FilesystemModel = FilesystemModel.fromRoot(project.Remote);
	self._StudioModel = StudioModel.fromInstance(project.Local);
	self._Maid._FilesystemModel = self._FilesystemModel;
	self._Maid._StudioModel = self._StudioModel;
	return self;
end

function ProjectSync.Test()
	local TS = game:GetService("TestService");
	TS:Check(true, "foobar", script, 36);
	TS:Check(false, "foobar", script, 37);
	TS:Checkpoint("checkpoint", script, 38);
end

return ProjectSync;

