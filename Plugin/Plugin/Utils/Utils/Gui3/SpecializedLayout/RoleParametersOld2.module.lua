--[[

RoleParameters
A class which manages children's LayoutParams based on their Role. It also allows plugging/swapping defaults.
Members:
	enum RoleType = {Single, Many}

Properties:
	Schema (table): a table describing the roles for this element, their layout parameters, a default element to fill the role, and sundry other details.
	{
		["RoleName"] = {
			Type = RoleType (enum);
			LayoutParams = {};
			Default = Gui.new("Rectangle");
			ParentName = "_Frame";
		};
		['*'] = WildcardSchemaDefinition...
		DefaultRole = "RoleName";
	};
	Defaults: a table of alternate defaults (not all need be defined) for each role. This is meant to make applying a different style easy.
	Defaults = {
		[RoleName] = Gui.new("Rectangle");
		...
	};
	Parent: the gui element this RoleParameters object applies to.

Methods:
	GetChildContainer(child): gets the object which should contain this element.
	GetChildOfRole(role, index): returns the child which has a given role. If RoleType is single, this will return the first child it finds with the given role and if it finds nothing, it will return the default. If the RoleType is Many, it will return a copy of the first child it finds with the given role and the copy will already be parented in the proper space.
		The parameter index only applies for the Many RoleType and will return the index'th copy of the original.
	SetRoleCount(role, count): the number of elements of a given role which we should instantiate.
	GetRoleCount(role): returns the number of elements with a given role.
	GetChildLayoutParams(child): gets the layout params for a given child.
	GetChildRole(child): gets the role of a child.
	GetRoleLayoutParams(role): returns the layout params for a given role.
Events:
	RoleSourceChanged(role): fires when the source object for a given role is changed.
	LayoutParamsChanged(role): fires when a child gets a new LayoutParams or the existing one gets new key/value pairs.


--]]

local Utils = require(script.Parent.Parent.Parent);
local Gui = require(script.Parent.Parent);
local Debug = Utils.new("Log", "RoleParameters: ", true);
local FuncCallDebug = Utils.new("Log", "RoleParameters.", true);

local function IsReady(self)
	return not not (self._Schema and self._Parent);
end

local RoleParameters = Utils.new("Class", "RoleParameters");

--Single: if there are no children with this role, we make sure of it by cloning some default & parenting it to the object.
--Many: this object may be cloned several times to satisfy the needs of the SpecializedLayout.
RoleParameters.RoleType = Utils.new("Enum", "RoleType", "Single", "Many");
local MANY = RoleParameters.RoleType.Many;
local SINGLE = RoleParameters.RoleType.Single;
local WILDCARD = '*';

RoleParameters._LockParameters = false;
RoleParameters._Initialized = false;
RoleParameters._InitializationRoleCounts = false;
RoleParameters._Schema = false;
RoleParameters._Defaults = {};
RoleParameters._Parent = false;

function RoleParameters:Clone()
	local new = RoleParameters.new();
	new.Schema = self.Schema;
	new.Defaults = self.Defaults;
	new._InitializationRoleCounts = self._RoleCounts;
	return new;
end

RoleParameters._ChangedEvents = false; --! A map of [child] --> changed event
RoleParameters._CreatedElements = false; --! A map of [child] --> <"defaults" or "schema"> if this child was created by this instance, only.
RoleParameters._RoleCounts = false; --! A map of ["role name"] = <max index> for all roles which have RoleType = Many.
RoleParameters._LayoutParams = false; --! A map of [child] --> <LayoutParams> for all children be they created by this instance or by the user.
RoleParameters._ElementMap = false; --! A map of ["role name"] = child or {child1, ...}
RoleParameters._Source = false; --! A map of ["role name"] = {SourceObject, ShouldBeCloned}
RoleParameters._ChildRemovedCxn = false; --! A connection for when self._Parent.ChildRemoved fires.
RoleParameters._ChildAddedCxn = false; --! A connection for when self._Parent.ChildAdded fires.

--Events
RoleParameters._RoleSourceChanged = false;
RoleParameters._LayoutParamsChanged = false;

--Schema and Parent must only be defined once.
function RoleParameters.Set:Schema(v)
	FuncCallDebug("Set.Schema(%s, %s) called", self, v);
	if self._LockParameters then
		Utils.Log.Error(3, "Schema must not be set more than once");
	end
	--Validate input
	do
		local defaultRoleSpecified = false;
		for role, schema in pairs(v) do
			if role == "DefaultRole" then
				defaultRoleSpecified = true;
			else
				if not schema.Type then
					Utils.Log.Warn("Type not specified for Schema[%s]", role);
					schema.Type = "Single";
				end
				if not schema.ParentName then
