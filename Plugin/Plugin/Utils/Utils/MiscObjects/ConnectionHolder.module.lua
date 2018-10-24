local Utils = require(script.Parent.Parent);

local ConnectionHolder = Utils.new("Class", "ConnectionHolder");

ConnectionHolder._Mode = "DisconnectFirst";
ConnectionHolder._Connections = false;

--[[ @brief Validates and sets the "Mode" property.
     @param mode A string of value 'DisconnectFirst' or 'DisconnectSecond'.
--]]
function ConnectionHolder.Set:Mode(mode)
	Utils.Log.AssertNonNilAndType("Mode", "string", mode);
	if mode=="DisconnectFirst" or mode=="DisconnectSecond" then
		self._Mode = mode;
	else
		Utils.Log.Error("Invalid value for Mode: %s; expected 'DisconnectFirst' or 'DisconnectSecond'.", mode);
	end
end

ConnectionHolder.Get.Mode = "_Mode";

--[[ @brief Disconnects all connections.
--]]
function ConnectionHolder:DisconnectAll()
	while next(self._Connections) do
		self:Disconnect(next(self._Connections));
	end
end

--[[ @brief Disconnects a connection given its name.
     @param name The name of the connection we are removing.
--]]
function ConnectionHolder:Disconnect(name)
	if self._Connections and self._Connections[name] and self._Connections[name].connected then
		self._Connections[name]:disconnect();
	end
	self._Connections[name] = nil;
end

--[[ @brief Registers a connection into this holder.
     @param name An identifier for this connection.
     @param connection The connection object. Should have property 'connected' and method 'disconnect'.
     @details If a connection with the name of 'name' already exists, conflict resolution will be pursued depending on the value of the Mode property.
--]]
function ConnectionHolder:Add(name, connection)
	if self._Connections[name] and self._Connections[name].connected then
		if self._Mode == "DisconnectFirst" then
			self:Disconnect(name);
		elseif self._Mode == "DisconnectSecond" then
			connection:disconnect();
			return;
		end
	end
	self._Connections[name] = connection;
end

--[[ @brief Alias for ConnectionHolder:Add(name, connection).
--]]
function ConnectionHolder:__newindex(name, connection)
	self:Add(name, connection);
end

--[[ @brief Returns whether a connection is made and active.
--]]
function ConnectionHolder:__index(name)
	return self._Connections[name] and self._Connections[name].connected;
end

--[[ @brief Creates a new ConnectionHolder object.
--]]
function ConnectionHolder.new()
	local self = setmetatable({}, ConnectionHolder.Meta);
	self._Connections = {};
	return self;
end

return ConnectionHolder;
