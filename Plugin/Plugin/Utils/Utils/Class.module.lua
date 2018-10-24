--[[ Usage Instructions

The canonical way to require this script is:
	local Class = require(path.to.Class);
Henceforth, references to this class will use the name "Class."

----------------------------
-- Basic Instructions --
----------------------------

To create a new top-level class, use the 'new' method, e.g.:
	local Shape = Class.new("Shape");
The string represents the name of the class. This is primarily useful for debugging.
	print(Shape); --> Shape

To add a default property-value pair, create the index in the class:
	Shape.Position = Vector2.new(0, 0);
To add a method to the class, register it as follows:
	function Shape:GetArea()
		print("GetArea() not defined for " .. self.ClassName);
	end

To instantiate a class, write the following:
	local shapeInstance = setmetatable({}, Shape.Meta);
At this point, you may perform operations such as:
	print(shapeInstance.Position); --> 0, 0
	print(shapeInstance.ClassName); --> Shape
	print(shapeInstance:IsA("Shape")); --> true
	shapeInstance:GetArea(); --> GetArea() not defined for Shape

The two special keys you get for free are:
	ClassName: the name of the class which this instance belongs to.
	IsA(className): a method which returns true if this instance is
	                a member of the class or one of its subclasses.

-------------------------
-- Getters/Setters --
-------------------------

Sometimes one may want to perform some basic checks when a property is being set. One could do the Java approach as follows:
	function Shape:SetPosition(pos)
		assert(pos.x > 0 and pos.y > 0, "position must be in the positive quadrant");
		self.Position = pos;
	end
	function Shape:GetPosition()
		return self.Position;
	end
Then, changes could be made as follows:
	shapeInstance:SetPosition(Vector2.new(10, 20));
	print(shapeInstance:GetPosition()); --> 10, 20

However, a slightly more Lua-centric approach would be to write/read the property mapping. From the user's perspective, we want to write:
	shapeInstance.Position = Vector2.new(10, 20);
	print(shapeInstance.Position); --> 10, 20
To accomplish this, we need to store the value of "Position" in some other key, e.g., "_Position". We set the default value as:
	Shape._Position = Vector2.new();
We can 'redirect' all sets/gets to the "Position" key as follows:
	Shape.Set.Position = "_Position";
	Shape.Get.Position = "_Position";
Of course, this still doesn't give us verification that the position is in the positive quadrant. So, we can rewrite the "Setter" to verify this as follows:
	function Shape.Set:Position(v)
		assert(pos.x > 0 and pos.y > 0, "position must be in the positive quadrant");
		self._Position = v;
	end

Our complete shape definition is then (for brevity, GetArea was removed):
	local Class = require(path.to.Class);
	local Shape = Class.new("Shape");
	
	Shape._Position = Vector2.new();
	
	function Shape.Set:Position(v)
		assert(pos.x > 0 and pos.y > 0, "position must be in the positive quadrant");
		self._Position = v;
	end
	Shape.Get.Position = "_Position";

	function Shape.new()
		return setmetatable({}, Shape.Meta);
	end
	
	return Shape; --This makes sense in a ModuleScript.

It is used as such:
	local Shape = require(path.to.Shape);
	local shapeInstance = Shape.new();
	shapeInstance.Position = Vector2.new(10, 20);
	print(shapeInstance.Position); --> 10, 20
	shapeInstance.Position = Vector2.new(-10, 20); --> error: position must be in the positive quadrant

A quick follow-up note:
The class framework has special keys "Get" and "Set", but you may decide you want your class to have a function with one of those names. In that case, you can just write over those tables:
	local instance;
	function MySingletonClass:Get()
		if not instance then instance = MySingletonClass.new(); end
		return instance;
	end
If you want a method named "Get" or "Set" and also want to use the Lua-style getters and setters, you can use any case permutation of "get" and "set" or "getop" and "setop", e.g., "GET", "get", "gEt", etc.
	MySingletonClass.GET.Property = "_Property";

--------------------
-- Inheritance --
--------------------
The framework supports single-inheritance. To obtain this feature, use the second argument in the class constructor, e.g.:
	local Square = Class.new("Square", Shape);
We then inherit methods from Shape:
	local squareInstance = setmetatable({}, Square.Meta);
	print(squareInstance.Position); --> 0, 0
	squareInstance.Position = Vector2.new(-10, 20); --> error: position must be in the positive quadrant

For our example, consider a "SideLength" property.
	Square._SideLength = 10;
	function Square.Set:SideLength(v)
		assert(v ~= nil, "side length may not be nil");
		assert(type(v) == "number", "side length must be a number");
		assert(v > 0, "side length must be positive and non-zero");
		self._SideLength = v;
	end
	Square.Get.SideLength = "_SideLength";

Methods can be overridden simply by redefining them:
	function Square:GetArea()
		--Either of the following two lines is acceptable, though the second may be slightly faster. However, it would break the concept of encapsulation if external code tried referencing "_SideLength", so be careful where you use it.
		return self.SideLength * self.SideLength;
		return self._SideLength * self._SideLength;
	end

--]]

local Log = require(script.Parent.Log);
local ClassDebug = Log.new("Class:\t", false);

local CLASS_REFERENCE_KEY = "__Class";

local Class = {};

