local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];
local View = require(script.Parent.View);
local Test = Gui.Test;
local InterpretExpression = require(script.ExpressionParse).Parse;

--A text input box which only allows for numeric input. Expressions may be input.

local NumberInput = Utils.new("Class", "NumberInput", View);
local Super = NumberInput.Super;

------------------
-- Properties --
------------------

NumberInput._Input = false;
NumberInput._ChildPlacements = false;
NumberInput._Value = 0;


-------------------------
-- Getters/Setters --
-------------------------

--Value: the numerical value of the textbox.
function NumberInput.Set:Value(v)
	self._Input.Text = tostring(v);
	if self._Value ~= v then
		self._Value = v;
		self._Changed:Fire("Value");
	end
end
NumberInput.Get.Value = "_Value";

-----------------------------------------------------------------------------------------------------------------
-- The following functions are routine declarations for a class which wraps another class --
-----------------------------------------------------------------------------------------------------------------

function NumberInput:_GetHandle()
	return self._Input:_GetHandle();
end

function NumberInput.Set:Parent(v)
	self._Input.ParentNoNotify = v;
	Super.Set.Parent(self, v);
end

function NumberInput.Set:ParentNoNotify(v)
	self._Input.ParentNoNotify = v;
	Super.Set.ParentNoNotify(self, v);
end

function NumberInput:_GetChildContainer(child)
	return self._Input:_GetChildContainer(child);
end

function NumberInput:_Reflow(pos, size)
	self._Input:_SetPPos(pos);
	self._Input:_SetPSize(size);
end

function NumberInput:_AddChild(v)
	self._ChildPlacements:AddChildTo(v, self._Input);
	Super._AddChild(self, v);
end

function NumberInput:_RemoveChild(v)
	self._ChildPlacements:RemoveChild(v);
	Super._RemoveChild(self, v);
end

function NumberInput:ForceReflow()
	Super.ForceReflow(self);
	self._Input:ForceReflow();
end

--Instantiate & return a new NumberInput.
function NumberInput.new()
	local self = setmetatable(Super.new(), NumberInput.Meta);
	self._ChildPlacements = Gui.ChildPlacements();
	self._Input = Gui.new("TextBox");
	self._Input.FocusLost:connect(function(enterPressed)
		local val, err = InterpretExpression(self._Input.Text);
		if not val then
			Log.Warn("%s", err);
			self.Value = self.Value;
		else
			self.Value = val;
		end
	end)
	self.Value = self.Value;
	return self;
end

------------
-- Tests --
------------

function Test.NumberInput_ExprDecode()
	Log.AssertEqual("5*2", 10, InterpretExpression("5*2"));
	Log.AssertEqual("5*2+10", 20, InterpretExpression("5*2+10"));
	Log.AssertEqual("10+5*2", 20, InterpretExpression("10+5*2"));
	Log.AssertEqual("-500 + 2^3^2", 12, InterpretExpression("-500 + 2^3^2"));
	Log.AssertEqual("cos 0", 1, InterpretExpression("cos 0"));
	Log.AssertEqual("5 x cos 0", 5, InterpretExpression("5 x cos 0", {x = 1}));
	Log.AssertEqual("5x cos(0)", 5, InterpretExpression("5x cos(0)", {x=1}));
	local x, y, z = InterpretExpression("1, 2, 3", {});
	Log.AssertEqual("1", 1, x);
	Log.AssertEqual("2", 2, y);
	Log.AssertEqual("3", 3, z);
end

function Test.NumberInput_Changed()
	local ValueChanged = 0;
	local function onChanged(property)
		if property=="Value" then
			ValueChanged = ValueChanged + 1;
		end
	end
	local ni = Gui.new("NumberInput");
	ni.Changed:connect(onChanged);
	ni.Value = 1;
	Log.AssertEqual("number of Changed events", 1, ValueChanged);
	Log.AssertEqual("Value", 1, ni.Value);
	ni.Value = 0;
	Log.AssertEqual("number of Changed events", 2, ValueChanged);
	Log.AssertEqual("Value", 0, ni.Value);
end


return NumberInput;
