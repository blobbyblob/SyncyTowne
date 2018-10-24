local Utils = require(game.ReplicatedStorage.Utils);
local Heap = Utils.new("Class", "Heap");

Heap.Comparator = function(a, b) return a < b; end

--[[ @brief Reshuffles the heap if a given index is larger than one of its children.
--]]
function Heap:_HeapifyTopDown(i)
	local l = i * 2;
	local r = l + 1;
	local largest;
	if l <= #self and self.Comparator(self[l], self[i]) then
		largest = l;
	else
		largest = i;
	end
	if r <= #self and self.Comparator(self[r], self[largest]) then
		largest = r;
	end
	if largest ~= i then
		self[i], self[largest] = self[largest], self[i];
		self:_HeapifyTopDown(largest);
	end
end

--[[ @brief Reshuffles the heap if a given index is smaller than its parent.
--]]
function Heap:_HeapifyBottomUp(i)
	local parent = math.floor(i / 2);
	while self[parent] and self.Comparator(self[i], self[parent]) do
		self[parent], self[i] = self[i], self[parent];
		i = parent;
		parent = math.floor(i / 2);
	end
end

--[[ @brief Returns the smallest element in the heap.
     @return The smallest element in the heap (using the stored comparator function).
--]]
function Heap:Top()
	return self[1];
end

--[[ @brief Removes and returns the smallest element on the heap.
     @return The smallest element on the heap (using the stored comparator function).
--]]
function Heap:Pop()
	local v = self[1];
	self[1] = self[#self];
	self[#self] = nil;
	self:_HeapifyTopDown(1);
	return v;
end

--[[ @brief Adds an element to the heap.
     @param element The element to add.
--]]
function Heap:Insert(element)
	rawset(self, #self + 1, element);
	self:_HeapifyBottomUp(#self);
end

--[[ @brief Finds the object in the heap and reduces its value.
     @details Note: this is not an efficient operation. It runs in O(n) time where n is the size of the heap.
--]]
function Heap:HeapifyObject(element)
	for i = 1, #self do
		if self[i] == element then
			self:_HeapifyBottomUp(i);
			break;
		end
	end
end

function Heap.new()
	return setmetatable({}, Heap.Meta);
end

return Heap;
