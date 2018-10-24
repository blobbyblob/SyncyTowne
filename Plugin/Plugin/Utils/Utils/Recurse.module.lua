local HelpDocs = {
	Map = [[
Applies an operation to all elements in a hierarchy.
	Map(root, fn): calls function fn(instance) for root & all of root's descendants.
]];
	Get = [[
Returns a table containing all elements in a hierarchy.
	Get(root)
]];
};

local RecurseLib = setmetatable({}, {});
getmetatable(RecurseLib).__call = function(self, ...) return RecurseLib.Get(...); end

function RecurseLib.Get(root, t)
	t = t or {};
	table.insert(t, root);
	for i, v in pairs(root:GetChildren()) do
		RecurseLib.Get(v, t);
	end
	return t;
end
function RecurseLib.Get(root)
	local t = {root};
	local i = 1;
	while i <= #t do
		for j, v in pairs(t[i]:GetChildren()) do
			table.insert(t, v);
		end
		i = i + 1;
	end
	return t;
end

--[[ @brief Recursively descends through root using :GetChildren().
     @param root An element with children that can be accessed through :GetChildren().
     @param fn A function which is passed an element (root, its children, etc.) and returns true if we should stop descending.
--]]
function RecurseLib.Map(root, fn)
	for i, v in pairs(RecurseLib.Get(root)) do
		fn(v);
	end
end
function RecurseLib.Map(root, fn)
	local t = {root};
	local i = 1;
	while i <= #t do
		if not fn(t[i]) then
			for j, v in pairs(t[i]:GetChildren()) do
				table.insert(t, v);
			end
		end
		i = i + 1;
	end
end

return RecurseLib;
