--[[

This library explores a new way to organize data. Notable changes:
	1. Instance and GuiBase2d are two separate components which made up what was once "View".
	2. Layout logic was removed from GuiBase2d and returns in the form of "Modifiers".

To Test:
	require(game.ReplicatedStorage.Utils:Clone()).Gui.Test();

--]]

local Utils = require(script.Parent);

local Classes = {};
for _, class in pairs({"TextBox"}) do
	Classes[class] = {"Module", "Wrapper_"..class};
end

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
		local x;
		if class == "ScreenGui" then
			x = Instance.new("ScreenGui");
		else
			x = Gui.new(class);
		end
		for i, v in pairs(t) do
			if type(i) == 'number' then
				v.Parent = x;
			elseif not PROPERTIES_MAP[i] then
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
	wait();
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
		local success, err = pcall(require, v);
		if not success then
			print("Failure loading " .. v.Name .. ": " .. err);
		end
	end
--	require(script.SpecializedLayout);
end

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