--					Utils.Log.Warn("ParentName not specified for Schema[%s]", role);
				end
				if not schema.Default then
					Utils.Log.Warn("Default not specified for Schema[%s]", role);
					schema.Default = Gui.Create "Rectangle" {};
				end
				if not schema.LayoutParams then
					Utils.Log.Warn("LayoutParams not specified for Schema[%s]", role);
					schema.LayoutParams = {};
				end
			end
		end
		if not defaultRoleSpecified then
			Utils.Log.Warn("DefaultRole not specified for Schema");
		end
	end
	self._Schema = v;
	if self._Parent and self._Schema then
		self:_Setup();
	end
end
function RoleParameters.Set:Parent(v)
	FuncCallDebug("Set.Parent(%s, %s) called", self, v);
	if v and self._LockParameters then
		Utils.Log.Error(3, "Parent must not be set more than once");
	end
	self._Parent = v;
	if v and self._Schema then
		self:_Setup();
	elseif not v then
		self:_Teardown();
	end
end
function RoleParameters.Set:Defaults(v)
	FuncCallDebug("Set.Defaults(%s, %s) called", self, v);
	if self._Defaults ~= v then
		self._Defaults = v;
		if self._Initialized then
			self:_UpdateDefaults();
		end
	end
end

RoleParameters.Get.Schema = "_Schema";
RoleParameters.Get.Parent = "_Parent";
RoleParameters.Get.Defaults = "_Defaults";

RoleParameters.Get.RoleSourceChanged = "_RoleSourceChanged";
RoleParameters.Get.LayoutParamsChanged = "_LayoutParamsChanged";

--@brief Gets the layout parameters for a given child and caches it in self._LayoutParams[child]
function RoleParameters:_ObtainLayoutParams(child, role)
	FuncCallDebug("_ObtainLayoutParams(%s, %s, %s) called", self, child, role);
	--Clone the child's LayoutParams and buffer them with any missing keys.

	if not child.LayoutParams then
		child.LayoutParams = Utils.Table.ShallowCopy(self._Schema[role].LayoutParams or {});
	else
		for key, value in pairs(self._Schema[role].LayoutParams) do
			if child.LayoutParams[key] == nil then
				child.LayoutParams[key] = value;
			end
		end
	end
	child.LayoutParams.Role = role;


--	local params = child.LayoutParams and Utils.Table.ShallowCopy(child.LayoutParams) or self._Schema[role].LayoutParams;
	self._LayoutParams[child] = child.LayoutParams;
end

--@brief Listens for changes on the child.
--@param child The child we should listen to. This should be a user-specified child.
function RoleParameters:_AcceptChildOfRole(child, role, skipCallback)
	FuncCallDebug("_AcceptChildOfRole(%s, %s, %s) called", self, child, role);
	Utils.Log.Assert(self._CreatedElements[child]==nil, "_AcceptChildOfRole should not be passed a child which this RoleParameters created");
	self._Source[role] = {child, "user"};
	--Connect to the Changed event
	self._ChangedEvents[child] = child.Changed:connect(function(prop)
		if prop=="LayoutParams" then
			self:_ObtainLayoutParams(child, role);
			self._LayoutParamsChanged:Fire(role);
		end
	end);
	self:_CreateAllElements(role);
	if self._Initialized then
		self._RoleSourceChanged:Fire(role);
	end
end

--@brief Stops listening for changes on the child.
--@param child The child we should stop listening to. This should be a user-specified child.
function RoleParameters:_ReleaseChildOfRole(child, role)
	FuncCallDebug("_ReleaseChildOfRole(%s, %s, %s) called", self, child, role);
	Utils.Log.Assert(self._CreatedElements[child]==nil, "_ReleaseChildOfRole should not be passed a child which this RoleParameters created");

	--Stop listening on the changed event.
	self._ChangedEvents[child]:Disconnect();
	self._ChangedEvents[child] = nil;
	--Choose a new element for self._Source
	if self._Defaults[role] then
		self._Source[role] = {self._Defaults[role], "defaults"};
		self:_ObtainLayoutParams(self._Source[role][1], role);
	else
		self._Source[role] = {self._Schema[role].Default, "schema"};
		self:_ObtainLayoutParams(self._Source[role][1], role);
	end
	--Recreate elements using defaults instead.
	self:_CreateAllElements(role);
	if self._Initialized then
		self._RoleSourceChanged:Fire(role);
	end
end