Class._Class_ClassName = "Custom Class"; --The name for this class (if given). If Class.ClassName is not specified, this will be the value for the "ClassName" index. This is helpful for debugging.
Class._Superclass = nil; --The parent of this class from which we inherit.
Class._PropertyShortcut = true;

--[[ @brief Constructs a metatable for a class.
     @details This function is called externally through Class.Meta.
     @param self The class we are generating for.
     @return A table which may be used as the metatable for instances of this class.
--]]
function GetMetatable(Class)
	local Meta = {};
	local Methods = {};
	Methods[CLASS_REFERENCE_KEY] = Class;
	local Getters = Class._Getters or {};
	local Setters = Class._Setters or {};

	local class = Class;
	while class ~= nil do
		for i, v in pairs(class) do
			if i=="_Getters" then
				for i, v in pairs(v) do
					Getters[i] = Getters[i] or v;
				end
			elseif i=="_Setters" then
				for i, v in pairs(v) do
					Setters[i] = Setters[i] or v;
				end
			elseif i:sub(1, 2)~="__" then
				Methods[i] = Methods[i] or v;
			else
				Meta[i] = Meta[i] or v;
			end
		end
		class = class._Superclass;
	end

	if not Meta.__tostring then
		local name = "Class " .. (Class._Class_ClassName or "unknown");
		Meta.__tostring = function(self) return name; end;
	end
	if not Methods.ClassName then
		Methods.ClassName = Class._Class_ClassName;
	end
	local function isAfunc(self, class)
		local c = Class;
		while c ~= nil do
			if c._Class_ClassName == class then
				return true;
			end
			c = c._Superclass;
		end
		return false;
	end
	if not Methods.IsA then
		Methods.IsA = isAfunc;
	end
	if not Methods.IsAn then
		Methods.IsAn = isAfunc;
	end
	if Meta.__index or next(Getters)~=nil then
		local f = Meta.__index;
		function Meta.__index(self, i)
			ClassDebug("%s.__index(%s, %s) called", Class._Class_ClassName, rawget(self, "_Class_ClassName"), i);
			if Methods[i] ~= nil then
				ClassDebug("    Methods[%s] ~= nil", i);
				return Methods[i];
			elseif Getters[i] then
				if type(Getters[i]) == 'string' then
					ClassDebug("    Getters[%s] = 'string'", i);
					return self[Getters[i]];
				else
					ClassDebug("    Getters[%s] = 'function'", i);
					return Getters[i](self, i);
				end
			elseif f then
				ClassDebug("    Calling __index(%s, %s)", rawget(self, "_Class_ClassName"), i);
				return f(self, i);
			else
				ClassDebug("    failed.");
				return nil;
			end
		end
	else
		Meta.__index = Methods;
	end
	local f = Meta.__newindex;
	function Meta.__newindex(self, i, v)
		ClassDebug("%s.%s = %s", self, i, v);
		local x = Setters[i];
		if x then
			if type(x) == 'string' then
				rawset(self, x, v);
			else
				return x(self, v, i);
			end
		elseif Methods[i]~=nil then
			rawset(self, i, v);
		elseif f then
			return f(self, i, v);
		else
			Log.Warn(2, "Attempting to write to unknown key; %s[%s] = %s", self, i, v);
			rawset(self, i, v);
		end
	end
	Meta.__Class = Class;
	return Meta;
end

--[[ @brief Returns special keys or existing default values/methods.
     @details Special keys include:
         Meta: the metatable for this class.
         Super: the superclass associated with this class.
         Get: a table of getter functions/mappings.
         Set: a table of setter functions/mappings.
         Additionally, if an index was created before, it will be returned on index. This includes indices created by superclasses.
     @param i The index to search for.
     @return The value for i.
--]]
function Class:__index(i)
	if i=="Meta" then
		local Meta = GetMetatable(self);
		rawset(self, i, Meta);
		return Meta;
	elseif i=="Name" then
		return self._Class_ClassName;
	elseif i=="Super" then
		return self._Superclass;
	else
		--Crawl up the inheritance hierarchy looking for this member.
		local class = rawget(self, '_Superclass');
		while class~=nil and rawget(class, i)==nil do
			class = rawget(class, '_Superclass');
		end
		if class ~= nil then
			return rawget(class, i);
		end
		
		--If that didn't work, check some of the lower-priority keys.
		if type(i)=='string' then
			if i:lower()=="get" or i:lower()=="getop" then
				return self._Getters;
			elseif i:lower()=="set" or i:lower()=="setop" then
				return self._Setters;
			end
		end
	end
end

--[[ @brief Returns a name for this class.
     @details A class can be ascribed a name on creation to allow for better debugging.
     @return A string describing this class.
--]]
function Class:__tostring()
	return self._Class_ClassName;
end

--[[ @brief Creates a class with a given name (type) and superclass.
     @param name All instances of this class will have a ClassName value set to the class name. Additionally, debug output may display this name.
     @param superclass This class will inherit functions from the superclass(es).
--]]
function Class.new(name, superclass)
	local self = setmetatable({}, Class);
	self._Class_ClassName = name;
	self._Superclass = superclass;
 	self._Setters = {};
	self._Getters = {};
	return self;
end

function Class.Test()
	local A = Class.new("Super");
	A.Property = "Value";
	local B = Class.new("Child", A);
	local b = setmetatable({}, B.Meta);
	print(b.Property);
end

return Class;
