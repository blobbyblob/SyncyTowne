--[[

Represents all "saveable" objects using Lua tables.

Properties:
	Root: the Instance at the root of the model.
	Objects: all objects which can be saved. These are entries of the following form:
		{
			Object = <object>;
			Hash = "<hash>";
			Original = <handle>; --Only for StudioModels which were constructed using fromFilesystemModel; this refers to the tree entry that created this object.
		}

Events:
	Changed: fires when any object is added/removed, or a property is changed on any object.

Methods:
	Compare(other): compares one StudioModel to another.
	Destroy(): cleans up this instance.

Constructors:
	fromInstance(root): constructs a StudioModel from an Instance.
	fromFilesystemModel(fsModel): constructs a StudioModel from a FilesystemModel.

--]]

local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "StudioModel: ", false);
local Helpers = require(script.Parent.Helpers);

local SUFFIXES = Helpers.SUFFIXES;
local GetSuffix = Helpers.GetSuffix;
local SUFFIX_CONVERT_TO_OBJECT = Helpers.SUFFIX_CONVERT_TO_OBJECT;
local GetHash = Helpers.GetHash;

local function CompareHashes(a, b)
	return a.Hash == b.Hash;
end
local CLASS_COMPARISON = {
	ModuleScript = CompareHashes;
	LocalScript = CompareHashes;
	Script = CompareHashes;
};

local StudioModel = Utils.new("Class", "StudioModel");

StudioModel._Root = false;
StudioModel._Objects = {};
StudioModel._ChangedEvent = false;
StudioModel._Cxns = false;

StudioModel.Get.Root = "_Root";
StudioModel.Get.Objects = "_Objects";
StudioModel.Get.Changed = function(self) return self._ChangedEvent.Event; end;

function StudioModel:Destroy()
	self._Cxns:Destroy();
end

function StudioModel:_HookUpConnections()
	local function ListenTo(obj)
		--Watch for name changes for all ancestors.
		local r = obj.Parent;
		while r ~= self._Root do
			if self._Cxns.NameChange[r] then
				break;
			else
				self._Cxns.NameChange[r] = r:GetPropertyChangedSignal("Name"):Connect(function()
					if r:IsDescendantOf(self._Root) then
						self._ChangedEvent:Fire(obj);
					else
						self._Cxns.NameChange[r] = nil;
					end
				end);
			end
		end
		local entry;
		for i, v in pairs(self._Objects) do
			if v.Object == obj then
				entry = v;
				break;
			end
		end
		--Watch for Source/Name changes for the script itself.
		self._Cxns.PropertyChanges[obj] = obj.Changed:Connect(function(property)
			if property == "Source" or property == "Name" then
				if property == "Source" then
					entry.Hash = GetHash(obj);
				end
				self._ChangedEvent:Fire(obj);
			end
		end);
		--Watch for ancestry changes of any variety.
		self._Cxns.AncestryChanges[obj] = obj.AncestryChanged:Connect(function(child, parent)
			if not obj:IsDescendantOf(self._Root) then
				Debug("%s is no longer a part of the studio model", obj);
				self._Cxns.PropertyChanges[obj] = nil;
				self._Cxns.AncestryChanges[obj] = nil;
				for i, v in pairs(self._Objects) do
					if v.Object == obj then
						table.remove(self._Objects, i);
						break;
					end
				end
			elseif child:IsDescendantOf(self._Root) then
				Debug("%s had its hierarchy changed", obj);
				self._ChangedEvent:Fire(obj);
			end
		end);
	end
	self._Cxns.DescendantAdded = self._Root.DescendantAdded:Connect(function(descendant)
		if SUFFIXES[descendant.ClassName] then
			table.insert(self._Objects, { Object = descendant; Hash = GetHash(descendant); });
			ListenTo(descendant);
		end
	end);
	for i, v in pairs(self._Objects) do
		ListenTo(v.Object);
	end
end

--[[ @brief Compares two studio models.
	@param other The second studio model to compare.
	@return An array with entries of the following form:
		{
			A = <item from self>
			B = <item from other>
			Status = "synced|desynced|aOnly|bOnly|classMismatch";
		}
--]]
function StudioModel:Compare(other)
	local results = {};
	local equivalents = {[self._Root] = other._Root};
	local function GetEquivalent(obj)
		if not equivalents[obj] then
			local parent = GetEquivalent(obj.Parent);
			if parent and parent:FindFirstChild(obj.Name) then
				equivalents[obj] = parent:FindFirstChild(obj.Name);
			else
				Debug("Cannot find equivalent for %s in %s", obj, parent);
			end
		end
		return equivalents[obj];
	end

	--Map `other._Objects[i].Object` -> `other._Objects[i]` for all i.
	local otherObjectsMap = {};
	for i, v in pairs(other._Objects) do
		otherObjectsMap[v.Object] = v;
	end

	local backConvert = {};
	for i, v in pairs(self._Objects) do
		local corresponding = GetEquivalent(v.Object);
		if corresponding and otherObjectsMap[corresponding] then
			backConvert[corresponding] = v;
			if corresponding.ClassName == v.Object.ClassName then
				local comparisonResult = CLASS_COMPARISON[v.Object.ClassName](v, otherObjectsMap[corresponding]);
				if comparisonResult then
					table.insert(results, { A = v; B = otherObjectsMap[corresponding]; Status = "synced"; });
				else
					Debug("Script %s differs", v.Object:GetFullName());
					table.insert(results, { A = v; B = otherObjectsMap[corresponding]; Status = "desynced"; });
				end
			else
				table.insert(results, { A = v; B = otherObjectsMap[corresponding]; Status = "classMismatch"; });
			end
		else
			table.insert(results, { A = v; Status = "aOnly"; });
			Debug("Object %s in self, not other", v);
		end
	end
	for i, v in pairs(other._Objects) do
		if not backConvert[v.Object] then
			Debug("Object %s in other, not self", v);
			table.insert(results, { B = v; Status = "bOnly"; });
		end
	end
	return results;
