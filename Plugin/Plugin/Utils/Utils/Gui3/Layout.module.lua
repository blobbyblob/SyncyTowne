local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);
local ChildProperties = require(script.ChildProperties);

local Debug = Utils.new("Log", "Layout: ", true);

local Super = Gui.GuiBase2d;
local Layout = Utils.new("Class", "Layout", Super);

Layout._ChildParameters = ChildProperties.new();

function Layout:_Clone(new)
	new._ChildParameters = self._ChildParameters:Clone();
end

function Layout:_IterateLayoutChildren()
	local function iterate(self, i)
		local i, child = next(self._Children, i);
		if not i then return; end
		if child:IsA("GuiBase2d") then
			return i, child, self._ChildParameters[child];
		else
			return iterate(self, i);
		end
	end
	return iterate, self, nil;
end

function Layout.new()
	local self = setmetatable(Super.new(), Layout.Meta);
	self._ChildParameters = ChildProperties.new();
	return self;
end

local function CompareTables(expected, actual)
	for i, v in pairs(expected) do
		Utils.Log.AssertEqual("key " .. tostring(i), v, actual[i]);
	end
	for i, v in pairs(actual) do
		if expected[i] == nil then
			Utils.Log.AssertEqual("key " .. tostring(i), nil, v);
		end
	end
end
function Gui.Test.ChildParameters()
	local x = ChildProperties.new();
	x:SetDefault("foo", "bar");
	local y = {};
	CompareTables(x[y], {foo='bar'});
	y.LayoutParams = {hello='world'};
	CompareTables(x[y], {foo='bar'});
	x:SetDefault("hello", "kitty");
	CompareTables(x[y], {foo='bar'; hello='world'});
	x:GetWritableParameters(y).hello = 'dolly';
	CompareTables(x[y], {foo='bar'; hello='dolly'});
end

return Layout;
