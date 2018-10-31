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
	Destroy(): cleans up this instance.

Constructors:
	fromRoot(rootPath): builds up a file system model from a root path on the file system. This will throw an error if the server can't be reached. This also starts up the connection.
	fromInstance(root): builds up a file system model from a root Instance in the DataModel. This does _not_ start up a connection.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "FilesystemModel: ", true);
local ServerRequests = require(script.Parent.Parent.ServerRequests);
local Helpers = require(script.Parent.Helpers);

local SUFFIXES = Helpers.SUFFIXES;
local SplitFilePath = Helpers.SplitFilePath;
local RemoveRoot = Helpers.RemoveRoot;

local FilesystemModel = Utils.new("Class", "FilesystemModel");

FilesystemModel._Root = false;
FilesystemModel._Tree = false;
FilesystemModel._ChangedEvent = false;
FilesystemModel._PollKey = false;

FilesystemModel.Get.Root = "_Root";
FilesystemModel.Get.Tree = "_Tree";
FilesystemModel.Get.Changed = function(self) return self._ChangedEvent.Event; end

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
	f1:Destroy();
end

return FilesystemModel;