--@brief Creates a new child for a given role/index.
--@details This function expects self._Source[role] to have been populated.
--    The function will delete the old child if appropriate and insert the newly created child
--    into self._CreatedElements. It will also create the LayoutParams object.
--@param role The role which the child we want to create should serve.
--@param index The index of the child (in the case that the role type is "Many").
function RoleParameters:_NewChild(role, index)
	FuncCallDebug("_NewChild(%s, %s, %s) called", self, role, index);
	local src, key;
	local isMany = MANY:Equals(self._Schema[role].Type);
	if isMany then
		src, key = self._ElementMap[role], index;
	else
		src, key = self._ElementMap, role;
	end

	--Delete the old element if this instance created it.
	local child = src[key];
	if child then
		if self._CreatedElements[child] then
			child.Parent = nil;
			self._CreatedElements[child] = nil;
		end
		self._LayoutParams[child] = nil;
	end

	--Create a new element.
	local source, clone = unpack(self._Source[role]);
	if clone~="user" or isMany then
		Debug("\tOriginal Element: %s", source);
		source = source:Clone();
		Debug("\tCloned Element: %s", source);
		self._CreatedElements[source] = clone;
	end

	src[key] = source;
	self:_ObtainLayoutParams(source, role);
	if not source.Parent then
		source.Parent = self._Parent;
	end
end

--@brief Removes a child at a given role/index.
--@details This is implicitly performed on _NewIndex, so it is only necessary to call it if you don't want to replace the index.
function RoleParameters:_RemoveChild(role, index)
	FuncCallDebug("_RemoveChild(%s, %s, %s) called", self, role, index);
	local src, key;
	if MANY:Equals(self._Schema[role].Type) then
		src, key = self._ElementMap[role], index;
	else
		src, key = self._ElementMap, role;
	end

	--Delete the old element if this instance created it.
	local child = src[key];
	if child and self._CreatedElements[child] then
		child.Parent = nil;
	end
	self._CreatedElements[child] = nil;
	self._LayoutParams[child] = nil;
	src[key] = nil;
end

--@brief Creates all elements for a given role.
function RoleParameters:_CreateAllElements(role)
	FuncCallDebug("_CreateAllElements(%s, %s) called", self, role);
	if MANY:Equals(self._Schema[role].Type) then
		for i = 1, self._RoleCounts[role] do
			self:_NewChild(role, i);
		end
	else
		self:_NewChild(role);
	end
end

function RoleParameters:_NewRoleFromWildcard(role, wildcardRoleDef)
	FuncCallDebug("_NewRoleFromWildcard(%s, %s, %s) called", self, role, wildcardRoleDef);
	wildcardRoleDef = wildcardRoleDef or self._Schema['*'];
	self._Schema[role] = wildcardRoleDef;
	self._ElementMap[role] = {};
	self._RoleCounts[role] = 0;
	for i, child in pairs(self._Parent:GetChildren()) do
		local childRole = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
		if role == childRole then
			Debug("Found Child of Role %s", role);
			self:_AcceptChildOfRole(child, role);
			break;
		end
	end
	if not self._Source[role] then
		if self._Defaults[role] then
			self._Source[role] = {self._Defaults[role], "defaults"};
		else
			self._Source[role] = {wildcardRoleDef.Default, "schema"};
		end
		--Verify that the LayoutParams for this element have already been cached.
		--It seems rather likely that they would be, but it's worth making sure (esp.
		--since this function won't be called more than once per role).
		self:_ObtainLayoutParams(self._Source[role][1], role);
	end
	self:_CreateAllElements(role);
end

