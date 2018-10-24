local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Window = Utils.new("Class", "Window");

Window.TitleBarHeight = 20;
Window._Cxns = false;

function Window:Update(handle)
	local title = handle:FindFirstChild("Title");
	title.Position = UDim2.new();
	title.Size = UDim2.new(1, 0, 0, self.TitleBarHeight);
	local content = handle:FindFirstChild("Content");
	content.Size = UDim2.new(1, 0, 1, -self.TitleBarHeight);
	content.Position = UDim2.new(0, 0, 0, self.TitleBarHeight);
	local components = {[title] = true, [content] = true};
	for i, v in pairs(handle:GetChildren()) do
		if not components[v] then
			v.Parent = content;
		end
	end
end

local _ = Window.Meta;

function Window.new()
	local self = setmetatable({}, Window.Meta);
	self._Cxns = Utils.new("ConnectionHolder");
	local handle = Instance.new("Frame");
	handle.BackgroundColor3 = Utils.Math.HexColor(0xDDDDDD);
	handle.BorderSizePixel = 0;
	local title = Instance.new("TextButton");
	title.Name = "Title";
	title.BackgroundColor3 = Utils.Math.HexColor(0x5194ff);
	title.Text = "Window";
	title.TextXAlignment = Enum.TextXAlignment.Left;
	title.BorderSizePixel = 0;
	title.AutoButtonColor = false;
	title.MouseButton1Down:connect(function(x, y)
		local startMousePos = Vector2.new(x, y);
		local startWindowPos = handle.Position;
		self._Cxns.Move = game:GetService("UserInputService").InputChanged:connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
				local delta = Vector2.new(inputObject.Position.x - startMousePos.x, inputObject.Position.y - startMousePos.y);
				handle.Position = startWindowPos + UDim2.new(0, delta.x, 0, delta.y);
			end
		end)
		self._Cxns.M1Up = game:GetService("UserInputService").InputEnded:connect(function(inputObject)
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
				local delta = Vector2.new(inputObject.Position.x - startMousePos.x, inputObject.Position.y - startMousePos.y);
				handle.Position = startWindowPos + UDim2.new(0, delta.x, 0, delta.y);
				self._Cxns:Disconnect("Move");
				self._Cxns:Disconnect("M1Up");
			end
		end)
	end)
	title.Parent = handle;
	local content = Instance.new("Frame");
	content.Name = "Content";
	content.BackgroundTransparency = 1;
	content.Parent = handle;

	local components = {[title] = true; [content] = true;};
	handle.ChildAdded:connect(function(child)
		if not components[child] then
			spawn(function()
				child.Parent = content;
			end);
		end
	end)
	self:Update(handle);
	return handle, self;
end

function Gui.Test.Window_Default(sgui, cgui)
	local window = Window.new();
	window.Parent = cgui;
	window.Size = UDim2.new(0, 400, 0, 300);
end

Window.Help = [[
An element with a title bar and a main content pane. Windows can be dragged around.
]];

return Window;
