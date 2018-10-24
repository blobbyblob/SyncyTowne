local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);
local RoleParameters = require(script.RoleParameters);

local Debug = Utils.new("Log", "SpecializedLayout: ", false);

local Super = Gui.GuiBase2d;
local SpecializedLayout = Utils.new("Class", "SpecializedLayout", Super);

SpecializedLayout._ChildParameters = false;
SpecializedLayout._Limbo = Instance.new("Frame");

function SpecializedLayout:_Clone(new)
	new._ChildParameters:_Teardown();
	new._ChildParameters = self._ChildParameters:Clone();
	new._ChildParameters.Parent = new;
end
function SpecializedLayout:_GetChildContainerRaw(child)
	local container = self._ChildParameters:GetChildContainer(child)
	return container;
end

function SpecializedLayout.new()
	local self = setmetatable(Super.new(), SpecializedLayout.Meta);
	self._ChildParameters = RoleParameters.new();
	self._ChildParameters.Parent = self;
	return self;
end

local function Dump(roleParameters)
	Debug("%0t", roleParameters);
--	Debug("ChangedEvents: %t", roleParameters._ChangedEvents);
--	Debug("CreatedElements: %t", roleParameters._CreatedElements);
--	Debug("RoleCounts: %t", roleParameters._RoleCounts);
--	Debug("LayoutParams: %t", roleParameters._LayoutParams);
--	for i, v in pairs(roleParameters._LayoutParams) do
--		Debug("\t%s = %t", i, v);
--	end
--	Debug("ElementMap: %t", roleParameters._ElementMap);
--	Debug("Source: %1t");
end

function Gui.Test.SpecializedLayout_Basic(sgui)
	local r = Gui.new("Rectangle");
	r.Size = UDim2.new(0, 110, 0, 110);
	local s = SpecializedLayout.new();
	s.Parent = r;
	local function Refresh(role)
		if role == 'A' then
			local a = s._ChildParameters:GetChildOfRole("A");
			a.Size = UDim2.new(0, 30, 1, -10);
			a.Position = UDim2.new(0, 40, 0, 5);
		elseif role == 'B' then
			if s._ChildParameters:GetRoleCount("B") >= 2 then
				local b1 = s._ChildParameters:GetChildOfRole("B", 1);
				local b2 = s._ChildParameters:GetChildOfRole("B", 2);
				Debug("Applying Size/Position to %s and %s", b1, b2);
				b1.Size = UDim2.new(0, 30, 1, -10);
				b1.Position = UDim2.new(0, 5, 0, 5);
				b2.Size = UDim2.new(0, 30, 1, -10);
				b2.Position = UDim2.new(0, 75, 0, 5);
			end
		end
	end
	s._ChildParameters.RoleSourceChanged:connect(function(role)
		Debug("RoleSourceChanged: %s", role);
		Refresh(role);
	end)
	r.Parent = sgui;
	local redRect = Gui.new("Rectangle");
	redRect.Color = Color3.new(1, 0, 0);
	redRect.Name = "redRect";
	local greenRect = Gui.new("Rectangle");
	greenRect.Name = "greenRect";
	greenRect.Color = Color3.new(0, 1, 0);
	s._ChildParameters.Schema = {
		A = {
			Type = RoleParameters.RoleType.Single;
			Default = redRect;
			LayoutParams = {
				Key1 = "foo";
				Key2 = "bar";
			};
		};
		B = {
			Type = RoleParameters.RoleType.Many;
			Default = greenRect;
			LayoutParams = {
				Key3 = "hello";
				Key4 = "world";
			};
		};
		DefaultRole = "A";
	};
	s._ChildParameters:SetRoleCount("B", 2);
	Refresh("A");
	Refresh("B");

	--Part 1. Use SpecializedLayout.Schema.Default
	local a = s._ChildParameters:GetChildOfRole("A");
	local b1 = s._ChildParameters:GetChildOfRole("B", 1);
	local b2 = s._ChildParameters:GetChildOfRole("B", 2);

