local Utils = require(script.Parent.Parent.Parent);
local Debug = Utils.new("Log", "RoleParameters: ", true);
local FuncCallDebug = Utils.new("Log", "RoleParameters: ", true);

local RoleParameters = Utils.new("Class", "RoleParameters");

--Single: if there are no children with this role, we make sure of it by cloning some default & parenting it to the object.
--Many: this object may be cloned several times to satisfy the needs of the SpecializedLayout.
RoleParameters.RoleType = Utils.new("Enum", "RoleType", "Single", "Many");
local MANY = RoleParameters.RoleType.Many;
local SINGLE = RoleParameters.RoleType.Single;

RoleParameters._Schema = false;
RoleParameters._Defaults = false;
RoleParameters._Parent = false;
RoleParameters._MainRole = false;
RoleParameters._Cache = false; --a map of created elements for a "Many" role type. Form: { RoleName = {index 1, index 2, ...} }
RoleParameters._Source = false; --a map of RoleName --> element from which we sourced this type.
RoleParameters._RoleCounts = false; --a map of RoleName --> number of elements.
RoleParameters._ElementsCreated = false; --a map of [obj] --> true if obj is a gui element created by this class.
RoleParameters._StagedProperties = false; --a table of the form [role][index?] = {key=value, ...} which specifies the properties which should be applied to a child of type role/index.
RoleParameters._StagedFunctions = false; --a table of the form [role][index?] = {function={args}, ...} which specifies the functions which should be called on a child of type role/index.
RoleParameters._Index = 0;

function RoleParameters.Set:Schema(v)
	self._Schema = v;
	for role, description in pairs(self._Schema) do
		self:_ValidateSource(role);
	end
end
function RoleParameters.Set:Defaults(v)
	self._Defaults = v;
	for role, description in pairs(self._Defaults) do
		self:_ValidateSource(role);
	end
end
function RoleParameters.Set:Parent(v)
	self._Parent = v;
end
function RoleParameters.Set:MainRole(v)
	self._MainRole = v;
	self:_ValidateSource(self._MainRole);
end
RoleParameters.Get.Schema = "_Schema";
RoleParameters.Get.Defaults = "_Defaults";
RoleParameters.Get.Parent = "_Parent";
RoleParameters.Get.MainRole = "_MainRole";
function RoleParameters.Get:RoleSourceChanged()
	return self._RoleSourceChanged.Event;
end
function RoleParameters.Get:LayoutParamsChanged()
	return self._LayoutParamsChanged.Event;
end

function RoleParameters:Clone()
	local new = RoleParameters.new()
	new.Schema = self.Schema;
	new.Defaults = self.Defaults;
	new.Parent = self.Parent;
	new.MainRole = self.MainRole;
	return new;
end

--[[ @brief Gets the "source" object for a given role.
     @details The source object for a role is the object which we clone in order to render our object. It could also be an object we do not clone in the case where we only need one item (RoleType == Single) and the user specified an element they want to use.
     @param role The role we are searching for.
     @return The handle of the source object.
     @return True if this handle also doubles as the actual child; false if it should be cloned before usage as the child.
--]]
function RoleParameters:_GetRoleSource(role)
	FuncCallDebug("_GetRoleSource(%s, %s) called", self, role);
	--If a role is of type "Single", it should look in self._Schema[role].Default, self._Defaults[role], and then search through the children.
	--If a role is of type "Many", it should look in the same sites.
	local child = self:_FindFirstChildOfRole(role);
	if child then
		if SINGLE:Equals(self._Schema[role].Type) then
			return child, true;
		else
			return child, false;
		end
	end
	if self._Defaults then
		if self._Defaults[role] then
			return self._Defaults[role], false;
		end
	end
	Debug("Role: %s", role);
	return self._Schema[role].Default, false;
end
--[[ @brief Iterates through children and returns the first one which has a given role. If none have a given role, nil will be returned.
     @param role The role to attempt to match
     @return The child with a given role, or nil if none exists.
--]]
function RoleParameters:_FindFirstChildOfRole(role)
	FuncCallDebug("_FindFirstChildOfRole(%s, %s) called", self, role);
	for i, v in pairs(self._Parent:GetChildren()) do
		if not self._ElementsCreated[v] then
			local r = v.LayoutParams and v.LayoutParams.Role or self._MainRole;
			if r == role then
				return v;
			end
		end
	end
