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

local Utils = require(script.Parent.Utils);
local Debug = Utils.new("Log", "ProjectSync: ", true);
local TableComparisonDebug = Utils.new("Log", "ProjectSync: ", false);
local HashModule = require(script.Hash);

--DifferenceType enum
local ONLY_IN_STUDIO = "OnlyInStudio";
local ONLY_ON_FILESYSTEM = "OnlyOnFilesystem";
local SOURCE_MISMATCH = "SourceMismatch";
local SOURCE_EQUAL = "SourceEqual";

local ProjectSync = Utils.new("Class", "ProjectSync");

ProjectSync._Project = false;
ProjectSync._DifferenceCount = 0;
ProjectSync._AutoSync = false;
ProjectSync._Differences = false; --A map of files which differ locally/remotely. [FilePath] -> [ScriptReference]
ProjectSync._ChangedEvent = false;
ProjectSync._ScriptChangeEvent = false; --An event which fires any time a script changes. Fingerprint: function(origin, remoteFileName, localScriptReference) where origin is "Local" or "Remote".
ProjectSync._Cxns = false;
ProjectSync._RemoteWatchID = false;
ProjectSync._ListOfFiles = false; --A list of files which this project entails. Each entry is the following: {FilePath, ScriptInStudio, DifferenceType}
ProjectSync._PullRequiresFolderCreationValue = false;
ProjectSync._PushWillDeleteFilesValue = false;

ProjectSync.Get.Project = "_Project";
ProjectSync.Get.DifferenceCount = "_DifferenceCount";
ProjectSync.Get.AutoSync = "_AutoSync";
function ProjectSync.Get:Changed() return self._ChangedEvent.Event; end
ProjectSync.Get.PullingWillCreateFolders = "_PullRequiresFolderCreationValue";
ProjectSync.Get.PushingWillDeleteFiles = "_PushWillDeleteFilesValue";

