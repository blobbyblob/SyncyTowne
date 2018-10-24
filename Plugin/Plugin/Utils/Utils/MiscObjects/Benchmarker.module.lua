--[[

Benchmarker: used for recording how long sections of code take.

To use: create a new benchmarker with:
	local b = Benchmarker.new();
When a new section of the code is starting, indicate by writing:
	b:Mark("mySectionName");
When you're done placing timers in the code, report the output with:
	b:End()
This will dump messages into the output.

Dependencies:
	script.Parent.Class
	script.Parent.Log

To Do:
	- Create public interface for editing properties
	- Allow creating timing regions which aren't reported.
	- Report averages for sections that run multiple times.
		- Limit the number of raw times to 20; after that, ONLY report averages.
		- If there are fewer than 20 raw times but there are duplicates, report raw times first, then averages.

--]]

local Utils = require(script.Parent.Parent);

local Debug = Utils.new("Log", "Benchmark:\t", true);

local Benchmarker = Utils.new("Class", "Benchmarker");

Benchmarker._LogStream = Debug;
Benchmarker._PrintAtEnd = true;
Benchmarker._Times = {};
Benchmarker._Names = {};
Benchmarker._LastTime = false;

Benchmarker.Set.LogStream = "_LogStream";
Benchmarker.Get.LogStream = "_LogStream";

function Benchmarker:_ReportLast()
	local i = #self._Times;
	if i==0 then
		return;
	end
	local runtime = self._Times[i];
	self._LogStream("Segment: %s; Name: %s; Runtime: %s ms", i, self._Names[i], 1000*runtime);
end

--[[ @brief Indicates that a distinct region with a given name is about to start.
--]]
function Benchmarker:Mark(name)
	local t = tick();
	if self._LastTime then
		table.insert(self._Times, t - self._LastTime);
	end
	table.insert(self._Names, name);
	if not self._PrintAtEnd then
		self:_ReportLast();
	end
	self._LastTime = tick();
end

--[[ @brief Indicates that all timed sections are done.
--]]
function Benchmarker:End()
	local t = tick();
	if self._LastTime then
		table.insert(self._Times, t - self._LastTime);
	end
	if self._PrintAtEnd then
		self._LogStream("%s\t%s\t%s", "section", "name", "runtime (ms)");
		for i = 1, #self._Times do
			self._LogStream("%s\t%s\t%s", i, self._Names[i], 1000*self._Times[i]);
		end
	else
		self:_ReportLast();
	end
	self._Times = {};
	self._Names = {};
	self._LastTime = false;
end

function Benchmarker.new()
	local self = setmetatable({}, Benchmarker.Meta);
	self._Times = {};
	self._Names = {};
	return self;
end

return Benchmarker;