end
--[[ @brief Instantiates/returns a new child.
     @details All children should be created through this function as it's responsible for noting who the 'owner' of the element is (important when deciding whether to delete it). This function will not, however, put the element in the _Cache.
     @param role The role to create.
     @param source The element from which we create the return value. This is the return value from _GetRoleSource.
     @param useWithoutClone Whether or not we should use the element without cloning it (true when the element is user-specified). This is the return value from _GetRoleSource.
     @return The newly created element.
--]]
function RoleParameters:_CreateChild(role, source, useWithoutClone)
	FuncCallDebug("_CreateChild(%s, %s, %s, %s) called", self, role, source, useWithoutClone);
	if not source then
		source, useWithoutClone = self:_GetRoleSource(role);
	end
	if useWithoutClone then
		return source;
	else
		local new = source:Clone();
		new.Name = source.Name .. "-Clone";
		new.Parent = self._Parent;
		self._ElementsCreated[new] = role;
		Debug("Added %s=%s to _ElementsCreated", new, role);
		return new;
	end
end
--[[ @brief Determines what the appropriate "source" for a given role is, and if it is different from the last, updates the item in the cache.
     @param role The role to search for.
--]]
function RoleParameters:_ValidateSource(role)
	FuncCallDebug("_ValidateSource(%s, %s) called", self, role);
	local source, useWithoutClone = self:_GetRoleSource(role);
	if source ~= self._Cache[role] and source ~= self._Source[role] then
		self._RoleSourceChanged:Fire(role, source);
		Debug("New source (%s) doesn't match old (%s)", source, self._Source[role]);
		--Wipe out _Cache[role] as long as it doesn't refer to a RoleType = Single element which is still a child of this instance.
		if self._Cache[role] then
			Debug("Cache[%s] (type %s) has contents (%t)", role, self._Schema[role].Type.Name, self._Cache[role]);
			if SINGLE:Equals(self._Schema[role].Type) then
				local element = self._Cache[role];
				if self._ElementsCreated[element] then
					element.Parent = nil;
					Debug("Removing %s from _ElementsCreated", element);
					self._ElementsCreated[element] = nil;
					self._Cache[role] = nil;
				end
				self._Cache[role] = self:_CreateChild(role, source, useWithoutClone);
				self:_ConfigureChild(self._Cache[role], role);
				Debug("Setting Cache[%s] = %s", role, self._Cache[role]);
			else
				for i, element in pairs(self._Cache[role]) do
					element.Parent = nil;
					Debug("Removing %s from _ElementsCreated", element);
					self._ElementsCreated[element] = nil;
					self._Cache[role][i] = self:_CreateChild(role, source, useWithoutClone);
					self:_ConfigureChild(self._Cache[role][i], role, i);
					Debug("Setting Cache[%s][%d] = %s", role, i, self._Cache[role][i]);
				end
			end
		else
			Debug("Cache[%s] (type %s) is empty", role, self._Schema[role].Type.Name);
			if SINGLE:Equals(self._Schema[role].Type) then
				self._Cache[role] = self:_CreateChild(role, source, useWithoutClone);
				self:_ConfigureChild(self._Cache[role], role);
				Debug("Setting Cache[%s] = %s", role, self._Cache[role]);
			end
		end
		self._Source[role] = source;
	else
		Debug("Source matches old (%s)", source);
	end
end
--[[ @brief Runs all functions and applies all parameters to a child.
     @param child The newly created child.
     @param role The role the child adheres to.
     @param i The index of the role.
--]]
function RoleParameters:_ConfigureChild(child, role, i)
	FuncCallDebug("_ConfigureChild(%s, %s, %s, %s) called", self, child, role, i);
	--Run all staged properties.
	local properties = self._StagedProperties[role];
	if properties and i then properties = properties[i]; end
	if properties then
		for key, value in pairs(properties) do
			child[key] = value;
		end
	end
	--Run all staged functions.
	local functions = self._StagedFunctions[role];
	if functions and i then functions = functions[i]; end
	if functions then
		for func, arguments in pairs(functions) do
			Debug("self._Schema[%s].Operations[%s] = %s", role, func, self._Schema[role].Operations[func]);
			self._Schema[role].Operations[func](self._Parent, child, unpack(arguments));
		end
	end
end

function RoleParameters:GetChildContainer(child)
	FuncCallDebug("GetChildContainer(%s, %s) called", self, child);
	local role = child.LayoutParams and child.LayoutParams.Role or self._MainRole;
	if not role then return; end
	Debug("Child Role: %s", role);
	local schema = self._Schema[role];
	Debug("Schema: %s", schema);
	if not schema then return; end
	if SINGLE:Equals(schema.Type) then
		local parent = self._Schema[role].ParentName;
		if parent then
			local parent = self._Parent[parent]
			if type(parent) == 'table' then
				parent = parent:_GetRbxHandle();
			end
			Debug("GetChildContainer(%s) = %s", child, parent);
			return parent;
		else
			if typeof(self._Parent._Parent) == 'Instance' then
				return self._Parent._Parent;
			end
			local parent = self._Parent._Parent:_GetChildContainer(self._Parent);
			Debug("GetChildContainer(%s) = %s", child, parent);
			return parent;
		end
	else
		local parent = self._Parent._Limbo;
		Debug("GetChildContainer(%s) = %s", child, parent);
		return parent;
	end
