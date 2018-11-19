local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "Helpers: ", true);

local module = {}

module.SUFFIXES = {
	ModuleScript = ".module.lua";
	LocalScript = ".client.lua";
	Script = ".server.lua";
};

module.SUFFIX_CONVERT_TO_OBJECT = {
	ModuleScript = function() return Instance.new("ModuleScript"); end;
	LocalScript = function() return Instance.new("LocalScript"); end;
	Script = function() return Instance.new("Script"); end;
};

module.SAVEABLE_SERVICES = {
	'Workspace',
	'Lighting',
	'ReplicatedFirst',
	'ReplicatedStorage',
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	--Admittedly, I have no idea what sorts of scripts one might want to put in the services below, but maybe someday someone will have a use case.
	"SoundService",
	"Chat",
	"LocalizationService",
	"TestService",
};

--[[ @brief Converts a path into directory & filename.
	@param path The path to split up.
	@return path The path to the directory containing the file.
	@return filename The name of the file.
--]]
function module.SplitFilePath(path)
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
function module.RemoveRoot(path, root)
	Utils.Log.Assert(path:sub(1, #root) == root, "Path %s does not start with root %s", path, root);
	return path:sub(#root + 2);
end

--[[ @brief Converts an instance into a string which kinda/sorta represents it.
	@param obj A roblox instance
	@return A string that is the object's hash.
--]]
function module.Hash(obj)
	return tostring(string.len(obj.Source));
end
module.GetHash = module.Hash;

--[[ @brief Determines which suffix a filename has, if any, and removes it.

	Example:
		GetSuffix("foo.module.lua") -> "ModuleScript", "foo"

	@param filename The filename to get the suffix from.
	@return[1] nil in case of failure.
	@return[2] The class which the suffix represents.
	@return[2] The filename without its suffix.
--]]
function module.GetSuffix(filename)
	for i, v in pairs(module.SUFFIXES) do
		if filename:sub(-#v) == v then
			return i, filename:sub(1, -#v - 1);
		end
	end
end

--[[ @brief Given a string, build something that somewhat resembles a FilesystemModel. This is useful for creating test cases.
	@param The string to represent the filesystem. This has the following form:
		Folder/
			file.txt
			Subfolder/
				more-files.txt
			another-file-which-is-a-child-of-Folder.txt
--]]
function module.BuildFakeFilesystemModel(str)
	local root = { Tree = { Name = "<root>"; Type = "folder"; FullPath = ""; Parent = nil; Children = {}; }; }
	local stack = {root.Tree};
	local lastIndentation;
	for line in string.gmatch(str, "[^\n]+") do
		local _, indentation = string.find(line, "^\t+");
		if not lastIndentation then lastIndentation = indentation; end
		if indentation ~= #line then
			for i = indentation + 1, lastIndentation do
				table.remove(stack);
			end
			local endsInSlash = string.find(line, "/$");
			if endsInSlash then
				--Create a folder.
				lastIndentation = indentation + 1;
				local name = string.sub(line, indentation + 1, endsInSlash - 1);
				local folder = { Name = name; Type = "folder"; FullPath = stack[#stack].FullPath .. name .. "/"; Parent = stack[#stack]; Children = {}; };
				stack[#stack].Children[name] = folder;
				table.insert(stack, folder);
			else
				--Create a file.
				lastIndentation = indentation;
				local i = string.find(line, " [^ ]+$");
				Utils.Log.Assert(i, "All files must be followed by their hash when creating a fake FilesystemModel");
				local name = string.sub(line, indentation + 1, i - 1);
				local hash = string.sub(line, i + 1);
				local file = { Name = name; Type = "file"; FullPath = stack[#stack].FullPath .. name; Parent = stack[#stack]; Hash = hash; };
				stack[#stack].Children[name] = file;
			end
		end
	end
	return root;
end

--[[ @brief Adds an object as a descendant of some root object by tracing a path.
	@param root The root of the project.
	@param path A path to some descendant. If no descendant exists anywhere along this path, folders will be created.
	@param name The name of the object. This is not meant to have suffixes from Helpers.SUFFIXES, but may have the ".parent" suffix.
	@param obj The object to insert.
	@return The new root, in the case that is has changed.
--]]
function module.AddToRoot(root, path, name, obj)
	Debug("AddToRoot(%s, %s, %s) called", path, name, obj);
	local r = root;
	local iterator = string.gmatch(path, "[^/]+");
	for dir in iterator do
		if not r:FindFirstChild(dir) then
			Debug("Folder %s had to be created in %s because it didn't exist", dir, r:GetFullName());
			local f = Instance.new("Folder");
			f.Name = dir;
			f.Parent = r;
		end
		r = r:FindFirstChild(dir);
	end

	local PARENT_SUFFIX = ".parent";
	local setNotAdd = false;
	if name:sub(-#PARENT_SUFFIX) == PARENT_SUFFIX then
		setNotAdd = true;
	end

	if setNotAdd then
		local nameWithoutSuffix = name:sub(1, -#PARENT_SUFFIX - 1);
		Debug("We are replacing %s, not adding %s as a child", r:GetFullName(), nameWithoutSuffix);
		obj.Name = nameWithoutSuffix;
		for i, v in pairs(r:GetChildren()) do
			v.Parent = obj;
		end
		obj.Parent = r.Parent;
		r.Parent = nil;
		if r == root then
			Debug("We have a new root!");
			root = obj;
		else
			--Things are probably going to go foul if the names don't match. We'll warn, then fix it.
			--Name mismatch would be something like this:
			--Folder
			--    Script.parent.module.lua <-- notice "Script" doesn't match the parent's name, "Folder".
			if r.Name ~= obj.Name then
				Utils.Log.Warning("Names do not match! %s/%s has child %s", path, r.Name, obj.Name);
			end
		end
	else
		Debug("Adding %s as child of %s", obj.Name, r:GetFullName());
		--If we will blow away a Folder, instead, replace it with our object.
		if r:FindFirstChild(name) then
			Debug("%s already has child named %s of class %s, so we will replace it", r.Name, obj.Name, r:FindFirstChild(name).ClassName);
			for i, v in pairs(r:FindFirstChild(name):GetChildren()) do
				v.Parent = obj;
			end
			r:FindFirstChild(name).Parent = nil;
		end
		obj.Parent = r;
	end
	return root;
end

--[[ @brief Gets a path given the root & an object within root. This also tacks on a suffix.

	For example, our workspace looks as such:
		workspace
			Model (Name = "foo")
				Model (Name = "bar")
					Script (Name = "baz")
		GetPath(workspace.foo, workspace.foo.bar.baz) -> "bar/baz.server.lua";
	Take note that foo is _excluded_ from the path.

	@param root The root to start descending from.
	@param script The script to stop at.
	@return A string that represents the path from root to script.
--]]
function module.GetPath(root, script)
	Utils.Log.Assert(script == root or script:IsDescendantOf(root), "script %s expected to be descendant of root %s", script:GetFullName(), root:GetFullName());
	local originalScript = script;
	local suffix = module.SUFFIXES[script.ClassName];
	local s;
	if root == script then
		s = {script.Name .. ".parent" .. (suffix or "")};
	else
		s = {script.Name .. (suffix or "")};
		script = script.Parent;
	end
	while script ~= root and script ~= nil do
		table.insert(s, 1, script.Name);
		script = script.Parent;
	end
	local fullPath = table.concat(s, "/");
	Debug("GetPath(%s, %s) = %s", root:GetFullName(), originalScript:GetFullName(), fullPath);
	return fullPath;
end

--[[ @brief Returns a script given its path and the root object.
	@param root The root instance for the project.
	@param path The path to the script (including the script itself).
	@return[1] nil if any object within the path doesn't exist.
	@return[2] A script which exists at the given path.
--]]
function module.GetScript(root, path)
	local class, filename = module.GetSuffix(path);
	for x in string.gmatch("[^/]+") do
		root = root:FindFirstChild(x);
		if not root then return; end
	end
	return root;
end

return module