end

function StudioModel.new()
	local self = setmetatable({}, StudioModel.Meta);
	self._Objects = {};
	self._ChangedEvent = Instance.new("BindableEvent");
	self._Cxns = Utils.new("Maid");
	self._Cxns.PropertyChanges = Utils.new("Maid");
	self._Cxns.AncestryChanges = Utils.new("Maid");
	self._Cxns.NameChange = Utils.new("Maid");
	return self;
end

function StudioModel.fromInstance(root)
	local self = StudioModel.new();
	self._Root = root;
	--Find all Scripts, ModuleScripts, or LocalScripts in root and add them to the tree.
	local function recurse(node)
		if node == game then
			for i, serviceName in pairs(Helpers.SAVEABLE_SERVICES) do
				recurse(game:GetService(serviceName));
			end
		elseif node then
			if SUFFIXES[node.ClassName] then
				table.insert(self._Objects, { Object = node; Hash = GetHash(node); });
			end
			for i, v in pairs(node:GetChildren()) do
				recurse(v);
			end
		end
	end
	recurse(root);
	self:_HookUpConnections();
	return self;
end

function StudioModel.fromFilesystemModel(fm)
	local root = Instance.new("Folder");
	local objects = {};
	local function AddToRoot(path, name, obj)
		Debug("AddToRoot(%s, %s, %s) called", path, name, obj);
		local first = string.match(path, "^[^/]+");
		if first then
			--make sure the root name matches the first directory.
			root.Name = first;
			Helpers.AddToRoot(root, path, name, obj);
		else
			--We have a script at top-level, so we should replace `root` with the proper script.
			for i, v in pairs(root:GetChildren()) do
				v.Parent = obj;
			end
			root = obj;
		end
	end
	--Scan through the tree; anything that's a file should be created.
	local function recurse(tree)
		Debug("Scanning %s", tree.Name);
		if tree.Type == "file" then
			local class, root = GetSuffix(tree.Name);
			if class then
				local entry = { Object = SUFFIX_CONVERT_TO_OBJECT[GetSuffix(tree.Name)](); Hash = tree.Hash; Original = tree; };
				entry.Object.Name = root;
				AddToRoot(tree.Parent.FullPath, root, entry.Object)
				table.insert(objects, entry);
			end
		elseif tree.Type == "folder" then
			--Skip folders. We'll implicitly create them if we need to.
			for i, v in pairs(tree.Children) do
				recurse(v);
			end
		end
	end
	recurse(fm.Tree);

	local self = StudioModel.new();
	self._Root = root;
	self._Objects = objects;
	return self;
end

local function PrintModel(model)
	local rootName = model.Root:GetFullName();
	local objectsSortedByFullName = {};
	for i, v in pairs(model.Objects) do
		table.insert(objectsSortedByFullName, {v.Object:GetFullName(); v});
	end
	table.sort(objectsSortedByFullName, function(a, b) return a[1] < b[1]; end);
	for i, v in pairs(objectsSortedByFullName) do
		local v = v[2];
		Debug("%s (%s) - %s", string.sub(v.Object:GetFullName(), #rootName + 2), v.Object.ClassName, v.Hash);
	end
end

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

function StudioModel.TestManualCompare()
	local m1 = StudioModel.fromInstance(TEST_FOLDER);
	local fm = Helpers.BuildFakeFilesystemModel([[
	Folder/
		Script.server.lua 22
		Subfolder.server.lua 22
		Subfolder/
			LocalScript.client.lua 23
			ModuleScript.module.lua 33
			FilesystemOnly.module.lua 33
	]]);
	local m2 = StudioModel.fromFilesystemModel(fm);
	Debug("Model 1:");
	PrintModel(m1);
	Debug("Model 2:");
	PrintModel(m2);
	m1:Destroy();
	m2:Destroy();
end

--[[ @brief Tests that a root script can be converted into a StudioModel from a FilesystemModel.
--]]
function StudioModel.TestRootScript()
	local fm = Helpers.BuildFakeFilesystemModel([[
		Main.server.lua 5
		Main/
			Subscript.server.lua 5
	]]);
	local m2 = StudioModel.fromFilesystemModel(fm);
	Debug("Model 2: ");
	PrintModel(m2);
end

StudioModel.Test = StudioModel.TestRootScript;

return StudioModel;
