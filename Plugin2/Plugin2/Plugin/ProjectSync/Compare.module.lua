--[[

Contains a function to compare a FilesystemModel against a StudioModel.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "Compare: ", true);
local Helpers = require(script.Parent.Helpers);
local StudioModel = require(script.Parent.StudioModel);
local ServerRequests = require(script.Parent.Parent.ServerRequests);

local module = {};

local MAP_COMPARISONS = {
	aOnly = "fileOnly";
	bOnly = "scriptOnly";
	synced = "synced";
	desynced = "desynced";
	classMismatch = "classMismatch";
};

local function NoOp()

end
local function DeleteFile(file, prefix)
	local success, response = ServerRequests.delete{File=prefix .. file.FullPath};
	if not success then
		Debug("Query failed: %s", response);
	end
	return success;
end
local function CreateScript(file, root, prefix)
	local directory, filename = Helpers.SplitFilePath(file.FullPath);
	local class, name = Helpers.GetSuffix(filename);
	local obj = Helpers.SUFFIX_CONVERT_TO_OBJECT[class]();
	local success, response = ServerRequests.read{ File = prefix .. file.FullPath; };
	if success then
		obj.Source = response.Contents;
		obj.Name = name;
		Helpers.AddToRoot(root, directory, name, obj);
	else
		Debug("Query failed: %s", response);
	end
	return success;
end
local function CreateFile(script, root, prefix)
	local path = Helpers.GetPath(root, script);
	local success, response = ServerRequests.write{ File = prefix .. path; Contents = script.Source; };
	if not success then
		Debug("Query failed: %s", response);
	end
	return success;
end
local function DeleteScript(script)
	if #script:GetChildren() > 0 then
		local f = Instance.new("Folder");
		f.Name = script.Name;
		f.Parent = script.Parent;
		for i, v in pairs(script:GetChildren()) do
			v.Parent = v;
		end
	end
	script:Destroy();
	return true;
end
local function SyncToScript(file, script, prefix)
	local success, response = ServerRequests.read{ File = prefix .. file.FullPath; };
	if success then
		script.Source = response.Contents;
	else
		Debug("Query failed: %s", response);
	end
	return success;
end
local function SyncToFile(file, script, prefix)
	local success, response = ServerRequests.write{ File = prefix .. file.FullPath; Contents = script.Source; };
	if not success then
		Debug("Query failed: %s", response);
	end
	return success;
end

--[[ @brief Compares a filesystem model against a data model.
	@param filesystemModel The FilesystemModel
	@param studioModel The StudioModel
	@return An array for which each entry has the following form:
		{
			File = <file entry>; --This matches an entry in fs.Tree
			Script = <script entry>; --This matches an object in sm.Objects
			Comparison = "synced|desynced|fileOnly|scriptOnly";
			Push = <function to push changes>;
			Pull = <function to pull changes>;
		}
--]]
function module.Compare(filesystemModel, studioModel)
	local fs = StudioModel.fromFilesystemModel(filesystemModel);
	local comparison = fs:Compare(studioModel);
	fs:Destroy();
	local root = studioModel.Root;
	local prefix = filesystemModel.Root .. "/";
	--Iterate through the comparison making the difference easier to work with.
	local s = {};
	for i, v in pairs(comparison) do
		local file;
		if v.A then file = v.A.Original; end
		local script = v.B;
		local trueScript = script and script.Object;
		local comparison = MAP_COMPARISONS[v.Status];
		if v.Status == "classMismatch" then
			table.insert(s, {
				File = file;
				Script = nil;
				Comparison = "fileOnly";
				Push = function() DeleteFile(file, prefix); end;
				Pull = function() CreateScript(file, root, prefix); end;
			});
			table.insert(s, {
				File = nil;
				Script = script;
				Comparison = "scriptOnly";
				Push = function() CreateFile(trueScript, root, prefix); end;
				Pull = function() DeleteScript(trueScript); end;
			});
		else
			local push, pull = NoOp, NoOp;
			if comparison == "fileOnly" then
				push = function() DeleteFile(file, prefix); end
				pull = function() CreateScript(file, root, prefix); end
			elseif comparison == "scriptOnly" then
				push = function() CreateFile(trueScript, root, prefix); end;
				pull = function() DeleteScript(trueScript); end;
			elseif comparison == "desynced" then
				push = function() SyncToFile(file, trueScript, prefix); end;
				pull = function() SyncToScript(file, trueScript, prefix); end;
			end
			table.insert(s, {
				File = file;
				Script = script;
				Comparison = comparison;
				Push = push;
				Pull = pull;
			});
		end
	end
	return s;
end

function module.Test()
	ServerRequests = setmetatable({
			_write = function(arg)
				return true, {};
			end;
			_delete = function(arg)
				return true, {};
			end;
			_read = function(arg)
				return true, { Contents = "foobar"; };
			end;
		}, {__index = function(t, i)
		rawset(t, i, function(arg)
			Debug("Invoking %s(%t)", i, arg);
			local f = rawget(t, "_" .. i);
			if f then
				return f(arg);
			else
				return false, "lol this is just a mock";
			end
		end);
		return rawget(t, i);
	end});
	local TEST_FOLDER = Utils.Misc.Create(
		{	ClassName = "Folder";
			{	ClassName = "Script";
				Source = 'print("Hello world!")\n';
			};
			{	ClassName = "Script";
				Name = "StudioOnly";
				Source = 'print("Hello world!")\n';
			};
			{	ClassName = "Script";
				Name = "Subfolder";
				Source = 'print("Hello world!")\n';
				{	ClassName = "ModuleScript";
					Source = 'local module = {}\n\nreturn module\n';
				};
				{	ClassName = "LocalScript";
					Source = 'print("Hello world!")\n'
				};
			};
		}
	);
	local tree = Helpers.BuildFakeFilesystemModel([[
		Folder/
			Script.server.lua 22
			Subfolder.server.lua 22
			Subfolder/
				LocalScript.client.lua 23
				ModuleScript.module.lua 33
				FilesystemOnly.module.lua 33
	]]);
	tree.Root = "SyncyTowne/server/testdir2";
	local sm = StudioModel.fromInstance(TEST_FOLDER);
	local comparison = module.Compare(tree, sm);
	Debug("%0t", comparison)
	for i, v in pairs(comparison) do
		Debug("=================\n%s - %s - %s\n=================", v.Script and v.Script.Object or "nil", v.File and v.File.FullPath or "nil", v.Comparison);
		v:Pull();
		Debug("Moving on...");
	end
	for i, v in pairs(sm.Objects) do
		Debug("%s: %q", v.Object:GetFullName(), string.gsub(v.Object.Source, "\n", "\\n"));
	end
	sm:Destroy();
end

return module;
