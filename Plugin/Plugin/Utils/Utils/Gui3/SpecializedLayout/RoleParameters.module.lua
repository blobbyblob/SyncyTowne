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
	GetChildLayoutParams(child): gets the layout params for a given child.
	GetChildRole(child): gets the role of a child.
	GetRoleLayoutParams(role): returns the layout params for a given role.

	GetChildOfRole(role, index): returns the child which has a given role. If RoleType
		is single, this will return the first child it finds with the given role and
		if it finds nothing, it will return the default. If the RoleType is Many, it
		will return a copy of the first child it finds with the given role and the
		copy will already be parented in the proper space.
		  The parameter index only applies for the Many RoleType and will return the
		index'th copy of the original.
		  This also returns the layout params.
	SetRoleCount(role, count): the number of elements of a given role which we should instantiate.
	GetRoleCount(role): returns the number of elements with a given role.
	Clone(): creates a copy of this object. Parent will not be set. Other properties will.
Events:
	RoleSourceChanged(role): fires when the source object for a given role is changed.
	LayoutParamsChanged(role): fires when a child gets a new LayoutParams or the existing one gets new key/value pairs.
		For the time being, this will never fire.


--]]

local Utils = require(script.Parent.Parent.Parent);
local Gui = require(script.Parent.Parent);
local Debug = Utils.new("Log", "RoleParameters: ", false);
local FuncCallDebug = Utils.new("Log", "RoleParameters.", false);

local RoleParameters = Utils.new("Class", "RoleParameters");

--Single: if there are no children with this role, we make sure of it by cloning some default & parenting it to the object.
--Many: this object may be cloned several times to satisfy the needs of the SpecializedLayout.
RoleParameters.RoleType = Utils.new("Enum", "RoleType", "Single", "Many");
local MANY = RoleParameters.RoleType.Many;
local SINGLE = RoleParameters.RoleType.Single;
local WILDCARD = '*';

RoleParameters._IsSetup = false;
RoleParameters._CreatedByMe = false;
RoleParameters._Schema = false;
RoleParameters._Parent = false;
RoleParameters._Defaults = false;
RoleParameters._LayoutParamsChanged = false;

function RoleParameters.Set:Schema(v)
	self._Schema = v;
	for role, def in pairs(self._Schema) do
		if role ~= "DefaultRole" then
			def.Type = RoleParameters.RoleType:InterpretEnum("Schema["..role.."].Type", def.Type);
			Utils.Log.AssertNonNilAndType("Schema["..role.."].LayoutParams", "table", def.LayoutParams);
			Utils.Log.AssertNonNilAndType("Schema["..role.."].Default", "table", def.Default);
			def.LayoutParams.Role = role;
		end
	end
	if self._Schema and self._Parent then
		self:_Setup();
	end
end
function RoleParameters.Set:Parent(v)
	self._Parent = v;
	if self._Schema and self._Parent then
		self:_Setup();
	end
end
function RoleParameters.Set:Defaults(v)
	self._Defaults = v;
	if self._IsSetup then
		self:_RoleSourceUpdateDefaults();
	end
end

RoleParameters.Get.Schema = "_Schema";
RoleParameters.Get.Parent = "_Parent";
RoleParameters.Get.Defaults = "_Defaults";
function RoleParameters.Get:RoleSourceChanged()
	return self._RoleSourceChanged.Event;
end
function RoleParameters.Get:LayoutParamsChanged()
	return self._LayoutParamsChanged.Event;
end

--Populate many functions which are defined by RoleSource.
_G[script.RoleSource] = RoleParameters;
_G[script.InstanceFulfillment] = RoleParameters;
require(script.RoleSource);
require(script.InstanceFulfillment);
_G[script.RoleSource] = nil;
_G[script.InstanceFulfillment] = nil;

function RoleParameters:_Setup()
	Debug("_Setup() called");
	if self._IsSetup then
		Utils.Log.Warn("Already set up");
	end
	self._IsSetup = true;
	self:_RoleSourceSetup();
	self:_FulfillSetup();
	Debug("_Setup() Complete")
	--Fire RoleSourceChanged for every role.
	for role in pairs(self._RoleSource) do
		self._RoleSourceChanged:Fire(role);
	end
