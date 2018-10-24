--_G.OpenDirectory(directory): A new copy of the directory with the suffix "_Source" will be created. This is the directory which should be edited. Any changes here will be reflected in the primary directory.
--_G.RefreshDirectory(directory): The given directory will have all its ModuleScripts "refreshed" s.t. they can be required again.
--_G.CloseDirectory(directory): the given directory will have its "_Source" folder cloned in one final time, then deleted..

--[[

require(game.ReplicatedStorage.lib_Source.Utils.SourceManagement:Clone()).RefreshDirectory(game.ReplicatedStorage.lib);

--]]

local module = {};

local ARCHIVE_LIMIT = 1;
local WRITE_TO_G = false;

function module.OpenDirectory(dir)
	if dir.Parent:FindFirstChild(dir.Name .. "_Source") then
		print(string.format("Directory %s already opened for editing.", dir.Name));
	end
	local source = dir:Clone();
	source.Name = dir.Name .. "_Source";
	source.Parent = dir.Parent;
end

function module.RefreshDirectory(dir)
	local source = dir.Parent:FindFirstChild(dir.Name .. "_Source");
	if not source then
		print(string.format("Directory %s not yet opened for editing. Opening now...", dir.Name));
		_G.OpenDirectory(dir);
		return module.RefreshDirectory(dir);
	end
	local DirectoryName = dir.Name;
	local newDir = source:Clone();
	newDir.Name = dir.Name;
	dir.Name = dir.Name .. "_" .. math.floor(tick());
	if ARCHIVE_LIMIT > 0 then
		if not game.ServerStorage:FindFirstChild("Archive") then
			Instance.new("Folder", game.ServerStorage).Name = "Archive";
		end
		if ARCHIVE_LIMIT ~= math.huge then
			local Archives = {};
			for i, v in pairs(game.ServerStorage.Archive:GetChildren()) do
				local name = v.Name:gmatch("(.*)_%d+$")();
				if name == DirectoryName then
					table.insert(Archives, v);
				end
			end
			if #Archives > ARCHIVE_LIMIT - 1 then
				local N = #DirectoryName+2;
				table.sort(Archives, function(a, b)
					return tonumber(a.Name:sub(N)) < tonumber(b.Name:sub(N));
				end);
				for i = 1, #Archives - ARCHIVE_LIMIT + 1 do
					Archives[i].Parent = nil;
				end
			end
		end
		dir.Parent = game.ServerStorage.Archive;
	else
		dir.Parent = nil;
	end
	newDir.Parent = source.Parent;
end

function module.CloseDirectory(dir)
	local source = dir.Parent:FindFirstChild(dir.Name .. "_Source");
	if not source then
		print(string.format("Directory %s not opened for editing.", dir.Name));
		return;
	end
	module.RefreshDirectory(dir);
	source.Parent = nil;
end

if WRITE_TO_G then
	for i, v in pairs(module) do
		_G[i] = v;
	end
end

return module;
