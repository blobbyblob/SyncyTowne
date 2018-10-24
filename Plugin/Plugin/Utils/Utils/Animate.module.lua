local Utils = require(script.Parent);

local HelpDocs = {

};

local AnimateLib = setmetatable({}, {});
getmetatable(AnimateLib).__call = function(...) return AnimateLib.Get(...); end

function AnimateLib.GripTool(model, tool)
	--TODO: Moves a tool into a model and CFrames it such that the character appears to be holding it.
	
end

function AnimateLib.SimulateAnimation(model, keyframesAndSuch)
	--TODO: animate the model by CFraming its parts around.
end

--TODO: add a parameter that instead welds the tool to the HumanoidRootPart.
function AnimateLib.Motor6DFromGrip(tool, rightArm)
	local m = Instance.new("Motor6D");
	m.C0 = CFrame.new(0, -1, 0, 1, 0, -0, 0, 0, 1, 0, -1, 0);
	m.C1 = Utils.Math.CFrameFromComponents(tool.GripPos, tool.GripRight, tool.GripUp, -tool.GripForward);
	m.Part0 = rightArm;
	m.Part1 = tool:FindFirstChild('Handle');
	m.Parent = rightArm;
	m.Name = "RightGrip";
	return m;
end

--[[ @brief Performs an operation on heartbeat based on a condition.
     @param callback The callback function for each heartbeat step.
     @param condition The condition we should check before running callback.
     @param yield Whether this function should yield or return immediately.
--]]
function AnimateLib.ConditionalOnHeartbeat(callback, condition, yield, callbackOnComplete)
	local cxn;
	local event = Utils.new("Event");
	local startTime = tick();
	cxn = game:GetService("RunService").Heartbeat:connect(function(step)
		if condition() then
			callback(step, tick() - startTime)
		else
			cxn:disconnect();
			event:Fire();
			if callbackOnComplete then
				callbackOnComplete();
			end
		end
	end);
	if yield then
		event:wait();
	end
end

--[[ @brief Performs an operation on heartbeat for a set amount of time.
     @details This fills a common need for animating things smoothly, esp. GUIs. Expect things animated through this function to be smoother than things animated on a while loop.
     @param fn The callback function for each heartbeat step.
     @param lengthOfTime The length of time which we should continually call the callback.
     @param yield Whether this function should yield or return immediately.
--]]
function AnimateLib.TemporaryOnHeartbeat(fn, lengthOfTime, yield, callback)
	local function PerfectDT(dt)
		if lengthOfTime > dt then
			lengthOfTime = lengthOfTime - dt;
			fn(dt);
		else
			local t = lengthOfTime;
			lengthOfTime = 0;
			fn(t);
		end
	end
	local function Condition()
		return lengthOfTime > 0;
	end
	return AnimateLib.ConditionalOnHeartbeat(PerfectDT, Condition, yield, callback);
end

return AnimateLib;
