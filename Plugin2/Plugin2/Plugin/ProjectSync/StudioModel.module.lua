--[[

Represents all "saveable" objects using Lua tables.

Properties:
	Root: the Instance at the root of the model.
	Objects: all objects which can be saved.

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
local Debug = Utils.new("Log", "StudioModel: ", true);

local function CompareSource(a, b)
	return a.Source == b.Source;
end
local SAVEABLE_TYPES = {
	Script = CompareSource;
	LocalScript = CompareSource;
	ModuleScript = CompareSource;
};

local StudioModel = Utils.new("Class", "StudioModel");

StudioModel._Root = false;
StudioModel._Objects = {};
StudioModel._ChangedEvent = false;
StudioModel._Cxns = false;

StudioModel.Get.Root = "_Root";
StudioModel.Get.Objects = "_Objects";
StudioModel.Get.Changed = function() return self._ChangedEvent.Event; end;

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
	local backConvert = {};
	for v in pairs(self._Objects) do
		local corresponding = GetEquivalent(v);
		if corresponding and other._Objects[corresponding] then
			backConvert[other._Objects[corresponding]] = v;
			if corresponding.ClassName == v.ClassName then
				if SAVEABLE_TYPES[v.ClassName](v, corresponding) then
					table.insert(results, { A = v; B = corresponding; Status = "synced"; });
				else
					table.insert(results, { A = v; B = corresponding; Status = "desynced"; });
				end
			else
				table.insert(results, { A = v; B = corresponding; Status = "classMismatch"; });
			end
		else
			table.insert(results, { A = v; Status = "aOnly"; });
			Debug("Object %s in self, not other", v);
		end
	end
	for v in pairs(other._Objects) do
		if not backConvert[other._Objects[v]] then
			Debug("Object %s in other, not self", v);
			table.insert(results, { B = v; Status = "bOnly"; });
		end
	end
	return results;
end

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
						self._ChangedEvent:Fire();
					else
						self._Cxns.NameChange[r] = nil;
					end
				end);
			end
		end
		--Watch for Source/Name changes for the script itself.
		self._Cxns.PropertyChanges[obj] = obj.Changed:Connect(function(property)
			if property == "Source" or property == "Name" then
				self._ChangedEvent:Fire();
			end
		end);
		--Watch for ancestry changes of any variety.
		self._Cxns.AncestryChanges[obj] = obj.AncestryChanged:Connect(function(child, parent)
			if not obj:IsDescendantOf(self._Root) then
				Debug("%s is no longer a part of the studio model", obj);
				self._Cxns.PropertyChanges[obj] = nil;
				self._Cxns.AncestryChanges[obj] = nil;
			elseif child:IsDescendantOf(self._Root) then
				Debug("%s had its hierarchy changed", obj);
				self._ChangedEvent:Fire();
			end
		end);
	end
	self._Cxns.DescendantAdded = self._Root.DescendantAdded:Connect(function(descendant)
		if SAVEABLE_TYPES[descendant.ClassName] then
			self._Objects[descendant] = true;
			ListenTo(descendant);
		end
	end);
	for i, v in pairs(self._Objects) do
		ListenTo(i);
	end
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
		if SAVEABLE_TYPES[node.ClassName] then
			self._Objects[node] = true;
		end
		for i, v in pairs(node:GetChildren()) do
			recurse(v);
		end
	end
	recurse(root);
	self:_HookUpConnections();
	return self;
end

function StudioModel.fromFilesystemModel(fm)

end

function StudioModel.Test()
	local m1 = StudioModel.fromInstance(game.ServerStorage.Folder);
	Debug("%0t", m1);
	local m2 = StudioModel.fromInstance(game.ServerStorage.Folder:Clone());
	Debug("%0t", m1:Compare(m2));
	m1:Destroy();
	m2:Destroy();
end

return StudioModel;
