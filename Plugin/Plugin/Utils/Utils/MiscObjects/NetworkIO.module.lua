--[[

Attempts to create an easy interface across which one can communicate.
The API is denoted by a hierarchy of RemoteEvents/RemoteFunctions/Folders.
Each Remote* begins with:
	"Server_": this will be handled by the server.
	"Client_": this will be handled by the client.
	"Both_": this will be handled by both server and client.
These need not be specified to index the function.

When indexing the Remote*, the following APIs are available:
	RemoteEvent:
		__call(...): invokes the remote side of the event.
		Client(): invokes the client side of the event (useful when calling a client event from the client).
		Server(): invokes the server side of the event (useful when calling a server event from the server).
		connect(): allows you to connect a callback to the event.
	RemoteFunction:
		__call(...): calls the remote side of the function.
		Client(): calls the client-side function.
		Server(): calls the server-side function.
		The RemoteFunction can have its callback function set by invoking __newindex on the containing folder/NetworkIO object.

Properties:
	API: the folder in which BindableEvents can be found.
	Role: whether this NetworkIO represents the client or server. This should be plugged in automatically, but it will not work in studio.

Constructor:
	new(api, role): creates a network IO interface using a given API folder & a role ("client" or "server").

--]]

local Utils = require(game.ReplicatedStorage.Utils);
local Debug = Utils.new("Log", "NetworkIO: ", false);

local HANDLERS = {
	RemoteEvent = {
		Server = {
			Server = function(self, ...)
				Debug("Firing RemoteEvent from Server to Server");
				--TODO: Make local bindable event
				Utils.Log.Error("Failed to implement Server to Server Events");
			end;
			Client = function(self, player, ...)
				Debug("Firing RemoteEvent from Server to Client");
				return self._API:FireClient(player, ...);
			end;
			AllClients = function(self, ...)
				Debug("Firing RemoteEvent from Server to AllClients");
				return self._API:FireAllClients(...);
			end;
			connect = function(self, f)
				Debug("Connecting RemoteEvent on Server");
				return self._API.OnServerEvent:connect(f);
			end
		};
		Client = {
			Server = function(self, ...)
				Debug("Firing RemoteEvent from Client to Server");
				return self._API:FireServer(...);
			end;
			Client = function(self, ...)
				Debug("Firing RemoteEvent from Client to Client");
				--TODO: make local BindableEvents.
				Utils.Log.Error("Failed to implement Client to Client Events");
			end;
			connect = function(self, f)
				Debug("Connecting RemoteEvent on Client");
				return self._API.OnClientEvent:connect(f);
			end
		};
	};
	RemoteFunction = {
		Server = {
			Server = function(self, ...)
				Debug("Firing RemoteEvent from Server to Server");
				return self._Callback(...);
			end;
			Client = function(self, player, ...)
				Debug("Firing RemoteEvent from Server to Client");
				return self._API:InvokeClient(player, ...);
			end;
			_SetCallback = function(self, f)
				Debug("Setting Callback on Server");
				self._API.OnServerInvoke = f;
			end;
		};
		Client = {
			Server = function(self, ...)
				Debug("Firing RemoteEvent from Client to Server");
				return self._API:InvokeServer(...);
			end;
			Client = function(self, ...)
				Debug("Firing RemoteEvent from Client to Client");
				return self._Callback(...);
			end;
			_SetCallback = function(self, f)
				Debug("Setting Callback on Client");
				self._API.OnClientInvoke = f;
			end;
		};
	};
	Folder = {
		Server = {};
		Client = {};
	}
};

local NetworkIO = Utils.new("Class", "NetworkIO");