end

function RoleParameters:_Teardown()
	Debug("Teardown() called");
	self:_FulfillTeardown();
	self:_RoleSourceCleanup();
	Debug("Teardown complete");
end

function RoleParameters:_NewRole(role)
	Debug("_NewRole(%s) fired", role);
end

function RoleParameters:GetChildContainer(child)
	FuncCallDebug("GetChildContainer(%s) called", child);
	local childRole = self._CreatedByMe[child] or child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
	local schema = self._Schema[childRole] or self._Schema[WILDCARD];
	Utils.Log.Assert(schema, "Schema not found for role %s (from child %s)", childRole, child);
	local source, cloneBeforeUse = unpack(self._RoleSource[childRole]);
	Debug("ChildRole: %s; isSource: %s; clone: %s", childRole, source==child, cloneBeforeUse);
	if source==child and cloneBeforeUse then
		return false;
	end
	local parentName = schema.ParentName;
	if parentName then
		--There are two ways to do this.
		--1. Always assume parentName belongs to a type from this library.
--		return self._Parent[parentName]:_GetChildContainer(child);
		--2. Always assume parentName is a raw roblox type.
		--return self._Parent[parentName];
		--3. Determine at runtime.
		local parent = self._Parent[parentName];
		if parent then
			if typeof(parent) == 'table' then
				Debug("Parent is a built-in type");
				return parent:_GetChildContainer(child);
			else
				Debug("Parent is a roblox type");
				return parent;
			end
		else
			Debug("Parent doesn't exist");
			return nil;
		end
	else
		Debug("ParentName not defined");
		return nil;
	end
end
function RoleParameters:GetChildLayoutParams(child)
	if child.LayoutParams then
		return child.LayoutParams;
	end
	Utils.Log.Warn("Failed to find LayoutParams in child %s; plugging in default", child);
	local childRole = self._CreatedByMe[child] or self._Schema.DefaultRole;
	local params = Utils.Table.ShallowCopy(self._Schema[childRole].LayoutParams);
	child.LayoutParams = params;
	return params;
end
function RoleParameters:GetChildRole(child)
	return self._CreatedByMe[child] or child.LayoutParams and child.LayoutParams.Role or self._Schema.DefaultRole;
end
function RoleParameters:GetRoleLayoutParams(role)
	--Get the layout params of the source for a given role.
	local source = self._RoleSource[role];
	if source then
		return source[3];
	else
		self:_RoleSourceAddWildcard(role);
		return self._RoleSource[role];
	end
end

function RoleParameters:Clone()
	local n = RoleParameters.new();
	n.Schema = self.Schema;
	n.Defaults = self.Defaults;
	n._RoleCounts = Utils.Table.ShallowCopy(self._RoleCounts);
	return n;
end

function RoleParameters.new()
	local self = setmetatable({}, RoleParameters.Meta);
	self._RoleSourceChanged = Utils.new("Event");
	self._RoleSourceChanged.Event:connect(function(role)
		self:_NewRole(role);
	end)
	self._LayoutParamsChanged = Utils.new("Event");
	self._CreatedByMe = {};
	self._RoleCounts = {};
	return self;
end

local function Validate(expected, actual)
	for i, v in pairs(expected) do
		Utils.Log.AssertEqual("expected[" .. tostring(i) .. "]", expected[i], actual[i]);
	end
