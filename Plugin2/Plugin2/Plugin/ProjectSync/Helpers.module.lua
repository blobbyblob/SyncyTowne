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
				local name = string.sub(line, indentation + 1, i - 1);
				local hash = string.sub(line, i + 1);
				local file = { Name = name; Type = "file"; FullPath = stack[#stack].FullPath .. name; Parent = stack[#stack]; Hash = hash; };
				stack[#stack].Children[name] = file;
			end
		end
	end
	return root;
end

--[[ @brief Traces a path from root down a path.

	If a child with a particular name cannot be found, a folder will be created.
	@param root The root which we should start our "trace" from.
	@param path The path to trace.
	@return An instance.
--]]
function module.GetOrCreateParentAtPath(root, path)
	for x in string.gmatch(path, "[^/]+") do
		if root:FindFirstChild(x) then
			root = root:FindFirstChild(x);
		else
			local new = Instance.new("Folder");
			new.Name = x;
			new.Parent = root;
			root = new;
		end
	end
	return root;
end
--TODO: delete the previous function?

function module.AddToRoot(root, path, name, obj)
	Debug("AddToRoot(%s, %s, %s) called", path, name, obj);
	local r = root;
	local iterator = string.gmatch(path, "[^/]+");
	iterator();
	for dir in iterator do
		if not r:FindFirstChild(dir) then
			local f = Instance.new("Folder");
			f.Name = dir;
			f.Parent = r;
		end
		r = r:FindFirstChild(dir);
	end

	--If we will blow away a Folder, instead, replace it with our object.
	if r:FindFirstChild(name) then
		for i, v in pairs(r:FindFirstChild(name):GetChildren()) do
			v.Parent = obj;
		end
		r:FindFirstChild(name).Parent = nil;
	end
	obj.Parent = r;
end

--[[ @brief Gets a path given the root & an object within root.
--]]
function module.GetPath(root, script)
	Utils.Log.Assert(script:IsDescendantOf(root), "script %s expected to be descendant of root %s", script:GetFullName(), root:GetFullName());
	local suffix = module.SUFFIXES[script.ClassName];
	local s = {script.Name .. suffix};
	while script ~= root and script ~= nil do
		script = script.Parent;
		table.insert(s, 1, script.Name);
	end
	return table.concat(s, "/");
end

return module