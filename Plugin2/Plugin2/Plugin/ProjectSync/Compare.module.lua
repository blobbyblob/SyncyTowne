--[[

Contains a function to compare a FilesystemModel against a StudioModel.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "Compare: ", true);
local Helpers = require(script.Parent.Helpers);
local FilesystemModel = require(script.Parent.FilesystemModel);

local module = {};

--[[ @brief Compares a filesystem model against a data model.
	@param fs The FilesystemModel
	@param sm The StudioModel
	@return An array for which each entry has the following form:
		{
			File = <file entry>; --This matches an entry in fs.Tree
			Script = <script entry>; --This matches an object in sm.Objects
			Comparison = "synced|desynced|fileOnly|scriptOnly";
			Push = <function to push changes>;
			Pull = <function to pull changes>;
		}
--]]
function module.Compare(fs, sm)
	local comparison = {};
	local _, firstChildOfTree = next(fs.Tree.Children);
	Compare(firstChildOfTree, sm.Root, comparison);
	return comparison;
end

function module.Test()
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
	local tree = {
		Children = {
			Folder = {
				Type = "folder";
				Name = "Folder";
				Children = {
					["Subfolder.server.lua"] = {
						Hash = 22;
						Type = "file";
						Name = "Subfolder.server.lua";
					};
					Subfolder = {
						Type = "folder";
						Name = "Subfolder";
						Children = {
							["ModuleScript.module.lua"] = {
								Hash = 33;
								Type = "file";
								Name = "ModuleScript.module.lua";
							};
							["LocalScript.client.lua"] = {
								Hash = 22;
								Type = "file";
								Name = "LocalScript.client.lua";
							};
						};
					};
					["Script.server.lua"] = {
						Hash = 23;
						Type = "file";
						Name = "Script.server.lua";
					};
				};
			};
		};
	};
	Debug("%0t", module.Compare({Tree = tree; }, {Root = TEST_FOLDER}))
end

return module;