end
function Gui.Test.RoleParameters_RoleSource()
	local s = RoleParameters.new();
	s.Parent = Gui.new("Rectangle");
	s.Schema = {
		Single = {
			Type = "Single";
			LayoutParams = {foo = 'bar'; key = 'value';};
			Default = Gui.Create "Rectangle" {LayoutParams = {key = 'none'};};
		};
		Many = {
			Type = "Many";
			LayoutParams = {foo = 'baz'; key = 'value';};
			Default = Gui.Create "Rectangle" {LayoutParams = {key = 'none'};};
			ParentName = "_Frame";
		};
	};
	Validate({s.Schema.Single.Default, true, s.Schema.Single.Default.LayoutParams, "schema"}, s._RoleSource.Single);
	Validate({s.Schema.Many.Default, true, s.Schema.Many.Default.LayoutParams, "schema"}, s._RoleSource.Many);

	s.Defaults = {
		Single = Gui.Create "Rectangle" {LayoutParams = {key = 'a'}};
		Many = Gui.Create "Rectangle" {LayoutParams = {key = 'b'}};
	};
	Validate({s.Defaults.Single, true, s.Defaults.Single.LayoutParams, "defaults"}, s._RoleSource.Single);
	Validate({s.Defaults.Many, true, s.Defaults.Many.LayoutParams, "defaults"}, s._RoleSource.Many);
	Validate({foo = "bar", key = "a", Role = "Single"}, s.Defaults.Single.LayoutParams);
	Validate({foo = "baz", key = "b", Role = "Many"}, s.Defaults.Many.LayoutParams);

	s.Defaults = {};
	Validate({s.Schema.Single.Default, true, s.Schema.Single.Default.LayoutParams, "schema"}, s._RoleSource.Single);
	Validate({s.Schema.Many.Default, true, s.Schema.Many.Default.LayoutParams, "schema"}, s._RoleSource.Many);

	s.Defaults = {
		Single = Gui.new("Rectangle");
	};
	Validate({s.Defaults.Single, true, s.Defaults.Single.LayoutParams, "defaults"}, s._RoleSource.Single);
	Validate({s.Schema.Many.Default, true, s.Schema.Many.Default.LayoutParams, "schema"}, s._RoleSource.Many);

	local x = Gui.Create "Rectangle" {
		Name = "CustomizedSingleRole";
		LayoutParams = {
			Role = "Single";
			foo = "Hello, World!";
		};
		Parent = s.Parent;
	};
	Validate({x, false, x.LayoutParams, "user"}, s._RoleSource.Single);
	Validate({foo = "Hello, World!", key = "value", Role = "Single"}, x.LayoutParams);
	Validate({s.Schema.Many.Default, true, s.Schema.Many.Default.LayoutParams, "schema"}, s._RoleSource.Many);
	x.Parent = nil;
	Validate({s.Defaults.Single, true, s.Defaults.Single.LayoutParams, "defaults"}, s._RoleSource.Single);
	Validate({s.Schema.Many.Default, true, s.Schema.Many.Default.LayoutParams, "schema"}, s._RoleSource.Many);
	x.LayoutParams.Role = "Many";
	x.LayoutParams.foo = nil;
	x.Parent = s.Parent;
	Validate({s.Defaults.Single, true, s.Defaults.Single.LayoutParams, "defaults"}, s._RoleSource.Single);
	Validate({foo = "bar", key = "value", Role = "Single"}, s.Defaults.Single.LayoutParams);
	Validate({x, true, x.LayoutParams, "user"}, s._RoleSource.Many);
end