NetworkIO._API = script;
NetworkIO._Children = {};
NetworkIO._Role = "unknown";
NetworkIO.Remote = function(self) Utils.Log.Error("Cannot call into remote for %s from context %s", self._API:GetFullName()); end
NetworkIO.Local = function(self) Utils.Log.Error("Cannot call into local for %s from context %s", self._API:GetFullName()); end
NetworkIO.RemoteAll = function(self) Utils.Log.Error("Cannot call into remote-all for %s from context %s", self._API:GetFullName()); end
NetworkIO.connect = function(self) Utils.Log.Error("Undefined connect() function for %s", self._API:GetFullName()); end
NetworkIO._call = function(self) Utils.Log.Error("Undefined call function for %s", self._API:GetFullName()); end;
NetworkIO._SetCallback = function(self) Utils.Log.Error("Cannot set callback for event type: %s", self._API:GetFullName()); end;

function NetworkIO:__index(i)
	Debug("Indexed %s", i);
	if not self._Children[i] then
		local prefixServer = "Server_" .. i;
		local prefixClient = "Client_" .. i;
		local prefixBoth = "Both_" .. i;
		local prefixNone = "" .. i;
		for _, v in pairs(self._API:GetChildren()) do
			if v.Name == prefixNone or v.Name == prefixServer or v.Name == prefixClient or v.Name == prefixBoth then
				local newNetworkIO = NetworkIO.new(v, self._Role);
				Utils.Log.Assert(newNetworkIO, "NetworkIO.new(%s, %s) returned nil", v, self._Role);
				self._Children[i] = newNetworkIO;
				break;
			end
		end
		Utils.Log.Assert(self._Children[i], "Failed to find child %s of %s", i, self._API:GetFullName());
	end
	return self._Children[i];
end

function NetworkIO:__newindex(i, v)
	local subapi = self[i];
	subapi:_SetCallback(v);
end

function NetworkIO:__call(...)
	return self:_call(...);
end

local VALID_CLASSES = {};
VALID_CLASSES.Folder = true;
VALID_CLASSES.RemoteEvent = true;
VALID_CLASSES.RemoteFunction = true;

function NetworkIO.new(api, role)
	--TODO: cache everything
	Debug("Fetching NetworkIO for operation %s for role %s", api, role);
	local self = setmetatable({}, NetworkIO.Meta);
	self._API = api;
	self._Role = role:lower();
	self._Children = {};
	local server = false;
	local client = false;
	if self._API.Name:sub(1, 7) == "Server_" then
		server = true;
		client = false;
	elseif self._API.Name:sub(1, 7) == "Client_" then
		server = false;
		client = true;
	elseif self._API.Name:sub(1, 5) == "Both_" then
		server = true;
		client = true;
	end

	Utils.Log.Assert(VALID_CLASSES[self._API.ClassName], "NetworkIO API hierarchy must consist only of Folders, RemoteEvents, and RemoteFunctions; got %s at %s", api.ClassName, api:GetFullName());
	Utils.Log.Assert(self._Role == "server" or self._Role == "client", "NetworkIO Role must be server or client");

	local callServer = HANDLERS[self._API.ClassName][self._Role=="server" and "Server" or "Client"].Server;
	local callClient = HANDLERS[self._API.ClassName][self._Role=="server" and "Server" or "Client"].Client;
	local callAllClients = HANDLERS[self._API.ClassName][self._Role=="server" and "Server" or "Client"].AllClients;
	if self._Role == "server" then
		if server then
			self.Local = callServer;
			self._call = self.Local;
		end
		if client then
			self.Remote = callClient;
			self.RemoteAll = callAllClients;
			self._call = function(self, player, ...)
				if player and typeof(player) == "Instance" and player:IsA("Player") then
					return callClient(self, player, ...);
				else
					return callAllClients(self, player, ...);
				end
			end
		end
	else
		if client then
			self.Local = callClient;
			self._call = self.Local;
		end
		if server then
			self.Remote = callServer;
			self._call = self.Remote;
		end
	end

	if (server and role == "server") or (client and role == "client") then
		self.connect = HANDLERS[self._API.ClassName][self._Role=="server" and "Server" or "Client"].connect;
		self._SetCallback = HANDLERS[self._API.ClassName][self._Role=="server" and "Server" or "Client"]._SetCallback;
	end
	return self;
end

return NetworkIO;
