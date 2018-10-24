--[[

Sorts a list of strings lexicographically with the exception of natural numbers which are sorted numerically.

E.g.,

foo1
foo2
foo12

foo
foo
foo1
foo2
foo2bar
foo12
foobar

--]]

local Utils = require(script.Parent.Parent);

--Compares two tables for equality starting from index 2.
--1. If one of the tables doesn't have an index, it is "less" than the other.
--1. Fewer tokens is "less".
--2. Numbers and strings compare to their own types directly; if they are equal, move to the next token.
--3. A number is "less" than a string.
local function tableCompare(a, b)
	--Compare foo < foo0
	for i = 2, #b do
		if not a[i] then
			--In the case that one has more elements than the other, the one without the element is "less".
			return true;
		elseif not b[i] then
			return false;
		elseif type(a[i]) == type(b[i]) then
			--Compare string to string & number to number directly.
			if a[i] < b[i] then
				return true;
			elseif b[i] < a[i] then
				return false;
			end
		elseif type(a[i]) == "number" then
			--If we are comparing number to string, the number is less.
			return true;
		else
			return false;
		end
	end
	return false;
end

return function(list)
	--Break each element into its alphabetical and numeric tokens.
	local t = {};
	for i, v in pairs(list) do
		local s = {v};
		for str, num in v:gmatch("([^0-9]*)([0-9]*)") do
			num = tonumber(num);
			if str ~= "" then
				table.insert(s, str);
			end
			if num ~= nil then
				table.insert(s, num);
			end
		end
		table.insert(t, s);
	end

	--Sort the table using the above function which uses the rules:
	table.sort(t, tableCompare);

	--Get the original input back.
	for i, v in pairs(t) do
		t[i] = v[1];
	end
	return t;
end