function Gui.Test.RoleParameters_Wildcard()
	local s = RoleParameters.new();
	s.Parent = Gui.new("Rectangle");
	s.Schema = {
		['*'] = {
			Type = "Many";
			LayoutParams = {wildcard = 'value'};
			Default = Gui.Create "Rectangle" {};
			ParentName = "_Frame";
		};
	};
	local function Validate(expected, actual)
		for i, v in pairs(expected) do
			Utils.Log.AssertEqual("expected[" .. tostring(i) .. "]", expected[i], actual[i]);
		end
	end
	s:_RoleSourceAddWildcard('customrole1');
	Validate({s.Schema['*'].Default, true, s.Schema['*'].LayoutParams, "schema"}, s._RoleSource.customrole1);
	Validate({wildcard = "value", Role = "*"}, s._RoleSource.customrole1[3]);
	local x = Gui.Create "Rectangle" {
		LayoutParams = {Role = "customrole2"; wildcard='lel';};
		Parent = s.Parent;
	};

	Validate({s.Schema['*'].Default, true, s.Schema['*'].LayoutParams, "schema"}, s._RoleSource.customrole1);
	Validate({wildcard = "value", Role = "*"}, s._RoleSource.customrole1[3]);
	Validate({x, true, x.LayoutParams, "user"}, s._RoleSource.customrole2);
	Validate({wildcard = "lel", Role = "customrole2"}, s._RoleSource.customrole2[3]);
	s.Defaults = {
		['*'] = Gui.Create "Rectangle" {LayoutParams = {wildcard = 'foo'}};
	};

	Validate({s.Defaults['*'], true, s.Defaults['*'].LayoutParams, "defaults"}, s._RoleSource.customrole1);
	Validate({wildcard = "foo", Role = "*"}, s._RoleSource.customrole1[3]);
	Validate({x, true, x.LayoutParams, "user"}, s._RoleSource.customrole2);
	Validate({wildcard = "lel", Role = "customrole2"}, s._RoleSource.customrole2[3]);

	local y = Gui.Create "Rectangle" {
		LayoutParams = {Role = "customrole2"; wildcard='lel1';};
		Parent = s.Parent;
	};
	Validate({s.Defaults['*'], true, s.Defaults['*'].LayoutParams, "defaults"}, s._RoleSource.customrole1);
	Validate({wildcard = "foo", Role = "*"}, s._RoleSource.customrole1[3]);
	Validate({x, true, x.LayoutParams, "user"}, s._RoleSource.customrole2);
	Validate({wildcard = "lel", Role = "customrole2"}, s._RoleSource.customrole2[3]);

	x.Parent = nil;
	Validate({s.Defaults['*'], true, s.Defaults['*'].LayoutParams, "defaults"}, s._RoleSource.customrole1);
	Validate({wildcard = "foo", Role = "*"}, s._RoleSource.customrole1[3]);
	Validate({y, true, y.LayoutParams, "user"}, s._RoleSource.customrole2);
	Validate({wildcard = "lel1", Role = "customrole2"}, s._RoleSource.customrole2[3]);

	y.LayoutParams.Role = "customrole1";
	y.Parent = s.Parent;
	Validate({y, true, y.LayoutParams, "user"}, s._RoleSource.customrole1);
	Validate({wildcard = "lel1", Role = "customrole1"}, s._RoleSource.customrole1[3]);
	Validate({s.Defaults['*'], true, s.Defaults['*'].LayoutParams, "defaults"}, s._RoleSource.customrole2);
	Validate({wildcard = "foo", Role = "*"}, s._RoleSource.customrole2[3]);
end

function Gui.Test.RoleParameters_TwoUsers()
	local s = RoleParameters.new();
	s.Schema = {
		Role = {
			Type = "Single";
			LayoutParams = {};
			Default = Gui.new("Rectangle");
		};
		DefaultRole = "Role";
	};
	s.Parent = Gui.new("Rectangle");

	--Create two objects to add.
	local c1 = Gui.Create "Rectangle" {
		LayoutParams = {Role = "Role"};
		Name = "c1";
	};
	local c2 = Gui.Create "Rectangle" {
		LayoutParams = {Role = "Role"};
		Name = "c2";
	};

	--Add c1, add c2, remove c1, then remove c2.
	c1.Parent = s.Parent;
	Validate({c1, false, c1.LayoutParams, "user"}, s._RoleSource.Role);
	c2.Parent = s.Parent;
	Validate({c1, false, c1.LayoutParams, "user"}, s._RoleSource.Role);
	c1.Parent = nil;
	Validate({c2, false, c2.LayoutParams, "user"}, s._RoleSource.Role);
	c2.Parent = nil;
	Validate({s.Schema.Role.Default, true, s.Schema.Role.LayoutParams, "schema"}, s._RoleSource.Role);
end

local SCHEMA_WILDCARD_SINGLE = {
	['*'] = {
		Type = "Single";
		LayoutParams = {};
		Default = Gui.new("Rectangle");
	};
	DefaultRole = "Role";
};

