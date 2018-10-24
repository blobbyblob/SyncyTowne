--[[

Creates & returns an event which fires when an instance is destroyed.

--]]

local Utils = require(script.Parent.Parent);
local Debug = Utils.new("Log", "OnDestroy: ", true);

--You cannot parent things to a destroyed object, so we use this tag. Any time something's
--parented to nil, we attempt to parent this tag to the object, and if we get an error,
--we know it's been destroyed. Otherwise, we de-parent it, and go about our business.
local destroyChecker = Instance.new("Folder");
destroyChecker.Name = "OnDestroy_EventChecker"; --In case we show up in logs somewhere, we have some clue what this is.

function SetParent(obj, parent)
	obj.Parent = parent;
end

--@brief Fires a callback when an object is destroyed.
--@param object The object to watch.
--@param callback The function to fire.
function onDestroy(object, callback)
	return object:GetPropertyChangedSignal("Parent"):connect(function()
		if not object.Parent then
			--We were either, :Remove()d, :Destroy()ed, or .Parent=nil'ed.
			--Figure out if we were /Destroyed/.
			if pcall(SetParent, object, destroyChecker) then
				destroyChecker.Parent = nil;
			else
				callback();
			end
		end
	end)
end

function Test()
	Debug("Testing");
	local obj = Instance.new("BoolValue", workspace);
	Instance.new("BoolValue", obj).Name = "A";
	local destroyCount = 0;
	onDestroy(obj, function()
		Debug("Destroyed");
		destroyCount = destroyCount + 1;
	end);
	local o2 = Instance.new("BoolValue", workspace);
	obj.Parent = nil;
	obj.Parent = o2;
	wait();
	Utils.Log.AssertEqual("DestroyCount", 0, destroyCount);
	o2:Destroy(); --If we destroy some ancestor, this should trickle down.
	wait();
	Utils.Log.AssertEqual("DestroyCount", 1, destroyCount);
end

Test();

return onDestroy;
