--[[

Represents the filesystem using Lua tables.

Properties:
	Root (string, read-only): the root of the project relative to the global root. This will be `false` if we're not syncing to the file system.
	Tree (read-only): the tree representing the contents of the filesystem. Each entry can be one of the following:
			{ Name = "<filename>",    Type = "file",   FullPath = "<full path>", Parent = <parent>, Hash = "<hash>" }
			{ Name = "<folder name>", Type = "folder", FullPath = "<full path>", Parent = <parent>, Children = {<children indexed by name>} }
		Note that in the case of a folder, children are recursively one of the aforementioned two types.

Events:
	Changed(property): fires when any property changes (e.g., files change on the remote).

Methods:
	Compare(other): returns a table comparing two file systems. The return value will be a list of the following elements:
		{ Name = "<relative file path from root>"; Difference = "synced|desynced|selfOnly|otherOnly" }
	Destroy(): cleans up this instance.

Constructors:
	fromRoot(rootPath): builds up a file system model from a root path on the file system. This will throw an error if the server can't be reached. This also starts up the connection.
	fromInstance(root): builds up a file system model from a root Instance in the DataModel. This does _not_ start up a connection.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "FilesystemModel: ", true);
local ServerRequests = require(script.Parent.Parent.ServerRequests);

local FilesystemModel = Utils.new("Class", "FilesystemModel");

FilesystemModel._Root = false;
FilesystemModel._Tree = false;
FilesystemModel._ChangedEvent = false;
FilesystemModel._PollKey = false;

FilesystemModel.Get.Root = "_Root";
FilesystemModel.Get.Tree = "_Tree";
FilesystemModel.Get.Changed = function(self) return self._ChangedEvent.Event; end

local SUFFIXES = {
	ModuleScript = ".module.lua";
	LocalScript = ".client.lua";
	Script = ".server.lua";
};

--[[ @brief Converts a path into its constituent parts.
	@param path The path to split up.
	@return path The path to the directory containing the file.
	@return filename The name of the file minus its suffix.
	@return suffix The _class_ of suffix (not the suffix itself).
--]]
local function SplitFilePath(path)
	local lastSlash = string.find(path, "/[^/]+$")
	local dir, filename;
	if lastSlash then
		dir = string.sub(path, 1, lastSlash - 1);
		filename = string.sub(path, lastSlash + 1)
	else
		dir, filename = "", path;
	end
	Debug("SplitFilePath: %s, %s", dir, filename);
	return dir, filename;
end

--[[ @brief The first part of the path will be chopped off as long as it matches `root`.
	@param path The path to clean up.
	@param root The part to remove.
	@return The path minus the root prefix.
--]]
local function RemoveRoot(path, root)
	Utils.Log.Assert(path:sub(1, #root) == root, "Path %s does not start with root %s", path, root);
	return path:sub(#root + 2);
end

--[[ @brief Takes input returned by the `parse` operation and makes it more usable (tables and such).
	@param tree A set of data where each line has a file path & a hash.
	@return A table of the following form:
		{
			{
				Path = "...";
				Hash = "...";
			},
			...
		}
--]]
local function SimplifyParseResult(tree)
	local s = {};
	for line in string.gmatch(tree, "[^\n]+") do
		--split the line into a path & hash.
		local i = string.find(line, " [^ ]*$");
		table.insert(s, {
			Path = string.sub(line, 1, i - 1);
			Hash = string.sub(line, i + 1);
		});
	end
	return s;
end

--[[ @brief Helper function for building up the tree.
	@param root The root of the tree. This should resemble a folder.
	@param path The path to the file.
	@param name The name of the file.
	@param entry A table with any additional info you'd like in the hierarchy.
--]]
local function AddEntryToTree(root, path, name, entry)
	--Make folders with a particular name as needed.
	for folder in string.gmatch(path, "[^/]+") do
		if not root.Children[folder] then
			root.Children[folder] = { Name = folder; Type = "folder"; FullPath = root.FullPath .. folder .. "/"; Parent = root; Children = {}; };
		end
		root = root.Children[folder];
	end
	entry.Parent = root;
	entry.FullPath = root.FullPath .. name;
	root.Children[name] = entry;
end

--[[ @brief Fetches a particular path in a tree.
--]]
local function GetEntryInTree(root, path, name)
	for folder in string.gmatch(path, "[^/]+") do
		if not root.Children[folder] then
			return nil;
		end
		root = root.Children[folder];
	end
	return root.Children[name];
end

--[[ @brief Queries the current state of the file hierarchy on the remote.
--]]
function FilesystemModel:_QueryServer()
	local _, parseResult = assert(ServerRequests.parse{
		File = self._Root;
		Depth = 0;
		Hash = true;
	});
	local parseResult = SimplifyParseResult(parseResult.Tree);
	local root = { Name = "<root>"; Type = "folder"; FullPath = ""; Children = {}; };
	for _, line in pairs(parseResult) do
		Debug("Path: %s", line.Path);
		local path, file = SplitFilePath(RemoveRoot(line.Path, self._Root));
		AddEntryToTree(root, path, file, { Name = file; Type = "file"; Hash = line.Hash});
	end
	self._Tree = root;
end

--[[ @brief Converts the FileChange parameter provided by the server into something more usable.
	@param text The text provided by the server.
	@return[1] A table of the form { Mode = "timeout"; }
	@return[2] A table of the form { Mode = "error"; Message = "error message"; }
	@return[3] A table of the form { Mode = "modify|add|delete"; FilePath = "path"; Hash = "hash"; }
--]]
local function SimplifyWatchPollResult(text)
	if text == "" then
		return {
			Mode = "timeout";
		};
	end
	local i = string.find(text, " ");
	local mode = text:sub(1, i - 1);
	if mode == "error" then
		return {
			Mode = mode;
			Message = text:sub(i + 1);
		}
	else
		local j, k = string.find(text, "'[^']+'", i + 1);
		Utils.Log.Assert(i + 1 == j, "text isn't what we thought: %s", text);
		return {
			Mode = mode;
			FilePath = text:sub(j + 1, k - 1);
			Hash = text:sub(k + 2);
		};
	end
end

--[[ @brief Starts watching a file hierarchy on the server.
--]]
function FilesystemModel:_StartWatching()
	if self._PollKey then
		self:_StopWatching();
	end
	local _, response = assert(ServerRequests.watch_start{
		File = self._Root;
	});
	self._PollKey = response.ID;
	local key = response.ID;
	spawn(function()
		while key == self._PollKey do
			local _, response = ServerRequests.watch_poll{
				ID = key;
			};
			Debug("watch_poll results: %s, %s", _, response);
			if key ~= self._PollKey then break; end
			Debug("Response: %0t", response);
			local result = SimplifyWatchPollResult(response.FileChange);
			Debug("SimplifiedWatchPollResult: %s --> %0t", response.FileChange, result);
			do
				return;
			end
			if mode == "modify" then
				--Find this object in our tree & update its hash.
				local path, filename = SplitFilePath(response.FilePath);
				local obj = GetEntryInTree(self._Tree, path, filename);
				if obj then
					obj.Hash = response.Hash;
				else
					AddEntryToTree(self._Tree, path, filename, { Hash = response.Hash; });
				end
				self._ChangedEvent:Fire();
			elseif mode == "error" then
				if result.Message == "ID_NO_LONGER_VALID" then
					self._PollKey = false; --we implicitly have stopped watching.
				end
			elseif mode == "add" then
				local path, filename = SplitFilePath(response.FilePath);
				AddEntryToTree(self._Tree, path, filename, { Hash = response.Hash; });
				self._ChangedEvent:Fire();
			elseif mode == "delete" then
				local obj = GetEntryInTree(self._Tree, path, filename);
				if obj and obj.Parent then
					obj.Parent.Children[obj.Name] = nil;
					self._ChangedEvent:Fire();
				end
			end
		end
	end);
end

--[[ @brief Stops watching a file hierarchy on the server.
--]]
function FilesystemModel:_StopWatching()
	if self._PollKey then
		ServerRequests.watch_stop{
			ID = self._PollKey;
		};
		self._PollKey = false;
	end
end

--[[ @brief Compares against another FilesystemModel.
--]]
function FilesystemModel:Compare(other)
	local comparison = {};
	local pseudoFolder = { Name = "<PseudoFolder>"; Type = "folder"; Children = {}};
	local function Compare(a, b)
		if a.Type == "folder" and b.Type == "folder" then
			for i, v in pairs(a.Children) do
				if b.Children[i] then
					Compare(v, b.Children[i]);
				else
					--We only have the entry in `a`.
					if v.Type == "file" then
						table.insert(comparison, { Name = v.FullPath; Comparison = "selfOnly"; });
					elseif v.Type == "folder" then
						Compare(v, pseudoFolder);
					end
				end
			end
			for i, v in pairs(b.Children) do
				if not a.Children[i] then
					--We only have the entry in `b`.
					if v.Type == "file" then
						table.insert(comparison, { Name = v.FullPath; Comparison = "otherOnly"; });
					elseif v.Type == "folder" then
						Compare(pseudoFolder, v);
					end
				end
			end
		elseif a.Type == "file" and b.Type == "file" then
			if a.Hash == b.Hash then
				table.insert(comparison, { Name = a.FullPath; Comparison = "synced"; });
			else
				table.insert(comparison, { Name = a.FullPath; Comparison = "desynced"; });
			end
		elseif a.Type == "file" and b.Type == "folder" then
			table.insert(comparison, { Name = a.FullPath; Comparison = "selfOnly"; });
			Compare(pseudoFolder, b);
		elseif a.Type == "folder" and b.Type == "file" then
			table.insert(comparison, { Name = b.FullPath; Comparison = "otherOnly"; });
			Compare(a, pseudoFolder);
		end
	end
	Compare(self._Tree, other._Tree);
	return comparison;
end

--[[ @brief Cleans up this instance.
--]]
function FilesystemModel:Destroy()
	self:_StopWatching();
end

--[[ @brief Instantiates a new FilesystemModel.

	This is not meant to be called directly. Instead, use fromRoot or fromInstance.
--]]
function FilesystemModel.new()
	local self = setmetatable({}, FilesystemModel.Meta);
	self._ChangedEvent = Instance.new("BindableEvent");
	return self;
end

--[[ @brief Creates a new file system model by querying the SyncyTowne server & starting up a watch.
	@param rootPath The path which we will query & watch.
	@return The file system model.
--]]
function FilesystemModel.fromRoot(rootPath)
	local self = FilesystemModel.new();
	self._Root = rootPath;
	self:_QueryServer();
	self:_StartWatching();
	return self;
end

--[[ @brief Creates a file system hierarchy using an Instance from the DataModel.
	@param root An instance in the data model.
	@return The file system model.
--]]
function FilesystemModel.fromInstance(root)
	local tree = { Name = "<root>"; Type = "folder"; FullPath = ""; Children = {}; };
	--Find all Scripts, ModuleScripts, or LocalScripts in root and add them to the tree.
	local function recurse(node, path)
		if SUFFIXES[node.ClassName] then
			local filename = node.Name .. SUFFIXES[node.ClassName];
			AddEntryToTree(tree, path, filename, {
				Name = filename;
				Type = "file";
				Hash = tostring(string.len(node.Source));
			});
		end
		path = path .. node.Name .. "/";
		for i, v in pairs(node:GetChildren()) do
			recurse(v, path);
		end
	end
	recurse(root, "");
	local self = FilesystemModel.new();
	self._Tree = tree;
	return self;
end

local function PrintTree(t, prefix)
	prefix = prefix or "";
	if t.Children then
		Debug("* %s%s", prefix, t.FullPath);
		for i, v in pairs(t.Children) do
			PrintTree(v, prefix .. "    ");
		end
	else
		Debug("* %s%s (%s)", prefix, t.FullPath, t.Hash);
	end
end

function FilesystemModel.Test()
	local f1 = FilesystemModel.fromRoot("SyncyTowne/server/testdir2");
	local f2 = FilesystemModel.fromInstance(game.ServerStorage.Folder);
	Debug("fromRoot:")
	PrintTree(f1.Tree);
	Debug("fromInstance:")
	PrintTree(f2.Tree);
	Debug("Difference: %0t", f1:Compare(f2));
	f1:Destroy();
	f2:Destroy();
end

return FilesystemModel;