--	b1.Size = UDim2.new(0, 30, 1, -10);
--	b1.Position = UDim2.new(0, 5, 0, 5);
--	a.Size = UDim2.new(0, 30, 1, -10);
--	a.Position = UDim2.new(0, 40, 0, 5);
--	b2.Size = UDim2.new(0, 30, 1, -10);
--	b2.Position = UDim2.new(0, 75, 0, 5);
--	wait();

	Dump(s._ChildParameters);

	Utils.Log.AssertEqual("B1.Parent", s, b1.Parent);
	Utils.Log.AssertEqual("A.Parent", s, a.Parent);
	Utils.Log.AssertEqual("B2.Parent", s, b2.Parent);
	Utils.Log.AssertEqual("B1.AbsoluteSize", Vector2.new(30, 100), b1.AbsoluteSize);
	Utils.Log.AssertEqual("A.AbsoluteSize", Vector2.new(30, 100), a.AbsoluteSize);
	Utils.Log.AssertEqual("B2.AbsoluteSize", Vector2.new(30, 100), b2.AbsoluteSize);
	Utils.Log.AssertEqual("B1.AbsolutePosition", Vector2.new(5, 5), b1.AbsolutePosition);
	Utils.Log.AssertEqual("A.AbsolutePosition", Vector2.new(40, 5), a.AbsolutePosition);
	Utils.Log.AssertEqual("B2.AbsolutePosition", Vector2.new(75, 5), b2.AbsolutePosition);
	Utils.Log.AssertEqual("A.LayoutParams.Key1", "foo", s._ChildParameters:GetChildLayoutParams(a).Key1);
	Utils.Log.AssertEqual("A.LayoutParams.Key2", "bar", s._ChildParameters:GetChildLayoutParams(a).Key2);
	Utils.Log.AssertEqual("B1.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(b1).Key3);
	Utils.Log.AssertEqual("B1.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(b1).Key4);
	Utils.Log.AssertEqual("B2.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(b2).Key3);
	Utils.Log.AssertEqual("B2.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(b2).Key4);
--	wait();

	Dump(s._ChildParameters);

	--Part 2. Use SpecializedLayout.Defaults
	local g1 = Gui.new("Gradient");
	g1.Color1 = Color3.new(1, 0, 0);
	g1.Color2 = Color3.new(.7, 0, 0);
	g1.Direction = "Vertical";
	local g2 = Gui.new("Gradient");
	g2.Direction = "Vertical";
	g2.Color1 = Color3.new(0, 1, 0);
	g2.Color2 = Color3.new(0, .7, 0);
	s._ChildParameters.Defaults = {
		A = g1;
		B = g2;
	};
	Dump(s._ChildParameters);

	local c = s._ChildParameters:GetChildOfRole("A");
	local d1 = s._ChildParameters:GetChildOfRole("B", 1);
	local d2 = s._ChildParameters:GetChildOfRole("B", 2);
	Utils.Log.AssertEqual("B1.ClassName", "Gradient", d1.ClassName);
	Utils.Log.AssertEqual("A.ClassName", "Gradient", c.ClassName);
	Utils.Log.AssertEqual("B2.ClassName", "Gradient", d2.ClassName);

--	d1.Size = UDim2.new(0, 30, 1, -10);
--	d1.Position = UDim2.new(0, 5, 0, 5);
--	c.Size = UDim2.new(0, 30, 1, -10);
--	c.Position = UDim2.new(0, 40, 0, 5);
--	d2.Size = UDim2.new(0, 30, 1, -10);
--	d2.Position = UDim2.new(0, 75, 0, 5);

	Utils.Log.AssertEqual("B1.AbsoluteSize", Vector2.new(30, 100), d1.AbsoluteSize);
	Utils.Log.AssertEqual("A.AbsoluteSize", Vector2.new(30, 100), c.AbsoluteSize);
	Utils.Log.AssertEqual("B2.AbsoluteSize", Vector2.new(30, 100), d2.AbsoluteSize);
	Utils.Log.AssertEqual("B1.AbsolutePosition", Vector2.new(5, 5), d1.AbsolutePosition);
	Utils.Log.AssertEqual("A.AbsolutePosition", Vector2.new(40, 5), c.AbsolutePosition);
	Utils.Log.AssertEqual("B2.AbsolutePosition", Vector2.new(75, 5), d2.AbsolutePosition);
	Utils.Log.AssertEqual("B1.Parent", s, d1.Parent);
	Utils.Log.AssertEqual("A.Parent", s, c.Parent);
	Utils.Log.AssertEqual("B2.Parent", s, d2.Parent);
	Utils.Log.AssertEqual("A.LayoutParams.Key1", "foo", s._ChildParameters:GetChildLayoutParams(c).Key1);
	Utils.Log.AssertEqual("A.LayoutParams.Key2", "bar", s._ChildParameters:GetChildLayoutParams(c).Key2);
	Utils.Log.AssertEqual("B1.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(d1).Key3);
	Utils.Log.AssertEqual("B1.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(d1).Key4);
	Utils.Log.AssertEqual("B2.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(d2).Key3);
	Utils.Log.AssertEqual("B2.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(d2).Key4);

	Dump(s._ChildParameters);

	--Part 3. Use children.
	local t1 = Gui.new("Text");
	t1.Scaled = true;
	t1.Text = "j";
	t1.Color = Color3.new(1, 0, 0);
	t1.LayoutParams = {Role = "A"};
	t1.Name = "TextA";
	local t2 = Gui.new("Text");
	t2.Scaled = true;
	t2.Text = "i";
	t2.Color = Color3.new(0, 1, 0);
	t2.LayoutParams = {Role = "B"};
	t2.Name = "TextB";

	t1.Parent = s;
	t2.Parent = s;

	local a = s._ChildParameters:GetChildOfRole("A");
	local b1 = s._ChildParameters:GetChildOfRole("B", 1);
	local b2 = s._ChildParameters:GetChildOfRole("B", 2);
	a.Name = a.Name .. "_1";
	b1.Name = b1.Name .. "_1";
	b2.Name = b2.Name .. "_2";

	Dump(s._ChildParameters);

	Utils.Log.AssertEqual("B1.AbsoluteSize", Vector2.new(30, 100), b1.AbsoluteSize);
	Utils.Log.AssertEqual("A.AbsoluteSize", Vector2.new(30, 100), a.AbsoluteSize);
	Utils.Log.AssertEqual("B2.AbsoluteSize", Vector2.new(30, 100), b2.AbsoluteSize);
	Utils.Log.AssertEqual("B1.AbsolutePosition", Vector2.new(5, 5), b1.AbsolutePosition);
	Utils.Log.AssertEqual("A.AbsolutePosition", Vector2.new(40, 5), a.AbsolutePosition);
	Utils.Log.AssertEqual("B2.AbsolutePosition", Vector2.new(75, 5), b2.AbsolutePosition);
	Utils.Log.AssertEqual("B1.Parent", s, b1.Parent);
	Utils.Log.AssertEqual("A.Parent", s, a.Parent);
	Utils.Log.AssertEqual("B2.Parent", s, b2.Parent);
	Utils.Log.AssertEqual("A.LayoutParams.Key1", "foo", s._ChildParameters:GetChildLayoutParams(a).Key1);
	Utils.Log.AssertEqual("A.LayoutParams.Key2", "bar", s._ChildParameters:GetChildLayoutParams(a).Key2);
	Utils.Log.AssertEqual("B1.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(b1).Key3);
	Utils.Log.AssertEqual("B1.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(b1).Key4);
	Utils.Log.AssertEqual("B2.LayoutParams.Key3", "hello", s._ChildParameters:GetChildLayoutParams(b2).Key3);
	Utils.Log.AssertEqual("B2.LayoutParams.Key4", "world", s._ChildParameters:GetChildLayoutParams(b2).Key4);

	t1.Parent = nil;
	t2.Parent = nil;

	local a = s._ChildParameters:GetChildOfRole("A");
	local b1 = s._ChildParameters:GetChildOfRole("B", 1);
	local b2 = s._ChildParameters:GetChildOfRole("B", 2);
	a.Name = a.Name .. "_1";
	b1.Name = b1.Name .. "_1";
	b2.Name = b2.Name .. "_2";

	Dump(s._ChildParameters);
	s._ChildParameters.Defaults = nil;

	Dump(s._ChildParameters);
end

function Gui.Test.SpecializedLayout_Wildcard(sgui, cgui)
	local s = SpecializedLayout.new();
	s.Parent = sgui;
	s._ChildParameters.Schema = {
		['*'] = {
			Type = "Many";
			LayoutParams = {
				foo = 'bar';
			};
			Default = Gui.Create "Rectangle" {
				Color = Utils.Math.HexColor(0xAABBCC);
			};
		};
		DefaultRole = "Lolno";
	};
	s._ChildParameters:SetRoleCount("Test", 1);
	local x = s._ChildParameters:GetChildOfRole("Test", 1);
	Utils.Log.AssertNonNilAndType("GetChildOfRole('Test', 1)", "table", x);
	Utils.Log.AssertEqual("GetChildOfRole('Test', 1).Color", x.Color, s._ChildParameters.Schema['*'].Default.Color);
	local l1 = x.LayoutParams;
	local l2 = s._ChildParameters:GetRoleLayoutParams('Test');
	Utils.Log.AssertEqual("GetRoleLayoutParams('Test')", l1.foo, l2.foo);
	Utils.Log.AssertEqual("GetRoleLayoutParams('Test')", l1.Role, l2.Role);
end

function Gui.Test.SpecializedLayout_Clone(sgui, cgui)
	local r = Gui.Create "Rectangle" {};
	local s = SpecializedLayout.new();
	s.Parent = r;
	s._ChildParameters.Schema = {
		Many = { Type = "Many"; LayoutParams = {}; Default = Gui.Create "Rectangle" {}; };
	};
	s._ChildParameters:SetRoleCount("Many", 3);
	Utils.Log.AssertEqual("Number of children", 3, #s:GetChildren());
	Utils.Log.AssertEqual("Number of children", 3, #r:_GetRbxHandle():GetChildren());
	local t = r:Clone();
	Utils.Log.AssertEqual("Number of children", 3, #t:_GetRbxHandle():GetChildren());
	Utils.Log.AssertEqual("Number of children", 3, #s:GetChildren());
	Utils.Log.AssertEqual("Number of children", 3, #r:_GetRbxHandle():GetChildren());
end

return SpecializedLayout;