function RoleParameters:_Setup()
	FuncCallDebug("_Setup(%s) called", self);
	Utils.Log.Assert(self._LockParameters == false, "_Setup() called more than once");
	Utils.Log.Assert(self._Parent and self._Schema, "_Setup() should not be called until _Parent and _Schema are defined");
	self._LockParameters = true;

	--Initialize _ElementMap for roles of type "Many"
	Debug("Initializing _ElementMap");
	for role, def in pairs(self._Schema) do
		if role ~= WILDCARD and MANY:Equals(def.Type) then
			Debug("_ElementMap[%s] = {}", role);
			self._ElementMap[role] = {};
		end
	end

	--Initialize _RoleCounts to 0 for all "Many" elements.
	Debug("Initializing _RoleCounts");
	for role, def in pairs(self._Schema) do
		if role ~= WILDCARD and MANY:Equals(def.Type) then
			Debug("_RoleCounts[%s] = 0", role);
			self._RoleCounts[role] = 0;
		end
	end

	--Iterate through children and figure out which roles are defined.
	Debug("Getting values for _Source from children");
	local schemaCopy = Utils.Table.ShallowCopy(self._Schema);
	schemaCopy.DefaultRole = nil;
	for i, child in pairs(self._Parent:GetChildren()) do
		local role = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
		if role and schemaCopy[role] then
			Debug("\tFound child %s of role %s; accepting...", child, role);
			self:_AcceptChildOfRole(child, role);
			schemaCopy[role] = nil;
		end
	end

	--For all that aren't, clone from _Defaults or _Schema.
	Debug("Filling in gaps of _Source");
	for role, def in pairs(schemaCopy) do
		if role ~= WILDCARD then
			if self._Defaults[role] then
				Debug("\t_Source[%s] = {%s, defaults}", role, self._Defaults[role]);
				self._Source[role] = {self._Defaults[role], "defaults"};
			else
				Debug("\t_Source[%s] = {%s, schema}", role, def.Default);
				self._Source[role] = {def.Default, "schema"};
			end
			self:_ObtainLayoutParams(self._Source[role][1], role);
			self:_CreateAllElements(role);
		end
	end

	--Connect to the parent's ChildAdded and ChildRemoved events.
	Debug("Starting %s.ChildAdded and %s.ChildRemoved events", self._Parent, self._Parent);
	self._ChildAddedCxn = self._Parent.ChildAdded:connect(function(child)
		Debug("ChildAdded(%s) fired", child);
		if self._CreatedElements[child] then
			Debug("\tChild was created by this class");
			return;
		end
		local role = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
		Debug("\tNew Child's Role: %s", role);
		if role and self._Source[role] and self._Source[role][2] ~= "user" then
			--We were previously using a default element for this role.
			self:_AcceptChildOfRole(child, role);
		end
	end);
	self._ChildRemovedCxn = self._Parent.ChildRemoved:connect(function(child)
		Debug("ChildRemoved(%s) fired", child);
		if self._CreatedElements[child] then
			Debug("\tChild was created by this class");
			return;
		end
		if self._LayoutParams[child] then
			--We were previously using this element for the role.
			local role = self._LayoutParams[child].Role;
			self:_ReleaseChildOfRole(child, role);
		else
			local potentialRole = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
			if potentialRole and self._Source[potentialRole] and self._Source[potentialRole][1] == child then
				--This child was indeed being used as the source for <potentialRole>
				self:_ReleaseChildOfRole(child, potentialRole);
			end
		end
	end);

	if self._InitializationRoleCounts then
		for role, count in pairs(self._InitializationRoleCounts) do
			self:SetRoleCount(role, count);
		end
		self._InitializationRoleCounts = nil;
	end

	self._Initialized = true;
	for role, def in pairs(self._Schema) do
		if role ~= "DefaultRole" then
			self._RoleSourceChanged:Fire(role);
		end
	end
end

function RoleParameters:_Teardown()
	FuncCallDebug("_Teardown(%s) called", self);
	--Iterate through all created elements and destroy them.
	for element, source in pairs(self._CreatedElements) do
		element.Parent = nil;
	end
	self._ChildAddedCxn:Disconnect();
	self._ChildRemovedCxn:Disconnect();
	self._ChildAddedCxn = false;
	self._ChildRemovedCxn = false;
end

function RoleParameters:_UpdateDefaults()
	FuncCallDebug("_UpdateDefaults(%s) called", self);
	--The defaults table was updated.
	--Verify all LayoutParams exist and are properly populated (all elements).
	for role, default in pairs(self._Defaults) do
		if not default.LayoutParams then
			default.LayoutParams = Utils.Table.ShallowCopy(self._Schema[role].LayoutParams);
		else
			for key, value in pairs(self._Schema[role].LayoutParams) do
				if default.LayoutParams[key] == nil then
					default.LayoutParams[key] = value;
				end
			end
		end
		default.LayoutParams.Role = role;
	end
	--Loop through all roles and check if the defaults table is what we should be using for a given role.
	for role, tup in pairs(self._Source) do
		local src, desc = unpack(tup);
		if desc == 'schema' and self._Defaults[role] then
			self._Source[role] = {self._Defaults[role], "defaults"};
		elseif desc == 'defaults' and not self._Defaults[role] then
			self._Source[role] = {self._Schema[role].Default, "schema"};
		end
		self:_ObtainLayoutParams(self._Source[role][1], role);
		self:_CreateAllElements(role);
		self._RoleSourceChanged:Fire(role);
	end
end