local CLASS_TO_SUFFIX = {
	ModuleScript = ".module.lua";
	LocalScript = ".client.lua";
	Script = ".server.lua";
}
local function RemoveSuffix(filepath)
	for i, v in pairs(CLASS_TO_SUFFIX) do
		if filepath:sub(-#v) == v then
			return filepath:sub(1, -#v - 1), i;
		end
	end
end
local function RemovePrefix(filepath, remote)
	Utils.Log.Assert(remote == filepath:sub(1, #remote), "Remote filepath doesn't appear to be in correct directory; path is %s, expected to be in %s", filepath, remote);
	filepath = filepath:sub(#remote + 2);
	return filepath;
end

local function InvokeCommand(command)
	local result = game:GetService("HttpService"):PostAsync("http://127.0.0.1:605", command)
	return result;
end

function HashSource(source)
	return HashModule.Hash(source);
end

--@brief Gets the script's remote filepath representation.
--@details For example, workspace.Folder.MyScript might be represented as MyProject/Folder/MyScript.server.lua
--@param s The script to get the remote filepath representation of.
local function GetRemoteScript(self, s)
	local original = s;
	local root = self._Project.Local;
	local t = {};
	table.insert(t, s.Name .. CLASS_TO_SUFFIX[s.ClassName]);
	if s ~= root then
		s = s.Parent;
		while s and s ~= root do
			table.insert(t, 1, s.Name);
			s = s.Parent;
		end
		if s == root then
			--We could potentially not add the root if the root's class is a folder or some non-property-having class.
			--We'll cross that bridge when we get there, though.
			table.insert(t, 1, s.Name);
		end
	end
	table.insert(t, 1, self._Project.Remote);
	local retval = table.concat(t, "/");
	Debug("GetRemoteScript(%s) = %s", original:GetFullName(), retval);
	return retval;
end

--@brief Gets the script in the DataModel given its filepath.
local function GetLocalScript(self, filepath)
	local originalFilepath = filepath;
	local root = self._Project.Local;
	filepath = RemovePrefix(filepath, self._Project.Remote);
	local filepath, className = RemoveSuffix(filepath);
	if filepath:sub(1, #root.Name + 1) == root.Name .. "/" or filepath == root.Name then
		filepath = filepath:sub(#root.Name + 2);
	end
	for name in string.gmatch(filepath, "[^/]+") do
		local nextRoot = root:FindFirstChild(name);
		if not nextRoot then
			Debug("Failed to find %s in %s when getting local script for remote %s", name, root:GetFullName(), originalFilepath);
			--We failed to find the script.
			return nil;
		end
		root = nextRoot;
	end
	if root.ClassName == className then
		return root;
	else
		--Some sort of class mismatch.
		Debug("Class Mismatch when getting local script for remote %s; expected %s, got %s", originalFilepath, className, root.ClassName);
		return nil;
	end
end

--@brief Creates a script in studio given the remote file path.
--@param filepath The remote filepath.
local function CreateLocalScript(self, filepath)
	filepath = RemovePrefix(filepath, self._Project.Remote);

	Debug("Creating Local Script for remote script %s", filepath);
	local root = self._Project.Local;
	local function foreach(generator)
		local s = {};
		for x in generator do
			table.insert(s, x)
		end
		return unpack(s)
	end
	local dirs = {foreach(string.gmatch(filepath, "[^/]+"))}
	for i = 2, #dirs do
		local s = dirs[i];
		if root:FindFirstChild(s) then
			root = root:FindFirstChild(s);
		else
			if i == #dirs then
				--this is the final item. Create the script.
				local nameWithoutSuffix, className = RemoveSuffix(s);
				Utils.Log.Assert(className, "Remote script %s has bad suffix", filepath);
				Debug("Creating a %s in %s with name %s", className, root:GetFullName(), s)
				local existing = root:FindFirstChild(nameWithoutSuffix);
				local script = Instance.new(className);
				script.Name = nameWithoutSuffix
				script.Parent = root;
				if existing and existing:IsA("Folder") then
					--It's OK to delete this; we'll just swap the children over to the new script.
					for i, v in pairs(existing:GetChildren()) do
						v.Parent = script;
					end
					existing:Destroy();
				end
				return script;
			else
				Utils.Log.Warn("Creating a folder in %s with name %s", root:GetFullName(), s)
				--create a folder I guess?
				local f = Instance.new("Folder");
				f.Name = s;
				f.Parent = root;
				root = f;
			end
		end
	end
end

--@brief Gets the complete mapping of [filepath] -> [script] where script is the Instance in data model.
local function GetLocalScripts(self)
	--TODO: we'll some day want to do filename scrubbing.
	--Consider: certain files/directory names are forbidden, such as AUX in Windows
	--Consider: in windows, the same file lowercase/uppercase are the same.
	--Consider: in FAT32, certain characters are forbidden: <>:"/\|?*
	local hashes = {};
	local function Recurse(obj, prefix)
		prefix = prefix .. "/" .. obj.Name
		if obj:IsA("LuaSourceContainer") then
			hashes[prefix .. CLASS_TO_SUFFIX[obj.ClassName]] = obj;
		end
		for i, v in pairs(obj:GetChildren()) do
			Recurse(v, prefix);
		end
	end
	Recurse(self._Project.Local, self._Project.Remote);
	return hashes;
end

--[[@brief Compares two tables and prints a table reflecting their differences.
	@param a A table mapping string to string.
	@param b A table mapping string to string.
--]]
local function TableComparison(a, b, aname, bname)
	if not aname then aname = "A"; end
	if not bname then bname = "B"; end

	--First print all keys that differ
	local header = false;
	for key, a in pairs(a) do
		local b = b[key];
		if b and a ~= b then
			if not header then header = true; TableComparisonDebug("%s", "====================\nDiffering Keys\n===================="); end
			TableComparisonDebug("%s", key);
			TableComparisonDebug("%s", "\t" .. aname .. ": " .. a);
			TableComparisonDebug("%s", "\t" .. bname .. ": " .. b);
		end
	end

	--Then print all keys which are only in one of the two tables.
	header = false;
	for key, a in pairs(a) do
		local b = b[key];
		if not b then
			if not header then header = true; TableComparisonDebug("%s", "====================\nKeys only in " .. aname .. "\n===================="); end
			TableComparisonDebug("%s", key .. "\t" .. a);
		end
	end
	header = false;
	for key, b in pairs(b) do
		local a = a[key];
		if not a then
			if not header then header = true; TableComparisonDebug("%s", "====================\nKeys only in " .. bname .. "\n===================="); end
			TableComparisonDebug("%s", key .. "\t" .. b);
		end
	end

	--Then print keys which are identical.
	header = false;
	for key, a in pairs(a) do
		local b = b[key];
		if b and a == b then
			if not header then header = true; TableComparisonDebug("%s", "====================\nMatching Keys\n===================="); end
			TableComparisonDebug("%s", key .. "\t" .. a);
		end
	end
end

--@brief Gets the complete list of remote scripts, then compares it to the complete list of local scripts.
function ProjectSync:CheckSync()
	--Fetch hashes for remote files.
	local ParseFetch = InvokeCommand("parse\n" .. self._Project.Remote .. "\n0\nTrue");
	local RemoteHashes = {};
	for file, hash in string.gmatch(ParseFetch, "([^\n]*) ([0-9a-fA-F]+)") do
		if RemoveSuffix(file) then
			RemoteHashes[file] = hash;
		end
	end

	--We "hash" by just getting the file length. It's easy to get collisions, even accidentally, but ... we can fix it some other day.
	--In an ideal world, roblox would implement an MD5 algorithm in C++, because it's prohibitively expensive in Lua.
	local LocalScripts = GetLocalScripts(self);
	local LocalHashes = {};
	for i, v in pairs(LocalScripts) do
		local hash = HashSource(v.Source)
		LocalHashes[i] = hash;
	end

	TableComparison(RemoteHashes, LocalHashes, "RemoteHashes", "LocalHashes");

	local fullFileList = {};
	local differ = {};
	local count = 0;
	for file, hash in pairs(RemoteHashes) do
		if not LocalHashes[file] then
			table.insert(fullFileList, {file, LocalScripts[file], ONLY_ON_FILESYSTEM})
		elseif LocalHashes[file] ~= hash then
			table.insert(fullFileList, {file, LocalScripts[file], SOURCE_MISMATCH});
		elseif LocalHashes[file] == hash then
			table.insert(fullFileList, {file, LocalScripts[file], SOURCE_EQUAL});
		end
		if LocalHashes[file] ~= hash then
			differ[file] = LocalScripts[file] or false;
			count = count + 1;
		end
	end
	for file, hash in pairs(LocalHashes) do
		if not RemoteHashes[file] then
			table.insert(fullFileList, {file, LocalScripts[file], ONLY_IN_STUDIO});
		end
		if RemoteHashes[file] ~= hash and not differ[file] then
			differ[file] = LocalScripts[file] or false;
			count = count + 1;
		end
	end

	table.sort(fullFileList, function(a, b) return a[1] < b[1]; end);
	self._ListOfFiles = fullFileList;

	self._DifferenceCount = count;
	self._Differences = differ;

	self:_PullRequiresFolderCreation()
	self:_PushWillDeleteFiles();

	self._ChangedEvent:Fire("DifferenceCount");
	self._ChangedEvent:Fire("Differences");
end

--[[ @brief Checks if pulling will require that we create folders locally.

	This sets the member variables appropriately.
--]]
function ProjectSync:_PullRequiresFolderCreation()
	--Hunt through the entire list of files. Any which are ONLY_ON_FILESYSTEM will
	--require scripts to be created locally. If we can't find a suitable parent for
	--a folder will be created.
	local AddEntry;
	local NodeMeta = {
		__index = function(t, i)
			AddEntry(t, i, true);
			return rawget(t, i);
		end;
		__call = function(t, i)
			AddEntry(t, i, false);
		end;
	}
	function AddEntry(t, i, foldersRequired)
		local root = rawget(t, "Root");
		if root:FindFirstChild(i) then
			Debug("Found child %s", i);
			rawset(t, i, setmetatable({Root = root:FindFirstChild(i); FoldersRequired = rawget(t, "FoldersRequired")}, NodeMeta));
		else
			Debug("Did not find child %s", i);
			rawset(t, i, setmetatable({Root = Instance.new("Folder"); FoldersRequired = foldersRequired or rawget(t, "FoldersRequired");}, NodeMeta));
		end
	end
	local tree = setmetatable({Root = self._Project.Local; FoldersRequired = false;}, NodeMeta);
	local FIRST_ITERATION = {};
	local function IsFoldersRequired(path)
		Debug("Path: %s", path);
		Debug("Remote Root: %s", self._Project.Remote);
		path = RemovePrefix(path, self._Project.Remote);
		local r = tree;
		local last = FIRST_ITERATION;
		for s in string.gmatch(path, "[^/]+") do
			if last and last ~= FIRST_ITERATION then
				Debug("Recursing into %s", last);
				r = r[last];
			end
			if last == FIRST_ITERATION then
				last = nil;
			else
				last = s;
			end
		end
		if last then
			local scriptName = RemoveSuffix(last);
			r(scriptName);
			return r[scriptName].FoldersRequired;
		else
			return r;
		end
	end
	local pullFolders = {};
	for i, v in pairs(self._ListOfFiles) do
		local serverPath, clientReference, state = unpack(v);
		if state == ONLY_ON_FILESYSTEM then
			if IsFoldersRequired(serverPath) then
				table.insert(pullFolders, serverPath);
			end
		end
	end
	self._PullRequiresFolderCreationValue = #pullFolders > 0 and pullFolders;
	Debug("Recomputed PullingWillCreateFolders to %s", self._PullRequiresFolderCreationValue);
end

--[[ @brief Checks if pushing will result in deleted files remotely.

	This sets the member variables appropriately.
--]]
function ProjectSync:_PushWillDeleteFiles()

end

--@brief Pushes any script mismatches to the remote.
--@param filepath If supplied, we only push changes for this script.
function ProjectSync:Push(filepath)
	if filepath then
		Debug("Pushing %s", filepath);
		local s = GetLocalScript(self, filepath);
		if s then
			InvokeCommand(string.format("write\n%s\n%s", filepath, s.Source));
		else
			InvokeCommand(string.format("delete\n%s", filepath));
		end
		if self._Differences[filepath] then
			for i, v in pairs(self._ListOfFiles) do
				if v[1] == filepath then
					v[3] = "SourceEqual";
				end
			end
			self._Differences[filepath] = nil;
			self._DifferenceCount = self._DifferenceCount - 1;
			self._ChangedEvent:Fire("DifferenceCount");
			self._ChangedEvent:Fire("Differences");
		end
	else
		for file, s in pairs(self._Differences) do
			if s then
				InvokeCommand(string.format("write\n%s\n%s", file, s.Source));
			else
				InvokeCommand(string.format("delete\n%s", file));
			end
		end
		self:CheckSync();
	end
end

--@brief Fetches the source for any scripts which mismatch.
--@param filepath If supplied, we only pull changes for this script.
function ProjectSync:Pull(s)
	if filepath then
		Debug("Pulling %s", filepath);
		local s = GetLocalScript(self, filepath);
		if not s then
			s = CreateLocalScript(self, filepath);
		end
		s.Source = InvokeCommand(string.format("read\n%s", filepath));
		if self._Differences[filepath] then
			for i, v in pairs(self._ListOfFiles) do
				if v[1] == filepath then
					v[3] = "SourceEqual";
				end
			end
			self._Differences[filepath] = nil;
			self._DifferenceCount = self._DifferenceCount - 1;
			self._ChangedEvent:Fire("DifferenceCount");
			self._ChangedEvent:Fire("Differences");
		end
	else
		for file, s in pairs(self._Differences) do
			if not (type(s) == "userdata" and typeof(s) == "Instance" and (s:IsA("Script") or s:IsA("ModuleScript"))) then
				--We don't have a local equivalent, so it's time to create one!
				s = CreateLocalScript(self, file)
			end
			if s then
				s.Source = InvokeCommand(string.format("read\n%s", file));
			end
		end
		self:CheckSync();
	end
end

--@brief Sets whether or not we will do automatic syncing for this project.
function ProjectSync:SetAutoSync(value)
	self:CheckSync();
	if value and self._DifferenceCount > 0 then
		error("Cannot start auto-sync with unsynced sources");
	end
	if value then
		local ScreenRemoteChanges = 0;
		local BufferLocalChanges = {};
		local QueuedChanges = 0;
		self._Cxns.UpdateOnAutoSync = self._ScriptChangeEvent.Event:Connect(function(location, path, s)
			Debug("Location: %s; Path: %s; Script: %s", math.random(100), location, path, s and s:GetFullName() or "nil");
			if location == "Local" then
				if s then
					if not BufferLocalChanges[s] then
						QueuedChanges = QueuedChanges + 1;
						BufferLocalChanges[s] = 0;
					else
						BufferLocalChanges[s] = BufferLocalChanges[s] + 1;
					end
					local t = BufferLocalChanges[s];
					wait(3);
					if t == BufferLocalChanges[s] then
						BufferLocalChanges[s] = nil;
						QueuedChanges = QueuedChanges - 1;
						ScreenRemoteChanges = tick() + .5;
						self:Push(path);
					end
				else
					ScreenRemoteChanges = tick() + .5;
					self:Push(path);
				end
			elseif location == "Remote" then
				if tick() > ScreenRemoteChanges then
					self:Pull(path);
				end
			end
		end);
		local loopStarted = false;
		self._Cxns.DifferenceCountChanged = self._ChangedEvent.Event:Connect(function(property)
			if property == "DifferenceCount" then
				if not loopStarted then
					loopStarted = true;
					--Wait 5 frames. If we still have differences, this is our sign to terminate auto-sync mode.
					for i = 1, 5 do
						if self.DifferenceCount - QueuedChanges == 0 then break; end
						wait();
					end
					if self.DifferenceCount - QueuedChanges ~= 0 then
						self:SetAutoSync(false);
					end
				end
			end
		end);
	else
		self._Cxns.UpdateOnAutoSync = nil;
		self._Cxns.DifferenceCountChanged = nil;
	end
	self._AutoSync = value;
	self._ChangedEvent:Fire("AutoSync");
end

--@brief Listens for changes that occur to scripts within self._Project.Local.
--
--This should also include scripts which are added/removed.
function ProjectSync:_ListenForLocalChanges()
	local function ListenOnSourceChange(script)
		local remoteFileName = GetRemoteScript(self, script);
		self._Cxns.SourceChangedCxns[script] = script:GetPropertyChangedSignal("Source"):Connect(function()
			--if the source changes, make sure we're in the _Differences map.
			if not self._Differences[remoteFileName] then
				self._Differences[remoteFileName] = script;
				self._DifferenceCount = self._DifferenceCount + 1;
				self._ScriptChangeEvent:Fire("Local", remoteFileName, script);
				self._ChangedEvent:Fire("Differences");
				self._ChangedEvent:Fire("DifferenceCount");
			end
		end);
		self._Cxns.NameChangedCxns[script] = script:GetPropertyChangedSignal("Name"):Connect(function()
			local oldName = remoteFileName;
			remoteFileName = GetRemoteScript(self, script);
			local Changes = {};
			local function RegisterChange(filename, script)
				Debug("RegisterChange(%s, %s) called", filename, script);
				if self._Differences[filename] == nil then
					self._DifferenceCount = self._DifferenceCount + 1;
				end
				self._Differences[filename] = script;
				table.insert(Changes, {filename, script ~= false and script or nil});
			end
			local oldPrefix = RemoveSuffix(oldName) .. "/";
			local newPrefix = RemoveSuffix(remoteFileName);
			local function RecursiveChange(root)
				local newPath = GetRemoteScript(self, root);
				RegisterChange(oldPrefix .. RemovePrefix(newPath, newPrefix), false)
				RegisterChange(newPath, root)
				for i, v in pairs(root:GetChildren()) do
					RecursiveChange(v);
				end
			end
			for i, v in pairs(script:GetChildren()) do
				RecursiveChange(v, RemoveSuffix(oldName), RemoveSuffix(remoteFileName));
			end
			RegisterChange(oldName, false);
			RegisterChange(remoteFileName, script);

			for i = #Changes, 1, -1 do
				self._ScriptChangeEvent:Fire("Local", unpack(Changes[i]));
			end
			self._ChangedEvent:Fire("Differences");
			self._ChangedEvent:Fire("DifferenceCount");
		end);
	end
	--listen for DescendantAdded or DescendantRemoving.
	self._Cxns.DescendantAdded = self._Project.Local.DescendantAdded:Connect(function(child)
		if child:IsA("Script") or child:IsA("ModuleScript") then
			ListenOnSourceChange(child);
			self:CheckSync();
		end
	end);
	self._Cxns.DescendantRemoving = self._Project.Local.DescendantRemoving:Connect(function(child)
		self:CheckSync();
	end);
	--For all scripts we currently know about, start listening for source changes.
	for filename, script in pairs(GetLocalScripts(self)) do
		ListenOnSourceChange(script);
	end
end

--@brief Listens for changes that occur to scripts within self._Project.Remote (on the remote server).
function ProjectSync:_ListenForRemoteChanges()
	spawn(function()
		local id = InvokeCommand(string.format("watch_start\n%s", self._Project.Remote));
		self._RemoteWatchID = id;
		while self._RemoteWatchID == id do
			local success, pollResult = pcall(InvokeCommand, string.format("watch_poll\n%s", self._RemoteWatchID));
			if success then
				local mode, remoteFileName, hash = string.match(pollResult, "([^ ]+) '([^ ]*)' ?([^ ]*)");
				if mode == "modify" and not self._Differences[remoteFileName] then
					local localScript = GetLocalScript(self, remoteFileName);
					if localScript and hash ~= HashSource(localScript.Source) then
						self._Differences[remoteFileName] = localScript;
						self._DifferenceCount = self._DifferenceCount + 1;
						self._ScriptChangeEvent:Fire("Remote", remoteFileName, localScript);
						self._ChangedEvent:Fire("Differences");
						self._ChangedEvent:Fire("DifferenceCount");
					end
				elseif mode == "error" then
					if remoteFileName == "ID_NO_LONGER_VALID" then
						id = InvokeCommand(string.format("watch_start\n%s", self._Project.Remote));
						self._RemoteWatchID = id;
					end
				end
			else
				wait(3); --errors shouldn't happen. We'll periodically retry.
			end
		end
	end);
end

--[[ @brief Iterates over all scripts in this project.
	@return A function which, for each invocation, will return a FilePath, ScriptInStudio, DifferenceType for each script maintained in this project.
--]]
function ProjectSync:Iterate()
	local t = Utils.Table.ShallowCopy(self._ListOfFiles);
	local i = 0;
	return function()
		i = i + 1;
		if not t[i] then
			return;
		else
			return unpack(t[i]);
		end
	end;
end

function ProjectSync:Destroy()
	local id = self._RemoteWatchID;
	spawn(function()
		InvokeCommand(string.format("watch_stop\n%s", tostring(id)));
	end);
	self._RemoteWatchID = nil;
	self._Cxns:Destroy();
end

function ProjectSync.new(project)
	local self = setmetatable({}, ProjectSync.Meta);
	self._Differences = {};
	self._ListOfFiles = {};
	self._Project = project;
	self._ChangedEvent = Instance.new("BindableEvent");
	self._ScriptChangeEvent = Instance.new("BindableEvent");
	self._Cxns = Utils.new("Maid");
	self._Cxns.SourceChangedCxns = Utils.new("Maid");
	self._Cxns.NameChangedCxns = Utils.new("Maid");
	self:_ListenForLocalChanges();
	self:_ListenForRemoteChanges();
	spawn(function()
		self:CheckSync();
	end)
	return self;
end

function ProjectSync.Test()
	local p = ProjectSync.new({
		Local = script.Parent;
		Remote = "webserver/Plugin";
	});
	Utils.Log.AssertEqual("remote", "webserver/Plugin/Plugin/ProjectSync.module.lua", GetRemoteScript(p, script));
	p:CheckSync();
end

return ProjectSync;
