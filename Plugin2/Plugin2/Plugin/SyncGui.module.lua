--[[

Renders the GUI to represent this project.

Note: implementation was put on hold to attempt to salvage the old SyncGui interface. Not because it's particularly good -- but because it will take me to the finish line. :)

Properties:
	Connected (boolean): can be set to true to indicate that we are connected to the server.
	AddNewCallback (function(dataModelObject, remotePath)): a function to call when the user attempts to add a new project to the GUI.
	RefreshCallback (function(project)): the function called when the refresh button is clicked. The argument project may be supplied if we are specifically refreshing a single project; otherwise, we pass `nil`, meaning refresh all.
	DeleteCallback (function(project)): the function called when a project is attempted to be deleted.
	Projects (array): an array where each element has the form:
		{ InSync = <true|false>; AutoSync = <true|false>; DataModelObject = <object handle>; RemotePath = "<path>"; Files = {
			{ LocalObject = <object handle>; RemotePath = "<object path>"; InSync = <true|false>; },
			... }
		}

Methods:

Constructors:
	new(): default constructor.

--]]

local module = {}

return module
