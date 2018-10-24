--[[

This script will build a Gui from a hierarchy of typenames, properties, etc.

An element in the hierarchy should look as follows:

Name (StringValue) with Value = Type
	"Properties" (Folder)
		PropertyName (*Value) with Value = PropertyValue.
		PropertyName (ModuleScript) which returns PropertyValue when 'require'd.
		PropertyName.."()" (ModuleScript) which returns PropertyValue when 'require'd and called.
		PropertyName (Folder) which allows table structures.
			Key (*Value) with Value = Value.
	<Children go here>

Name and PropertyName can be anything. The folder "Properties" is the only name-sensitive element.

--]]

local lib = script.Parent.Parent;
local Log = require(lib.Log);

--[[ @brief Returns the folder of properties for element e.
     @param e The hierarchy element. This may contain a folder named "Properties".
     @return A folder containing property-value pairs.
--]]
local function GetPropertiesFolder(e)
	--Step 1: Use FindFirstChild as a shortcut to the "Properties" child.
	if e:FindFirstChild("Properties") then
		local v = e.Properties;
		if v.ClassName == "Folder" or v.ClassName == "Configuration" then
			return v;
		else
			--Step 2: If FindFirstChild didn't lead to a folder, there might be another element with the same name which IS a folder.
			for i, v in pairs(e:GetChildren()) do
				if v.Name == "Properties" and (v.ClassName == "Folder" or v.ClassName == "Configuration") then
					return v;
				end
			end
			return v;
		end
	end
	Log.Warn(3, "No \"Properties\" folder found within %s", e);
	--Step 3: If neither of the attempts succeeded, return an empty folder.
	return Instance.new("Folder");
end

--[[ @brief Returns a table containing all key-value pairs within folder.
     @param folder A folder containing key-value pairs.
     @return A table containing key-value pairs corresponding to that within folder.
--]]
local function GetProperties(folder)
	local t = {};
	for i, v in pairs(folder:GetChildren()) do
		local key, value;
		if v:IsA("ModuleScript") then
			if v.Name:sub(#v.Name - 1) == "()" then
				key = v.Name:sub(1, #v.Name - 2);
				value = require(v)();
			else
				key = v.Name;
				value = require(v);
			end
		elseif v:IsA("Folder") or v:IsA("Configuration") then
			key = v.Name;
			value = GetProperties(v);
		else
			key = v.Name;
			value = v.Value;
		end
		t[key] = value;
	end
	return t;
end

local Gui = _G[script.Parent];

function Traverse(Element)
	local class = Element.Value;
	local gui = Gui.new(class);
	gui.Name = Element.Name;
	local PropertiesFolder = GetPropertiesFolder(Element);
	for key, value in pairs(GetProperties(PropertiesFolder)) do
		gui[key] = value;
	end
	for i, v in pairs(Element:GetChildren()) do
		if v.ClassName == "StringValue" then
			Traverse(v).Parent = gui;
		end
	end
	return gui;
end

--[[ @brief Returns a hierarchy of Gui instances based on a tree of roblox instances.
     @details A StringValue denotes an instance with the name being the instance's name, and the
         value being the instance's class. It should have a child of class "Folder" or "Configuration"
         which is named "Properties". Inside that folder are the key-value pairs which will be
         assigned to the instance. A property can be a *Value object, in which case the property's
         value will match the object's value. It can be a folder, in which case the property's value
         will be a table which contains key-value pairs (same rules apply to nested tables).
         Finally, it can be a module script, in which case the module script will be "require"d, and
         its return value will be the property value. If the name of the module script ends in "()",
         the property value will be require(moduleScript)().
     @param tree The topmost StringValue in the hierarchy.
--]]
function Gui.FromTree(tree)
	return Traverse(tree);
end

return nil;