function Gui.Test.RoleParameters_TwoWildcardUsers()
	local s = RoleParameters.new();
	s.Schema = SCHEMA_WILDCARD_SINGLE;
	s.Parent = Gui.new("Rectangle");

	--Create two objects to add.
	local c1 = Gui.Create "Rectangle" {
		LayoutParams = {Role = "Role"};
		Name = "c1";
	};
	local c2 = Gui.Create "Rectangle" {
		LayoutParams = {Role = "Role"};
		Name = "c2";
	};

	--Add c1, add c2, remove c1, then remove c2.
	c1.Parent = s.Parent;
	Validate({c1, false, c1.LayoutParams, "user"}, s._RoleSource.Role);
	c2.Parent = s.Parent;
	Validate({c1, false, c1.LayoutParams, "user"}, s._RoleSource.Role);
	c1.Parent = nil;
	Validate({c2, false, c2.LayoutParams, "user"}, s._RoleSource.Role);
	c2.Parent = nil;
	Validate({s.Schema['*'].Default, true, s.Schema['*'].LayoutParams, "schema"}, s._RoleSource.Role);
end

function Gui.Test.RoleParameters_IndexWildcard()
	--Create a new wildcard role by attempting to index it.
	--Ensure the event is called.
	local s = RoleParameters.new();
	s.Schema = SCHEMA_WILDCARD_SINGLE;
	s.Parent = Gui.new("Rectangle");

	--Count every time RoleSourceChanged fires.
	local i = 0;
	local cxn = s._RoleSourceChanged.Event:connect(function()
		i = i + 1;
	end)

	Validate({s.Schema['*'].Default, true, s.Schema['*'].LayoutParams, "schema"}, s._RoleSource.Test)

	Utils.Log.AssertEqual("RoleSourceChanged fire count", 1, i);
	cxn:disconnect();
end

local SCHEMA_MANY = {
	Many = {
		Type = "Many";
		LayoutParams = {};
		Default = Gui.Create "Rectangle" {};
	};
	DefaultRole = "Many";
}

function Gui.Test.RoleParameters_SetCountBeforeSetup()
	local s = RoleParameters.new();
	s.Schema = SCHEMA_MANY;
	s:SetRoleCount("Many", 2);
	s.Parent = Gui.new("Rectangle");
	Utils.Log.AssertEqual("Many.1", false, not s:GetChildOfRole("Many", 1));
	Utils.Log.AssertEqual("Many.2", false, not s:GetChildOfRole("Many", 2));
end

function Gui.Test.RoleParameters_GetChildContainer()
	local s = RoleParameters.new();
	s.Schema = {
		A = { Type = "Single"; LayoutParams = {}; Default = Gui.Create "Rectangle" {}; ParentName = "a"; };
		B = { Type = "Single"; LayoutParams = {}; Default = Gui.Create "Rectangle" {}; ParentName = "b"; };
	}
	local g = Gui.new("Rectangle");
	rawset(g, 'a', Gui.new("Rectangle"));
	rawset(g, 'b', Instance.new("TextLabel"));
	s.Parent = g;

	Utils.Log.AssertEqual("A's Parent", g.a:_GetRbxHandle(), s:GetChildContainer(s:GetChildOfRole("A")));
	Utils.Log.AssertEqual("B's Parent", g.b, s:GetChildContainer(s:GetChildOfRole("B")));
end

function Gui.Test.RoleParameters_VerifyArchivable()
	--Elements spawned by a RoleParameters should be Archivable = false.
	local s = RoleParameters.new();
	s.Schema = SCHEMA_MANY;
	s.Parent = Gui.new("Rectangle");

	s:SetRoleCount("Many", 3);

	Utils.Log.AssertEqual("At least one element was created", false, not next(s._CreatedByMe));
	local count = 0;
	for obj in pairs(s._CreatedByMe) do
		count = count + 1;
		Utils.Log.AssertEqual("obj.Archivable", false, obj.Archivable);
	end
	Utils.Log.AssertEqual("Number of \"Many\" role objects", 3, count);
end

return RoleParameters;
