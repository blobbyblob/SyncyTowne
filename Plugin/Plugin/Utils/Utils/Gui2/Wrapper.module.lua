local Utils = require(script.Parent.Parent);
local Log = Utils.Log;
local Gui = _G[script.Parent];

local Wrapper = Utils.new("Class", "Wrapper", require(script.Parent.View));
local Super = Wrapper.Super;

local InstanceMap = setmetatable({}, {__mode = "k"});

Wrapper._Handle = false;

function Wrapper.Set:Name(v)
	Super.Set.Name(self, v);
	self._Handle.Name = v;
end

--[[ @brief Index writes go straight through to the underlying element.
     @param i The key to write.
     @param v The value to write.
--]]
function Wrapper:__newindex(i, v)
--	Log.Debug("Wrapper.__newindex(%s, %s, %s) called", self, i, v);
	self._Handle[i] = v;
end

--[[ @brief Index reads go straight through to the underlying element.
     @param i The key to read.
--]]
function Wrapper:__index(i)
	return self._Handle[i];
end

--[[ @brief Returns the raw element which this Gui object is wrapping.
     @return The underlying element.
--]]
function Wrapper:_GetHandle()
	return self._Handle;
end

--[[ @brief Passes pos/size through to the children.
     @details This function should only be called if the wrapped element is a ScreenGui. Otherwise, improper positioning will occur.
--]]
function ScreenGuiReflow(self, pos, size)
	Gui.Log.Reflow("Wrapper._Reflow(%s, %s, %s) called", self, pos, size);
	Log.Assert(self._Handle.ClassName=="ScreenGui", "ScreenGuiReflow should only be called if the underlying element is a ScreenGui");
	for i, v in pairs(self:GetChildren()) do
		v:_SetPPos(pos);
		v:_SetPSize(size);
	end
end

function ScreenGuiReflowPre(self)
	local handle = self._Handle;
	self._AbsoluteSize = handle.AbsoluteSize;
	self._AbsolutePosition = handle.AbsolutePosition;
	self:_Reflow(UDim2.new(0, self._AbsolutePosition.x, 0, self._AbsolutePosition.y), UDim2.new(0, self._AbsoluteSize.x, 0, self._AbsoluteSize.y));
end

function Wrapper:_Reflow(pos, size)
	self._Handle.Position = pos;
	self._Handle.Size = size;
	for i, v in pairs(self:GetChildren()) do
		v:_SetPPos(UDim2.new());
		v:_SetPSize(UDim2.new(0, self._Handle.AbsoluteSize.x, 0, self._Handle.AbsoluteSize.y));
	end
end

function Wrapper:Clone()
	return Wrapper.new(self._Handle:Clone());
end

--[[ @brief Wraps an Instance & returns the Gui object.
     @details This function will ensure the proper methods will be attributed to the object. Position/Size will be copied over.
--]]
function Wrapper.new(instance)
	Log.AssertNonNilAndType("Wrapped Object", "userdata", instance);
	if not InstanceMap[instance] then
		local self = setmetatable(Super.new(), Wrapper.Meta);
		self._Handle = instance;
		--If the RBX Instance has a Position/Size, copy them over to the Gui object so they don't get overwritten incorrectly.
		--If it does not have a Position/Size, a special _Reflow function will be provided so that children render correctly.
		if instance:IsA("GuiObject") then
			self.Position = instance.Position;
			self.Size = instance.Size;
		else
			self._Reflow = ScreenGuiReflow;
			self._ReflowPre = ScreenGuiReflowPre;
		end
		--Children will be recursively wrapped.
		for i, v in pairs(instance:GetChildren()) do
			Wrapper.new(v).Parent = self;
		end
		if InstanceMap[instance.Parent] then
			self.Parent = InstanceMap[instance.Parent];
		else
			self.Parent = instance.Parent;
		end
		--This wrapper will be preserved so that two RBX Instances won't map to separate Gui objects.
		InstanceMap[instance] = self;
	end
	return InstanceMap[instance];
end

--Register an instantiation function for each of Frame, ScrollingFrame, TextButton, TextLabel, ImageButton,
--and ScreenGui so that one can write Gui.new("ScreenGui"), etc.
for i, v in pairs({"Frame", "ScrollingFrame", "TextButton", "TextLabel", "TextBox", "ImageButton", "ImageLabel", "ScreenGui"}) do
	local w = Utils.new("Class", v, Wrapper);
	function w.new()
		local x = Instance.new(v);
		if v~="ScreenGui" then
			x.Size = UDim2.new(1, 0, 1, 0);
			x.BorderSizePixel = 0;
		end
		return Wrapper.new(x);
	end
	Gui.Register(w);
end

return Wrapper;