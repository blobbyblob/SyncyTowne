--[[

This script is responsible for determining who is the "source" for a given role.

The user may specify a source which will take the highest priority.
If the role type is single, it will be advised that the class which uses it
does not clone it, but simply uses it as-is.
If the role type is many, the user should clone it.

The _Defaults table may also be defined which specifies that this
is the set of defaults to use when the user doesn't specify.
This is useful to apply "styles" to complicated classes.

The final fallback is to take the default from Schema.

Properties:
	_RoleSource = {[role] = {source, cloneBeforeUse, layoutParams, sourceDescription [internal use]}

Methods:
	_RoleSourceUpdateDefaults(): when a new _Defaults table is specified, call this to ensure we update.
	_RoleSourceSetup(): call this when calling the corresponding _Setup() function of the
		main class definition. At this point, _Schema and _Parent are expected to be defined.
	_RoleSourceCleanup(): call this when tearing down the RoleParameters.
	_RoleSourceAddWildcard(rolename): call this when a new wildcard class should be added.

Events:
	_RoleSourceChanged(role): this function gets fired when the source of a role changes.


The following elements are expected to be defined by the main manager:
	_Schema: the complicated schema definition... you know the one... with the color stain.
	_Defaults: a map of role --> default instance.
	_Parent: the instance which this RoleParameters is managing.
	_CreatedByMe: a map of instance --> true if they were created by this class.
	_RoleSourceChanged: an event.

--]]

local Utils = require(script.Parent.Parent.Parent.Parent);
local Gui = require(script.Parent.Parent.Parent);
local Debug = Utils.new("Log", "RoleSource: ", false);

local RoleParameters = _G[script];
local MANY = RoleParameters.RoleType.Many;
local SINGLE = RoleParameters.RoleType.Single;
local WILDCARD = '*';

RoleParameters._RoleSource = false;
RoleParameters._ChildAddedCxn = false;
RoleParameters._ChildRemovedCxn = false;
RoleParameters._MapSourceToRole = false; --This maps "user"-provided sources to the role they fill.
RoleParameters._RoleSourceChanged = false;

local PadLayoutParams = Utils.Table.Incorporate;

function RoleParameters:_RoleSourceSetup()
	Debug("Schema: %0t", self._Schema);
	self._MapSourceToRole = {};
	self._RoleSource = setmetatable({}, {__index = function(t, role)
		Debug("Searching for role %s", role);
		local wildcardDef = self._Schema[WILDCARD];
		if wildcardDef then
			self:_RoleSourceAddWildcard(role);
			return rawget(t, role);
		else
			Utils.Log.Error("Attempt to get source of invalid role %s", role);
		end
	end});
	--Iterate through children and check if they match any roles.
	--These are "user" specified and have the highest priority.
	for i, child in pairs(self._Parent:GetChildren()) do
		if child:IsA("GuiBase2d") then
			local role = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
			if role and role ~= WILDCARD and not rawget(self._RoleSource, role) then
				if not child.LayoutParams then
					child.LayoutParams = Utils.Table.ShallowCopy(self._Schema[role].LayoutParams);
				else
					PadLayoutParams(child.LayoutParams, self._Schema[role].LayoutParams);
				end
				self._RoleSource[role] = {child, MANY:Equals(self._Schema[role].Type), child.LayoutParams, "user"};
				self._MapSourceToRole[child] = role;
			end
		end
	end
	--Iterate through _Defaults and check if they match any roles which aren't occupied by user-specified elements.
	if self._Defaults then
		for role, default in pairs(self._Defaults) do
			if role ~= WILDCARD and not rawget(self._RoleSource, role) then
				self._RoleSource[role] = {default, true, default.LayoutParams, "defaults"}
			end
		end
	end
	--Iterate through _Schema and check if it matches any roles which aren't occupied by anything else.
	for role, schemaDef in pairs(self._Schema) do
		if role ~= "DefaultRole" then
			if not schemaDef.Default.LayoutParams then
				Debug("%0.0t", schemaDef.Default);
				Debug("Schema[%s].Default.LayoutParams not defined; assigning %t", role, schemaDef.LayoutParams);
				schemaDef.Default.LayoutParams = schemaDef.LayoutParams;
			else
				Debug("Schema[%s].Default.LayoutParams defined as %t; padding with %t", role, schemaDef.Default.LayoutParams, schemaDef.LayoutParams);
				PadLayoutParams(schemaDef.Default.LayoutParams, schemaDef.LayoutParams);
			end
			if role ~= WILDCARD and not rawget(self._RoleSource, role) then
				self._RoleSource[role] = {schemaDef.Default, true, schemaDef.Default.LayoutParams, "schema"};
			end
		end
	end
	--Hook into self._Parent.ChildAdded and ChildRemoved to update user roles when the user adds/removes children.
	self._ChildAddedCxn = self._Parent.ChildAdded:connect(function(child)
		if self._CreatedByMe[child] then return; end
		if not child:IsA("GuiBase2d") then return; end
		local childRole = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
		if childRole then
			Debug("Read in child of role %s", childRole);
			if not self._Schema[childRole] then
				if self._Schema[WILDCARD] then
					Debug("Role %s doesn't exist, but wildcard does", childRole);
				else
					Utils.Log.Warn("Child %s added with unknown role %s", child, childRole);
					return;
				end
			end
			local src = rawget(self._RoleSource, childRole);
			if not src or src[4] ~= 'user' then
				Debug("Child %s new representative for role %s", child, childRole);
				local schemaRole = self._Schema[childRole] and childRole or WILDCARD;
				local layoutParams = PadLayoutParams(child.LayoutParams or {}, self._Schema[schemaRole].LayoutParams);
				if not self._Instances[childRole] and self._Schema[schemaRole].Type == MANY then
					self._Instances[childRole] = {};
				end
				self._RoleSource[childRole] = {child, MANY:Equals(self._Schema[schemaRole].Type), layoutParams, "user"};
				self._MapSourceToRole[child] = childRole;
				self:_FulfillUpdateRole(childRole);
				self._RoleSourceChanged:Fire(childRole);
			end
		end
	end)
	self._ChildRemovedCxn = self._Parent.ChildRemoved:connect(function(child)
		local role = self._MapSourceToRole[child];
		if role then
			Debug("Child %s removed which represented role %s", child, role);
			self._MapSourceToRole[child] = nil;
			self._RoleSource[role] = nil;
			self:_RoleSourceFindReplacement(role);
		end
	end)
end

function RoleParameters:_RoleSourceCleanup()
	--Disconnect ChildAdded and ChildRemoved events.
	if self._IsSetup then
		self._ChildAddedCxn:disconnect();
		self._ChildAddedCxn = nil;
		self._ChildRemovedCxn:disconnect();
		self._ChildRemovedCxn = nil;
	end
end

function RoleParameters:_RoleSourceFindReplacement(role)
	Debug("Searching for replacement for role %s", role);
	local isWildcardRole = not self._Schema[role] and self._Schema[WILDCARD];
	--Find a replacement. First check the children, then _Defaults, then _Schema. If role is a wildcard, we also should search that _Defaults entry.
	for i, child in pairs(self._Parent:GetChildren()) do
		Debug("Checking child %s", child);
		if child:IsA("GuiBase2d") then
			local childRole = child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
			if role == childRole and not self._CreatedByMe[child] then
				Debug("Found child of role %s", role);
				local r = self._Schema[role] and role or WILDCARD;
				local layoutParams = PadLayoutParams(child.LayoutParams or {}, self._Schema[r].LayoutParams);
				child.LayoutParams = layoutParams;
				self._RoleSource[role] = {child, MANY:Equals(self._Schema[r].Type), layoutParams, "user"};
				self._MapSourceToRole[child] = role;
				break;
			end
		end
	end
	if not rawget(self._RoleSource, role) and self._Defaults then
		Debug("Searching defaults; role %s; isWildcard: %s", role, isWildcardRole);
		if self._Defaults[role] then
			Debug("Found default of role %s", role);
			self._RoleSource[role] = {self._Defaults[role], true, self._Defaults[role].LayoutParams, "defaults"};
		elseif isWildcardRole and self._Defaults[WILDCARD] then
			Debug("Found wildcard default", role);
			self._RoleSource[role] = {self._Defaults[WILDCARD], true, self._Defaults[WILDCARD].LayoutParams, "defaults"};
		end
	end
	if not rawget(self._RoleSource, role) then
		if self._Schema[role] then
			Debug("Found role %s in schema", role);
			self._RoleSource[role] = {self._Schema[role].Default, true, self._Schema[role].Default.LayoutParams, "schema"};
		elseif isWildcardRole and self._Schema[WILDCARD] then
			Debug("Found wildcard schema");
			self._RoleSource[role] = {self._Schema[WILDCARD].Default, true, self._Schema[WILDCARD].Default.LayoutParams, "schema"};
		end
	end
	self:_FulfillUpdateRole(role);
	self._RoleSourceChanged:Fire(role);
end

function RoleParameters:_RoleSourceUpdateDefaults()
	local defaults = self._Defaults;
	if not defaults then
		defaults = {};
	end

	--Iterate through _Defaults and ensure LayoutParams is properly defined for them all.
	for role, default in pairs(defaults) do
		if not default.LayoutParams then
			Debug("Defaults[%s].LayoutParams not defined; assigning %t", role, self._Schema[role].LayoutParams);
			default.LayoutParams = self._Schema[role].LayoutParams;
		else
			Debug("Defaults[%s].LayoutParams defined as %t; padding with %t", role, default.LayoutParams, self._Schema[role].LayoutParams);
			PadLayoutParams(default.LayoutParams, self._Schema[role].LayoutParams);
		end
	end

	--Iterate through all roles and check if any were previously using defaults/schema. These should be updated.
	for role, tup in pairs(self._RoleSource) do
		local isWildcardRole = not self._Schema[role] and self._Schema[WILDCARD];
		if (defaults[role] or defaults[WILDCARD] and isWildcardRole) and (tup[4] == "defaults" or tup[4] == "schema") then
			Debug("Defaults defines role %s; overriding previous (from %s)", role, tup[4]);
			local r = defaults[role] and role or WILDCARD;
			self._RoleSource[role] = {defaults[r], true, defaults[r].LayoutParams, "defaults"};
			self:_FulfillUpdateRole(role);
			self._RoleSourceChanged:Fire(role);
		elseif not defaults[role] and tup[4] == "defaults" then
			Debug("Defaults does not define %s, but previous was defaults; switching to schema", role);
			self._RoleSource[role] = {self._Schema[role].Default, true, self._Schema[role].Default.LayoutParams, "schema"};
			self:_FulfillUpdateRole(role);
			self._RoleSourceChanged:Fire(role);
		end
	end
end

function RoleParameters:_RoleSourceAddWildcard(role)
	local wildcardDef = self._Schema[WILDCARD];
	Utils.Log.Assert(wildcardDef, "Must have wildcard definition in schema in order to generate role %s", role);
	if wildcardDef.Type == MANY then self._Instances[role] = {}; end
	return self:_RoleSourceFindReplacement(role);
end

function RoleParameters:_RoleSourceDump()
	Debug("%0t", self._RoleSource);
	Debug("%t", self._MapSourceToRole);
end

return RoleParameters;
