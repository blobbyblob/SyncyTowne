--[[

Synchronizes a FilesystemModel & StudioModel.

Properties:
	FilesystemModel (read-only): the state of the remote filesystem.
	StudioModel (read-only): the state of the local studio DataModel.
	RootPath (read-only): the path of this project on the file system (relative to the global root).
	RootInstance (read-only): the reference to the root object in the studio DataModel.
	AutoSync (boolean): when true, the project will automatically be synced when changes are detected.
	DifferenceCount (read-only, int): the number of files which differ on the remote.
	Differences (read-only, array): a list of files which differ on the remote compared to locally.

Events:
	SyncStateChanged(remoteFile, studioScript, state): fires whenever the two models come unsynced.
		remoteFile: the full path to the remote file

Methods:
	RemoveRoot(path) -> path: returns the file path with the root path trimmed off. E.g., RemoveRoot("project/foo/bar") -> "foo/bar" (if Root is "project")
	RemoveSuffix(path) -> path, className: returns the path with any suffix trimmed. E.g., RemoveSuffix("foo.module.lua") -> "foo", "ModuleScript"
	RemovePath(path) -> path, filename: splits off the filename given a path. E.g., RemovePath("path/to/foo") -> "path/to", "foo"
	GetRemote(Instance) -> path: returns the remote filename for a particular Instance.
	GetLocal(path) -> Instance: returns the local instance for a particular filename.
	Push([ path ]): pushes DataModel state to the remote.
		path: when provided, only the contents at this file path will be pushed.
	Pull([ path ]): pulls remote state to the DataModel.
		path: when provided, only the contents at this file path will be pulled.

Constructors:
	new(fileRoot, studioRoot): constructs a new synchronizer using the remote root path & the studio root part.

--]]

local module = {}

return module
