--[[

This library explores a new way to organize data.
Notable changes:
	1. The roblox frame will be the primary handle for most objects.
	2. We won't make substitutes for what's typically a roblox object's job. E.g., displaying text.

--]]

local Utils = require(script.Parent);

local Classes = {};
local Libraries = {};
for i, v in pairs(script:GetChildren()) do
	Libraries[v.Name] = v.Name;
	if v.Name ~= "Module" then
		Classes[v.Name] = v.Name;
	end
end

--Gui itself can be indexed to access the individual classes. E.g., Gui.Instance.new will instantiate a new "instance" type.
local Gui = Utils.new("LibraryLoader");
Gui.Submodules = Libraries;
Gui.SearchDirectory = script;

Gui.Enum = Utils.new("EnumContainer");
Gui.Enum:newEnumClass("Gravity", "TopLeft", "Top", "TopRight", "Left", "Center", "Right", "BottomLeft", "Bottom", "BottomRight");

--Gui.new can create new classes of underlying types, e.g., Gui.new("Instance") will create a new instance of type "Instance".
Gui.new = Utils.new("ConstructorLoader");
Gui.new.SearchDirectory = script;
Gui.new.Classes = Classes;
local PROPERTIES = {"CFrame", "Parent"};
local PROPERTIES_MAP = Utils.Table.ConvertArrayToMap(PROPERTIES);
function Gui.Create(class)
	return function(t)
		local x = Gui.new(class);
		for i, v in pairs(t) do
			if type(i) == 'number' then
				v.Parent = x;
			elseif i ~= "Parent" and i ~= "CFrame" then
				x[i] = v;
			end
		end
		for i, prop in pairs(PROPERTIES) do
			if t[prop] then
				x[prop] = t[prop];
			end
		end
		return x;
	end
end

--Gui.Test is a functor which can be invoked to test all underlying gui classes. This may take some time to run.
Gui.Test = Utils.new("TestRegistry");
function Gui.Test.BetweenFunction(testName)
	game.StarterGui:ClearAllChildren();
	local sgui = Instance.new("ScreenGui");
	sgui.Name = "StarterGui:" .. testName;
	local cgui = Instance.new("ScreenGui");
	cgui.Name = "CoreGui:" .. testName;
	local cxn;
	cxn = sgui.Changed:connect(function()
		if not sgui:IsDescendantOf(game) then
			cxn:disconnect();
			cgui:Destroy();
			sgui:Destroy();
		end
	end)
	sgui.Parent = game.StarterGui;
	cgui.Parent = game.CoreGui;
	return sgui, cgui;
end
function Gui.Test.Init()
	for i, v in pairs(script:GetChildren()) do
		require(v);
	end
end

Gui.Map = {};

function Gui.RealAbsolutePosition(gui)
	local sgui = gui;
	while sgui and not sgui:IsA("LayerCollector") do
		sgui = sgui.Parent;
	end
	if sgui and sgui:IsA("ScreenGui") then
		local diff = workspace.CurrentCamera.ViewportSize.Y - sgui.AbsoluteSize.y;
		return gui.AbsolutePosition + Vector2.new(0, diff);
	end
	return gui.AbsolutePosition;
end

return Gui;
