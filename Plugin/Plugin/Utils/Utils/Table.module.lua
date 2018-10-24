local Utils = require(script.Parent);

local module = {}

--[[ @brief Packs a table so that no gaps exist.
     @param t The table to pack.
     @param maxn The highest index (obtained by table.maxn if nil).
--]]
function module.CloseGaps(t, maxn)
	if not maxn then maxn = table.maxn(t); end
	local j = 1;
	for i = 1, maxn do
		if t[i] ~= nil then
			if i > j then
				t[j] = t[i];
				t[i] = nil;
			end
			j = j + 1;
		end
	end
end

--[[ @brief Produces a cumulative sum along a table.
     @details The passed-in table will be mutated.
     @example Accumulate({1, 2, 3}) = {1, 3, 6}.
     @param t The table to accumulate.
--]]
function module.Accumulate(t)
	local s = 0;
	for i, v in pairs(t) do
		s = s + t[i];
		t[i] = s;
	end
	return t;
end

--[[ @brief Sums all elements in a table.
     @param t A table of numbers.
     @return The total sum of all numbers in t.
--]]
function module.Sum(t, n)
	local sum = 0;
	if n then
		for i = 1, n do
			sum = sum + t[i>#t and #t or i] or 0;
		end
	else
		for i, v in pairs(t) do
			sum = sum + v;
		end
	end
	return sum;
end

--[[ @brief Proportionally modifies all numbers in an array so the sum is 1.
     @example Normalize({1, 2, 3}) = {1/6, 2/6, 3/6};
     @param t The array to normalize.
     @return t The normalized array. This will be the same as t.
--]]
function module.Normalize(t)
	local sum = module.Sum(t);
	if sum~=0 then
		for i, v in pairs(t) do
			t[i] = v/sum;
		end
	end
	return t;
end

--[[ @brief Adds the same value to all numbers in an array so the sum is 0.
     @example AdditiveNormalize({5, 10, 15}) = {-5, 0, 5}
     @param t The array to normalize.
     @return The normalized array.
--]]
function module.AdditiveNormalize(t)
	local offset = module.Sum(t) / #t;
	for i, v in pairs(t) do
		t[i] = v - offset;
	end
	return t;
end

--[[ @brief Normalizes an array using the 1 norm. The satellite array will be multiplied by the same normalizing factor.
     @param array The array to normalize.
--]]
function module.NormalizeArrayWithSatellite(array, satellite)
	local sum = module.Sum(array);
	if sum==0 then return; end
	for i = 1, #array do
		array[i] = array[i] / sum;
	end
	for i = 1, #satellite do
		satellite[i] = satellite[i] / sum;
	end
end

--[[ @brief Copies a table.
     @param t The table to copy.
     @return The copied table.
--]]
function module.ShallowTableCopy(t)
	local s = {};
	for i, v in pairs(t) do
		s[i] = v;
	end
	return s;
end

function module.ArrayCopyOnCondition(t, c)
	local s = {};
	for i, v in pairs(t) do
		if c(v) then
			table.insert(s, v);
		end
	end
	return s;
end

module.ShallowCopy = module.ShallowTableCopy;

--[[ @brief Returns the number of entries in a given table.
--]]
function module.CountMapEntries(t)
	local n = 0;
	for i in pairs(t) do
		n = n + 1;
	end
	return n;
end

module.newLayeredTable = require(script.LayeredTable).new;
module.newReadOnlyWrapper = require(script.ReadOnlyWrapper).new;

function module.AddTableToTable(t1, t2)
	local output = {};
	for i, v in pairs(t1) do
		output[i] = v + t2[i];
	end
	return output;
end
function module.AddNumberToTable(n, t)
	local output = {};
	for i, v in pairs(t) do
		output[i] = v + n;
	end
	return output;
end
function module.Add(...)
	local AddQueue = {...};
	--Peel off the last two elements and add them.
	for i = #AddQueue - 1, 1, -1 do
		local a = AddQueue[i + 1];
		local b = AddQueue[i];
		if type(a) == 'table' then
			if type(b) == 'table' then
				AddQueue[i] = module.AddTableToTable(a, b);
			else
				AddQueue[i] = module.AddNumberToTable(b, a);
			end
		else
			if type(b) == 'table' then
				AddQueue[i] = module.AddNumberToTable(a, b);
			else
				AddQueue[i] = a * b;
			end
		end
	end
	return AddQueue[1];
end

function module.MultiplyTableByTable(t1, t2)
	local output = {};
	for i = 1, #t1 do
		output[i] = t1[i] * t2[i];
	end
	return output;
end
function module.MultiplyNumberByTable(n, t)
	local output = {};
	for i = 1, #t do
		output[i] = t[i] * n;
	end
	return output;
end
function module.Multiply(t1, t2)
	if type(t1) == 'table' then
		if type(t2) == 'number' then
			return module.MultiplyNumberByTable(t2, t1);
		elseif type(t2) == 'table' then
			return module.MultiplyTableByTable(t1, t2);
		else
			Utils.Log.AssertNonNilAndType("argument 2", "table or number", t2);
		end
	elseif type(t1) == 'number' then
		if type(t2) == 'table' then
			return module.MultiplyNumberByTable(t1, t2);
		else
			Utils.Log.AssertNonNilAndType("argument 2", "table", t2);
		end
	end
end

local function rawRange(start, stop, step)
	local output = {};
	if step > 0 then
		local i = start;
		while i < stop do
			output[#output + 1] = i;
			i = i + step;
		end
	elseif step < 0 then
		local i = start;
		while i > stop do
			output[#output + 1] = i;
			i = i + step;
		end
	end
	return output;
end
function module.Range(start, stop, step)
	if start and stop and step then
		return rawRange(start, stop, step);
	elseif start and stop then
		return rawRange(start, stop, 1);
	elseif start then
		return rawRange(0, start, 1);
	else
		return {};
	end
end

function module.RangeInclusive(start, stop, step)
	return module.Range(start, stop + step/2, step);
end

--[[ @brief Pulls all key-value pairs from 'draw' so long as they don't already exist in 'origin'.
     @param origin The table to modify (this is in-place).
     @param draw The table to pull into 'origin'.
     @return A reference to 'origin'. It will have all keys defined which are defined in origin or draw.
--]]
function module.Incorporate(origin, draw)
	for i, v in pairs(draw) do
		if origin[i] == nil then
			origin[i] = v;
		end
	end
	return origin;
end

function module.StableSort(t, compare)
	for i = 1, #t do
		local j = 1;
		while j < i and not compare(t[i], t[j]) do
			j = j + 1;
		end
		for k = i - 1, j, -1 do
			t[k], t[k+1] = t[k+1], t[k];
		end
	end
end

function module.ConvertArrayToMap(t)
	local s = {};
	for i = 1, #t do
		s[t[i]] = true;
	end
	return s;
end

--[[ @brief Performs an operation on every element in a table.
     @param t The table which we perform operations on.
     @param f The function to perform.
     @return A new table with all the indices of t and values of f(t[i]).
--]]
function module.Map(t, f)
	local s = {};
	for i, v in pairs(t) do
		s[i] = f(v);
	end
	return s;
end

--[[ @brief Creates a table with only the elements from t that pass a test.
     @param t The table to filter.
     @param f The test to apply. This function should return truthy/falsy.
     @return A table with the filter applied.
--]]
function module.Filter(t, f)
	local s = {};
	for i, v in pairs(t) do
		if f(v) then
			s[i] = v;
		end
	end
	return s;
end

--[[ @brief Returns the first element which meets some criterion.
--]]
function module.Find(t, f)
	for i, v in pairs(t) do
		if f(v) then
			return v;
		end
	end
end

return module