function RoleParameters:GetChildContainer(child)
	FuncCallDebug("GetChildContainer(%s, %s) called", self, child);
	--If child occupies one of the roles, return the parent it should use.
	Debug("self._LayoutParams[%s] = %t", child, self._LayoutParams[child]);
	if self._LayoutParams[child] then
		local role = self._LayoutParams[child].Role;
		local parentName = self._Schema[role].ParentName;
		Debug("ParentName[%s] = %s", role, parentName);
		if parentName then
			local parent = self._Parent[parentName]
			if typeof(parent) == 'Instance' then
				return parent;
			elseif type(parent) == 'table' then
				parent = parent:_GetRbxHandle();
			else
				Utils.Log.Error("Could not get child container for %s (role %s); %s.%s = %s", child, role, self._Parent, parentName, parent);
			end
			return parent;
		else
			if self._Parent and self._Parent._Parent then
				if typeof(self._Parent._Parent) == 'Instance' then
					return self._Parent._Parent;
				end
				local parent = self._Parent._Parent:_GetChildContainer(self._Parent);
				return parent;
			else
				return nil;
			end
		end
		return self._Parent[self._Schema[role].ParentName];
	else
		return self._Parent._Limbo;
	end
end
function RoleParameters:GetChildOfRole(role, index)
	FuncCallDebug("GetChildOfRole(%s, %s, %s) called", self, role, index);
	--Returns the child element which occupies a given role.
	local roleDef = self._Schema[role];
	if not roleDef and self._Schema['*'] then
		roleDef = self._Schema['*'];
		self._Schema[role] = roleDef;
		self:_NewRoleFromWildcard(role, roleDef);
	end
	if MANY:Equals(roleDef.Type) then
		Utils.Log.Assert(1 <= index and index <= self._RoleCounts[role], "index %d for role %s is out of bounds [1, %d]", index, role, self._RoleCounts[role]);
		local child = self._ElementMap[role][index];
		return child, self._LayoutParams[child];
	else
		local child = self._ElementMap[role];
		return self._ElementMap[role], self._LayoutParams[child];
	end
end
function RoleParameters:SetRoleCount(role, count)
	FuncCallDebug("SetRoleCount(%s, %s, %s) called", self, role, count);
	--Sets the highest possible index for a given role. The role type must be "Many".
	if not self._RoleCounts[role] and self._Schema['*'] then
		self:_NewRoleFromWildcard(role);
	end
	local lastCount = self._RoleCounts[role];
	self._RoleCounts[role] = count;
	for i = lastCount + 1, count do
		--Create new.
		self:_NewChild(role, i);
	end
	for i = count + 1, lastCount do
		--Remove old
		self:_RemoveChild(role, i);
	end
end
function RoleParameters:GetRoleCount(role)
	return self._RoleCounts[role];
end
function RoleParameters:GetChildLayoutParams(child)
	FuncCallDebug("GetChildLayoutParams(%s, %s) called", self, child);
	return self._LayoutParams[child]; 
end
function RoleParameters:GetChildRole(child)
	return child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
end
function RoleParameters:GetRoleLayoutParams(role)
	FuncCallDebug("GetRoleLayoutParams(%s) called", self, role);
	local source = self._Source[role][1];

	--If an entry in _LayoutParams exists, grab that.
	if self._LayoutParams[self._Source[role][1]] then
		return self._LayoutParams[source];
	end
	--It's a problem if LayoutParams wasn't cached.
	Utils.Log.Warn("Unable to find cached LayoutParams for role %s (source %s)", role, self._Source[role][2]);

	local params = source.LayoutParams;
	if not params then
		--If source has no LayoutParams table, we can simply source from Schema.
		params = Utils.Table.ShallowCopy(self._Schema[role].LayoutParams or {});
		params.Role = role;
		return params;
	else
		--Otherwise, if source has a LayoutParams table, we want to pad it with any missing elements.
		params = Utils.Table.ShallowCopy(params);
		for key, value in pairs(self._Schema[role].LayoutParams or {}) do
			if params[key] == nil then
				params[key] = value;
			end
		end
		params.Role = role;
		return params;
	end
end

function RoleParameters:Dump()
	Debug("%0.1t", self);
end

function RoleParameters.new()
	local self = setmetatable({}, RoleParameters.Meta);
	self._ChangedEvents = {};
	self._CreatedElements = {};
	self._RoleCounts = {};
	self._LayoutParams = {};
	self._ElementMap = {};
	self._Source = {};
	self._RoleSourceChanged = Utils.new("Event");
	self._LayoutParamsChanged = Utils.new("Event");
	return self;
end

return RoleParameters;
