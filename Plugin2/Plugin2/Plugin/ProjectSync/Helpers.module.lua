local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "Helpers: ", true);

local module = {}

module.SUFFIXES = {
	ModuleScript = ".module.lua";
	LocalScript = ".client.lua";
	Script = ".server.lua";
};

--[[ @brief Converts a path into directory & filename.
	@param path The path to split up.
	@return path The path to the directory containing the file.
	@return filename The name of the file.
--]]
function module.SplitFilePath(path)
	local lastSlash = string.find(path, "/[^/]+$")
	local dir, filename;
	if lastSlash then
		dir = string.sub(path, 1, lastSlash - 1);
		filename = string.sub(path, lastSlash + 1)
	else
		dir, filename = "", path;
	end
	Debug("SplitFilePath: %s, %s", dir, filename);
	return dir, filename;
end

--[[ @brief The first part of the path will be chopped off as long as it matches `root`.
	@param path The path to clean up.
	@param root The part to remove.
	@return The path minus the root prefix.
--]]
function module.RemoveRoot(path, root)
	Utils.Log.Assert(path:sub(1, #root) == root, "Path %s does not start with root %s", path, root);
	return path:sub(#root + 2);
end

function module.Hash(obj)
	return tostring(string.len(obj.Source));
end

function module.GetSuffix(filename)
	for i, v in pairs(module.SUFFIXES) do
		if filename:sub(-#v) == v then
			return i, filename:sub(1, -#v - 1);
		end
	end
end

return module