end
function RoleParameters:GetChildOfRole(role, index)
	FuncCallDebug("GetChildOfRole(%s, %s, %s) called", self, role, index);
	self:_ValidateSource(role);
	if SINGLE:Equals(self._Schema[role].Type) then
		return self._Cache[role]
	else
		return self._Cache[role][index];
	end
end
function RoleParameters:SetRoleCount(role, count)
	FuncCallDebug("SetRoleCount(%s, %s, %s) called", self, role, count);
	if MANY:Equals(self._Schema[role].Type) then
		local cache = self._Cache[role];
		if not cache then
			cache = {};
			self._Cache[role] = cache;
		end
		self:_ValidateSource(role);
		for i = 1, count do
			if not cache[i] then
				Debug("Creating element for Cache[%s][%d]", role, i);
				cache[i] = self:_CreateChild(role);
				self:_ConfigureChild(cache[i], role, i);
			end
		end
		for i = count + 1, #cache do
			cache[i].Parent = nil;
			cache[i] = nil;
		end
	else
		Utils.Log.Error("Cannot set role count for role of type %s", self._Schema[role].Type);
	end
end
function RoleParameters:ApplyFunction(role, index, functionName, ...)
	FuncCallDebug("ApplyFunction(%s, %s, %s, %s, %t) called", self, role, index, functionName, {...});
	if not self._StagedFunctions[role] then self._StagedFunctions[role] = {}; end

	local functions = self._StagedFunctions[role];
	local child = self._Cache[role];
	local arguments  = {...};
	if MANY:Equals(self._Schema[role].Type) then
		if not functions[index] then functions[index] = {}; end
		functions = functions[index];
		child = child[index];
	end
	functions[functionName] = arguments;
	if child then
		self._Schema[role].Operations[functionName](self._Parent, child, unpack(arguments));
	end
end
function RoleParameters:ApplyParameter(role, index, property, value)
	FuncCallDebug("ApplyParameter(%s, %s, %s, %s, %s) called", self, role, index, property, value);
	if not self._StagedProperties[role] then self._StagedProperties[role] = {}; end

	local parameters = self._StagedProperties[role];
	local child = self._Cache[role];
	if MANY:Equals(self._Schema[role].Type) then
		if not parameters[index] then parameters[index] = {}; end
		parameters = parameters[index];
		child = child[index];
	end

	parameters[property] = value;
	if child then
		Debug("Performing %s.%s = %s", child, property, value);
		child[property] = value;
	end
end
RoleParameters.ApplyProperty = RoleParameters.ApplyParameter;
function RoleParameters:GetChildLayoutParams(child)
	FuncCallDebug("GetChildLayoutParams(%s, %s) called", self, child);
	--Determine the child's role.
	local role = self._ElementsCreated[child] or child.LayoutParams and child.LayoutParams.Role or self._MainRole;
	--Get the child's LayoutParams table.
	if child.LayoutParams then
		--If it exists, copy it and fill in missing entries from self._Schema[role].LayoutParams
		Debug("Child's Role: %s", role);
		return Utils.Table.Incorporate(Utils.Table.ShallowCopy(child.LayoutParams), self._Schema[role].LayoutParams or {});
	else
		--If it doesn't exist, copy and return self._Schema[role].LayoutParams.
		return Utils.Table.ShallowCopy(self._Schema[role].LayoutParams or {});
	end
end

function RoleParameters:__tostring()
	return string.format("RoleParameters_%03x", self._Index);
end

local _ = RoleParameters.Meta;

--[[ @brief Instantiates a new RoleParameters object.
--]]
local index = 0;
function RoleParameters.new()
	local self = setmetatable({}, RoleParameters.Meta);
	index = index + 1;
	self._Index = index;
	self._Defaults = {};
	self._Cache = {};
	self._Source = {};
	self._ElementsCreated = {};
	self._StagedProperties = {};
	self._StagedFunctions = {};
	self._RoleSourceChanged = Utils.new("Event");
	self._LayoutParamsChanged = Utils.new("Event");
	self._RoleSourceChanged.Event:connect(function(...)
		FuncCallDebug("RoleSourceChanged(%s, %s) fired", ...);
	end)
	self._LayoutParamsChanged.Event:connect(function(...)
		FuncCallDebug("LayoutParamsChanged(%s) fired", ...);
	end)
	return self;
end

return RoleParameters;
