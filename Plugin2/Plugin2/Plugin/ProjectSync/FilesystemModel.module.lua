--[[

Represents the filesystem using Lua tables.

Properties:
	Root (string, read-only): the root of the project relative to the global root.
	Tree (read-only): the tree representing the contents of the filesystem. Each entry can be one of the following:
			{ Name = "<filename>",    Type = "file",   FullPath = "<full path>", Parent = <parent>, Hash = "<hash>" }
			{ Name = "<folder name>", Type = "folder", FullPath = "<full path>", Parent = <parent>, Children = {<children indexed by name>} }
		Note that in the case of a folder, children are recursively one of the aforementioned two types.

Events:
	Changed(property): fires when any property changes (e.g., files change on the remote).

Methods:
	Compare(other): returns a table comparing two file systems. The return value will be a list of the following elements:
		{ Name = "<relative file path from root>"; Difference = "synced|desynced|selfOnly|otherOnly" }

Constructors:
	fromRoot(rootPath): builds up a file system model from a root path. This will throw an error if the server can't be reached. This also starts up the connection.

--]]

return {};