local module = {}

--@brief Returns the greatest index whose value is still less than v.
--@param t The table to search (must be sorted).
--@param v The value to search for.
--@return i The last index less than v. Note: if everything in t is greater than v, this will be 0.
function module.Search(t, v)
	for i = 1, #t do
		if v < t[i] then
			return i - 1;
		end
	end
	return #t;
end

return module
