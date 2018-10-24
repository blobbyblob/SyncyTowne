--[[

This script is responsible for determining creating instances for each role when the role source changes.

Properties:
	_Instances = {[single role] = instance; [many role] = {instance1, instance2, ...}} for all roles.
	_CreatedByMe = {[instance] = role} for all instances created by this class.
	_RoleCounts = {[role] = count}: the number of each instance of role (role must be of type "Many").

Methods:
	SetRoleCount(role, count): the number of elements of a given role which we should instantiate.
	GetRoleCount(role): returns the number of elements with a given role.
	GetChildOfRole(role, index): returns the child which has a given role. If RoleType is single, this will return the first child it finds with the given role and if it finds nothing, it will return the default. If the RoleType is Many, it will return a copy of the first child it finds with the given role and the copy will already be parented in the proper space.
		The parameter index only applies for the Many RoleType and will return the index'th copy of the original.
	_UpdateRole(role): should be called when role has a new source.

--]]

local Utils = require(script.Parent.Parent.Parent.Parent);
local Gui = require(script.Parent.Parent.Parent);
local Debug = Utils.new("Log", "InstanceFulfillment: ", false);

local RoleParameters = _G[script];
local MANY = RoleParameters.RoleType.Many;
local SINGLE = RoleParameters.RoleType.Single;
local WILDCARD = '*';

RoleParameters._Instances = false;
RoleParameters._RoleCounts = false;
RoleParameters._CreatedByMe = false;

function RoleParameters:_FulfillNew(role)
	Debug("FulfillNew(%s) called", role);
	local source, cloneBeforeUse = unpack(self._RoleSource[role]);
	Utils.Log.Assert(cloneBeforeUse, "Don't call _FulfillNew when cloneBeforeUse is false");
	local new = source:Clone();
	new.Archivable = false;
	self._CreatedByMe[new] = role;
	new.Parent = self._Parent;
	return new;
end

function RoleParameters:SetRoleCount(role, count)
	Debug("RoleParameters:SetRoleCount(%s, %s) called", role, count);
	if not self._IsSetup then
		self._RoleCounts[role] = count;
		return;
	end
	local schemaDef = self._Schema[role] or self._Schema[WILDCARD];
	Utils.Log.Assert(schemaDef.Type == MANY, "SetRoleCount must only be called on roles with type \"Many\" (invalid role: %s)", role);
	Debug("Instances: %0t", self._Instances);
	local instancesList = self._Instances[role];
	if not instancesList then
		self:_RoleSourceAddWildcard(role);
		instancesList = self._Instances[role];
	end
	self._RoleCounts[role] = count;
	if #instancesList < count then
		for k = #self._Instances[role] + 1, count do
			self._Instances[role][k] = self:_FulfillNew(role);
		end
	elseif #self._Instances[role] > count then
		for k = count + 1, #self._Instances[role] do
			self:_Begone(self._Instances[role][k]);
			self._Instances[role][k] = nil;
		end
	end
end

function RoleParameters:GetRoleCount(role)
	Debug("RoleParameters:GetRoleCount(%s) called", role);
	return self._RoleCounts[role] or 0;
end

function RoleParameters:GetChildOfRole(role, index)
	Debug("RoleParameters:GetChildOfRole(%s, %s) called", role, index);
	local source = self._RoleSource[role];
	if not source then
		self:_RoleSourceAddWildcard(role);
		source = self._RoleSource[role];
	end
	local schemaDef = self._Schema[role] or self._Schema[WILDCARD];
	local isSingleType = SINGLE == schemaDef.Type;
	if isSingleType then
		return self._Instances[role], source[3];
	else
		if not self._Instances[role] then
			Utils.Log.Error("Instances list for role %s was never initialized", role);
		end
		return self._Instances[role][index], source[3];
	end
end

function RoleParameters:_Begone(obj)
	obj.Parent = nil;
	self._CreatedByMe[obj] = nil;
end

function RoleParameters:_FulfillUpdateRole(role)
	--The role has just updated. Make sure instances match.
	local source, cloneBeforeUse = unpack(self._RoleSource[role]);
	Debug("Role: %s", role);
	local schemaDef = self._Schema[role] or self._Schema[WILDCARD];
	local isSingleType = SINGLE:Equals(schemaDef.Type);
	if isSingleType then
		local obj = self._Instances[role];
		if self._CreatedByMe[obj] then
			self:_Begone(obj);
		end
	end
	if isSingleType and not cloneBeforeUse then
		self._Instances[role] = source;
	elseif isSingleType and cloneBeforeUse then
		self._Instances[role] = self:_FulfillNew(role);
	else
		--If we know when new roles crop up, we can initialize this at exactly the right time.
		--For now, just emit a warning if it's seen at a bad time.
		if not self._Instances[role] then
			Utils.Log.Warn("Failed to initialize array for %s at the right time", role);
			self._Instances[role] = {};
		end
		for k = 1, self._RoleCounts[role] or 0 do
			self:_Begone(self._Instances[role][k]);
			self._Instances[role][k] = self:_FulfillNew(role);
		end
	end
end

function RoleParameters:_FulfillSetup()
	self._Instances = {};
--	self._RoleCounts = {}; --This is done in RoleParameters.new
--	self._CreatedByMe = {}; --This is done in RoleParameters:_Setup()
	for role in pairs(self._RoleSource) do
		local schema = self._Schema[role];
		if schema.Type == MANY then
			self._Instances[role] = {};
			for k = 1, self._RoleCounts[role] or 0 do
				self._Instances[role][k] = {Destroy = function() end};
			end
		end
		self:_FulfillUpdateRole(role);
	end
end

function RoleParameters:_FulfillTeardown()
	for child in pairs(self._CreatedByMe) do
		self:_Begone(child);
	end
	self._CreatedByMe = nil;
	self._Instances = nil;
	self._RoleCounts = nil;
end

return RoleParameters;
