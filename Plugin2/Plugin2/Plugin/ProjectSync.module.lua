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
	CheckSync(): determines which scripts disagree with the remote. Returns a list of scripts.
	Push(script): updates the remote's scripts with the sources from studio. If script is provided, this will be the script which is synced; otherwise, all scripts in the project are synced.
	Pull(script): updates studio scripts with the sources from the remote. If script is provided, this will be the script which is synced; otherwise, all scripts in the project are synced.
	SetAutoSync(value): enables/disables auto-sync. This will automatically invoke CheckSync and throw an error if DifferenceCount > 0, so it's wise to check this in advance (or pcall).
	Iterate(): iterates over all files in this combined studio/filesystem client.
	Destroy(): cleans up this object.

Constructors:
	new(): construct with default settings.

--]]

local module = {}

return module
