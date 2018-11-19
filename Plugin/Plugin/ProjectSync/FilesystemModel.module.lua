--[[

Represents the filesystem using Lua tables.

Properties:
	Root (string, read-only): the root of the project relative to the global root. This will be `false` if we're not syncing to the file system.
	Tree (read-only): the tree representing the contents of the filesystem. Each entry can be one of the following:
			{ Name = "<filename>",    Type = "file",   FullPath = "<full path>", Parent = <parent>, Hash = "<hash>" }
			{ Name = "<folder name>", Type = "folder", FullPath = "<full path>", Parent = <parent>, Children = {<children indexed by name>} }
		Note that in the case of a folder, children are recursively one of the aforementioned two types.
	Connected (read-only): when true, we are successfully talking to the server.

Events:
	Changed(filepath): fires when any file changes (be it added, removed, etc.)

Methods:
	Destroy(): cleans up this instance.

Constructors:
	fromRoot(rootPath): builds up a file system model from a root path on the file system. This will throw an error if the server can't be reached. This also starts up the connection.
	fromInstance(root): builds up a file system model from a root Instance in the DataModel. This does _not_ start up a connection.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "FilesystemModel: ", false);
local ServerRequests = require(script.Parent.Parent.ServerRequests);
local Helpers = require(script.Parent.Helpers);

local SUFFIXES = Helpers.SUFFIXES;
local SplitFilePath = Helpers.SplitFilePath;
local RemoveRoot = Helpers.RemoveRoot;

local FilesystemModel = Utils.new("Class", "FilesystemModel");

FilesystemModel._Root = false;
FilesystemModel._Tree = false;
FilesystemModel._FileChangedEvent = false;
FilesystemModel._PropertyChangedEvent = false; --Oops. Changed used to be used for file changes, despite that property changes are canonical for the "Changed" event.
FilesystemModel._PollKey = false;
FilesystemModel._Connected = false;

FilesystemModel.Get.Root = "_Root";
FilesystemModel.Get.Tree = "_Tree";
FilesystemModel.Get.Changed = function(self) Utils.Log.Warning("Use FileChanged, not Changed"); return self._FileChangedEvent.Event; end
FilesystemModel.Get.FileChanged = function(self) return self._FileChangedEvent.Event; end
FilesystemModel.Get.PropertyChanged = function(self) return self._PropertyChangedEvent.Event; end
FilesystemModel.Get.Connected = "_Connected";

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

	entry.Type = entry.Type or "file";
	entry.Name = name;

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
	local success, parseResult = ServerRequests.parse{
		File = self._Root;
		Depth = 0;
		Hash = true;
	};
	if success then
		local parseResult = SimplifyParseResult(parseResult.Tree);
		local root = { Name = "<root>"; Type = "folder"; FullPath = ""; Children = {}; };
		for _, line in pairs(parseResult) do
			Debug("Path: %s", line.Path);
			local path, file = SplitFilePath(RemoveRoot(line.Path, self._Root));
			AddEntryToTree(root, path, file, { Name = file; Type = "file"; Hash = line.Hash});
		end
		self._Tree = root;
		self._Connected = true;
		self._PropertyChangedEvent:Fire("Connected");
	else
		self._Connected = false;
	end
end

--[[ @brief Converts the FileChange parameter provided by the server into something more usable.
	@param text The text provided by the server.
	@return[1] A table of the form { Mode = "timeout"; }
	@return[2] A table of the form { Mode = "error"; Message = "error message"; }
	@return[3] A table of the form { Mode = "modify|add|delete"; FilePath = "path"; Hash = "hash"; }
--]]
local function SimplifyWatchPollResult(text)
	if text == nil then
		return { Mode = "failure"; };
	elseif text == "" then
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
	local success, response = ServerRequests.watch_start{
		File = self._Root;
	};
	if not success then
		if self._Connected ~= false then
			self._Connected = false;
			self._PropertyChangedEvent:Fire("Connected");
			Debug("Failed to start watching remote");
		end
		return;
	end
	self._PollKey = response.ID;
	local key = response.ID;
	spawn(function()
		local failures = 0;
		while key == self._PollKey and failures <= 2 do
			failures = failures + 1;
			local success, response = ServerRequests.watch_poll{
				ID = key;
			};
			Debug("watch_poll results: %s, %s", success, response);
			if key ~= self._PollKey then break; end
			Debug("Response: %0t", response);
			local result = SimplifyWatchPollResult(response.FileChange);
			Debug("SimplifiedWatchPollResult: %s --> %0t", response.FileChange, result);
			if result.Mode == "modify" then
				failures = 0;
				--Find this object in our tree & update its hash.
				local path, filename = SplitFilePath(RemoveRoot(result.FilePath, self._Root));
				local obj = GetEntryInTree(self._Tree, path, filename);
				if obj then
					obj.Hash = result.Hash;
				else
					AddEntryToTree(self._Tree, path, filename, { Hash = result.Hash; });
				end
				self._FileChangedEvent:Fire(path .. "/" .. filename);
			elseif result.Mode == "error" then
				if result.Message == "ID_NO_LONGER_VALID" then
					self._PollKey = false; --we implicitly have stopped watching.
				else
					Debug("Unexpected error; terminating connection");
					break;
				end
			elseif result.Mode == "add" then
				failures = 0;
				local path, filename = SplitFilePath(RemoveRoot(result.FilePath, self._Root));
				local entry = { Hash = result.Hash; };
				AddEntryToTree(self._Tree, path, filename, entry);
				Debug("New Entry: %t", entry);
				self._FileChangedEvent:Fire(path .. "/" .. filename);
			elseif result.Mode == "delete" then
				failures = 0;
				local path, filename = SplitFilePath(RemoveRoot(result.FilePath, self._Root));
				local obj = GetEntryInTree(self._Tree, path, filename);
				if obj and obj.Parent then
					obj.Parent.Children[obj.Name] = nil;
					self._FileChangedEvent:Fire(path .. "/" .. filename);
				end
			elseif result.Mode == "timeout" then
				--Not a big deal! We'll just poll again.
				failures = 0;
			elseif result.Mode == "failure" then
			else
				Debug("Unexpected mode: %s", result.Mode);
			end
		end
		if key == self._PollKey then
			self._Connected = false;
			self._PropertyChangedEvent:Fire("Connected");
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
	self._FileChangedEvent = Instance.new("BindableEvent");
	self._PropertyChangedEvent = Instance.new("BindableEvent");
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
	local SetExpectations, WaitForExpectations; do
		--@brief Convert tree to mappy boi
		local function ConvertFolder(t)
			local r = {};
			for i, v in pairs(t.Children) do
				if v.Type == "folder" then
					r[v.Name] = ConvertFolder(v);
				elseif v.Type == "file" then
					r[v.Name] = v.Hash;
				end
			end
			return r;
		end
		--@brief Compares expected to actual.
		local function ExpectationMatch(expected, actual)
			local function Recurse(A, B)
				for i, a in pairs(A) do
					local b = B[i];
					if b == nil then
						Utils.Log.Error("Key %s doesn't match; expected %s, got %s", i, a, b);
					elseif type(a) ~= type(b) then
						Utils.Log.Error("Key %s doesn't match; expected type is %s, got %s", i, type(a), type(b));
					elseif type(a) == "table" then
						local success, str = pcall(Recurse, a, b);
						if not success then
							Utils.Log.Error("Key %s doesn't match\n%s", i, str);
						end
					else
						if a ~= b then
							Utils.Log.Error("Key %s doesn't match; expected %s, got %s", i, a, b);
						end
					end
				end
				for i, b in pairs(A) do
					local a = A[i];
					if a == nil then
						Utils.Log.Error("Key %s doesn't match; expected nil, got %s", i, a, b);
					end
				end
			end
			actual = ConvertFolder(actual);
			local success, str = pcall(Recurse, expected, actual);
			if success then
				return true;
			else
				return false, Utils.Log.Format("Mismatch!\n%s\nExpected: %0t\nActual: %0t", str, expected, actual);
			end
		end
		local expectations = {};
		local nextIndex = 1;
		local failState = false;
		local condition = Instance.new("BindableEvent");
		f1.Changed:connect(function()
			Debug("Changed fired (waiting on %s)", nextIndex);
			if not expectations[nextIndex] then
				failState = true;
				Utils.Log.Error("Received unexpected Changed event\n%0t", f1.Tree);
			end
			--Ensure f1.Tree matches the front of the expectation queue.
			--If it does, pop it from the queue. If we're down to 0, fire condition.
			local checkExpectations, errStr = ExpectationMatch(expectations[nextIndex], f1.Tree);
			if checkExpectations then
				nextIndex = nextIndex + 1;
				if nextIndex > #expectations then
					condition:Fire();
				end
			elseif nextIndex > 1 and ExpectationMatch(expectations[nextIndex - 1], f1.Tree) then
				--Sometimes spurious, duplicate notifications occur. This isn't a big deal.
			else
				failState = true;
				Utils.Log.Error("%s", errStr);
			end
		end);
		--@brief Assert that, when the Changed event fires, the tree will have the given form.
		function SetExpectations(tree)
			table.insert(expectations, Utils.Table.DeepCopy(tree));
		end
		--@brief Yields until all expectations are met. Will throw if it times out.
		function WaitForExpectations(timeout)
			if not timeout then timeout = .4; end
			if failState then
				Utils.Log.Error("Expectation failed");
			end
			Debug("%d expectations have been met; expecting %d", nextIndex - 1, #expectations);
			if nextIndex <= #expectations then
				local timerRunning = true;
				spawn(function()
					wait(timeout);
					if timerRunning then
						condition:Fire();
					end
				end);
				condition.Event:Wait();
				timerRunning = false;
				if nextIndex <= #expectations then
					Utils.Log.Error("Timed out in waiting");
				end
			end
		end
	end
	local baseExpectation = {
		Folder = {
			["Subfolder.server.lua"] = "22";
			["Script.server.lua"] = "23";
			Subfolder = {
				["ModuleScript.module.lua"] = "33";
				["LocalScript.client.lua"] = "22";
			};
		};
	};

	baseExpectation.Folder["Script.server.lua"] = "7";
	SetExpectations(baseExpectation);
	ServerRequests.write{File = "SyncyTowne/server/testdir2/Folder/Script.server.lua", Contents = "foobar\n"};
	WaitForExpectations();

	baseExpectation.Folder["Script.server.lua"] = "23";
	SetExpectations(baseExpectation);
	ServerRequests.write{File = "SyncyTowne/server/testdir2/Folder/Script.server.lua", Contents = "print('Hello, World!');"};
	WaitForExpectations();

	baseExpectation.Folder["NewScript.server.lua"] = "7";
	SetExpectations(baseExpectation);
	ServerRequests.write({File = "SyncyTowne/server/testdir2/Folder/NewScript.server.lua", Contents = "foobar\n"; });
	WaitForExpectations();

	baseExpectation.Folder["NewScript.server.lua"] = nil;
	SetExpectations(baseExpectation);
	ServerRequests.delete{File = "SyncyTowne/server/testdir2/Folder/NewScript.server.lua"};
	WaitForExpectations();

	f1:Destroy();
end

return FilesystemModel;
