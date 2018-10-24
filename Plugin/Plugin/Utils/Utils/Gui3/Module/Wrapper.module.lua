local Utils = require(script.Parent.Parent.Parent);
local Gui = require(script.Parent.Parent);

local Super = Gui.GuiBase2d;
local Wrapper = Utils.new("Class", "Wrapper", Gui.GuiBase2d);

Wrapper._Object = false;

function Wrapper.Set:Object(v)
	self._Object = v;
end
Wrapper.Get.Object = "_Object";

function Wrapper:_Clone(new)
	new._Object = self._Object:Clone();
end

function Wrapper:__newindex(i, v)
	self._Object[i] = v;
end
function Wrapper:__index(i)
	if type(self._Object[i]) == "function" then
		return function(this, ...)
			if this == self then
				return self._Object[i](self._Object, ...);
			end
		end
	else
		return self._Object[i];
	end
end

function Wrapper:_GetRbxHandle()
	return self._Object;
end

function Wrapper.new()
	local self = setmetatable(Super.new(), Wrapper.Meta);
	return self;
end

return Wrapper;
