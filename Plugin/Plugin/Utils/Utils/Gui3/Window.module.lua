local __help = [[

Window renders a gui that may be dragged around by its title bar and resized.
Properties:
	Resizable (boolean): whether or not the window is resizable.
	Draggable (boolean): whether or not the window may be dragged.
	Title (text): the text to display in the title bar.
	ButtonImages (array<text>): an array of images to display for buttons.
SpecializedLayout Schema:
	Content: the object to display in the main pane of the window.
	Background: the backdrop to lay behind the contents.
	Button: a button which gets cloned as needed to be placed at the top-right button array.
		SetDisplayImage(obj, image, index): a function which gets called when ButtonImages changes and re-initializes a button's display. 
		AspectRatio (number): the aspect ratio of the button.
	TitleBar: the image label (or similar) to use for the title.
		Offset: the height of the title bar in pixels.
		Scale: the height of the title bar with respect to the total window height.
		SetButtonWidth(obj, width): indicates the number of pixels which will be provided along the right side for buttons.
		SetText(obj, text): sets the text to display for the title bar.

]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);
local UIS = game:GetService("UserInputService");

local EDGE_WIDTH = 8;
local TOP_EDGE_WIDTH = 3;

local Debug = Utils.new("Log", "Window: ", false);

local WINDOW_SCHEMA = {
	TitleBar = {
		Type = "Single";
		LayoutParams = {
			Offset = 0;
			Scale = 0;
			SetButtonWidth = function() end;
			SetText = function() end;
		};
		Default = Gui.Create "Rectangle" {
			LayoutParams = {
				SetText = function(s, t)
					s.Label.Text = t;
				end;
				Offset = 20;
				ZIndex = 0;
			};
			Color = Utils.Math.HexColor(0xabc6f2);
			Gui.Create "Text" {
				Name = "Label";
				Color = Utils.Math.HexColor(0x0c1523);
			};
		};
		ParentName = "_Button";
	};
	Button = {
		Type = "Many";
		LayoutParams = {
			SetDisplayImage = function(obj, image, index) end;
			AspectRatio = 1;
		};
		Default = Gui.Create "Button" {
			Gui.Create "Image" {
				Name = "Image";
			};
			LayoutParams = {
				SetDisplayImage = function(obj, image) obj.Image.Image = image; end;
			};
		};
		ParentName = "_Button";
	};
	Background = {
		Type = "Single";
		LayoutParams = {};
		Default = Gui.Create "Rectangle" {
			Color = Utils.Math.HexColor(0xEEEEEE);
			ZIndex = 0;
		};
		ParentName = "_Button";
	};
	Content = {
		Type = "Single";
		LayoutParams = {};
		Default = Gui.Create "GuiBase2d" {};
		ParentName = "_Button";
	};
	DefaultRole = "Content";
};

local Super = Gui.SpecializedLayout;
local Window = Utils.new("Class", "Window", Super);
Window.__help = __help;

Window.Name = "Window";
Window._Resizable = false;
Window._Draggable = true;
Window._Title = "Window";
Window._ButtonImages = {};

Window._Cxns = false;
Window._Button = false;
Window._LastSize = false;
Window._LastPos = false;
Window._ButtonsWidth = 0;
Window._Changed = false;

function Window.Set:Resizable(v)
	self._Resizable = v;
end
function Window.Set:Draggable(v)
	self._Draggable = v;
end
function Window.Set:Title(v)
	self._Title = v;
	local child, params = self._ChildParameters:GetChildOfRole("TitleBar");
	params.SetText(child, v);
end
function Window.Set:ButtonImages(v)
	self._ButtonImages = v;
	self._ChildParameters:SetRoleCount("Button", #v);
	for i = 1, #v do
		local child, params = self._ChildParameters:GetChildOfRole("Button", i);
		params.SetDisplayImage(child, v[i]);
	end
end

Window.Get.Resizable = "_Resizable";
Window.Get.Draggable = "_Draggable";
Window.Get.Title = "_Title";
Window.Get.ButtonImages = "_ButtonImages";

function Window:_AdjustAbsolutePosition(delta)
	Super._AdjustAbsolutePosition(self, delta);
	self._Button._AbsoluteSize = self._AbsoluteSize;
	self._Button._AbsolutePosition = self._AbsolutePosition;
end

function Window:_Reflow()
	Debug("Window._Reflow(%s) called", self);
	local pos, size = Super._Reflow(self, true);
	if size.X.Offset < 0 or size.Y.Offset < 0 then
		size = UDim2.new(0, size.X.Offset < 0 and 0 or size.X.Offset, 0, size.Y.Offset < 0 and 0 or size.Y.Offset);
	end
	local coordinatesChanged = pos ~= self._LastPos or size ~= self._LastSize;
	self._LastPos = pos;
	self._LastSize = size;
	self._Button._AbsoluteSize = self._AbsoluteSize;
	self._Button._AbsolutePosition = self._AbsolutePosition;

	local titleBar, titleBarParams = self._ChildParameters:GetChildOfRole("TitleBar");
	local titleBarHeight = titleBarParams.Offset + titleBarParams.Scale * size.Y.Offset;
	if coordinatesChanged or self._Changed then
		local buttonWidth = 0;
		if #self._ButtonImages > 0 then
			local button, buttonParams = self._ChildParameters:GetChildOfRole("Button", 1);
			buttonWidth = buttonParams.AspectRatio * titleBarHeight;
			for i = 1, #self._ButtonImages do
				local button, params = self._ChildParameters:GetChildOfRole("Button", i);
				button._Size = UDim2.new(0, buttonWidth, 0, buttonWidth);
				button._Position = UDim2.new(0, size.X.Offset - buttonWidth * i, 0, 0);
				button:_ConditionalReflow();
			end
			buttonWidth = buttonWidth * #self._ButtonImages;
			self._ButtonsWidth = buttonWidth;
		end

		titleBarParams.SetButtonWidth(titleBar, buttonWidth);
		titleBar._Position = UDim2.new();
		titleBar._Size = UDim2.new(0, size.X.Offset, 0, titleBarHeight);
		titleBar:_ConditionalReflow();

		local background, backgroundParams = self._ChildParameters:GetChildOfRole("Background");
		background._Position = UDim2.new(0, 0, 0, titleBarHeight);
		background._Size = UDim2.new(0, size.X.Offset, 0, size.Y.Offset - titleBarHeight);
		background:_ConditionalReflow();

		local content = self._ChildParameters:GetChildOfRole("Content");
		content._Position = UDim2.new(0, 0, 0, titleBarHeight);
		content._Size = UDim2.new(0, size.X.Offset, 0, size.Y.Offset - titleBarHeight);
		content:_ConditionalReflow();

		self._Changed = false;
	end

	return pos, size;
end

function Window:_GetRbxHandle()
	return self._Button:_GetRbxHandle();
end

function Window:Destroy()
	Super.Destroy(self);
	self._Cxns:DisconnectAll();
end

function Window.new()
	local self = setmetatable(Super.new(), Window.Meta);
	local function FlagChange(role)
		Debug("FlagChange(%s) called", role);
		self._Changed = true;
		if role == "Button" then
			self.ButtonImages = self.ButtonImages;
		end
		self._LastPos = UDim2.new(-1, 0, -1, 0);
		Debug("%2t", self._ChildParameters._RoleSource);
		self._TriggerReflow();
	end
	self._Cxns = Utils.new("ConnectionHolder");
	self._Button = Gui.new("Button");
	self._ChildParameters.RoleSourceChanged:connect(FlagChange);
	self._ChildParameters.LayoutParamsChanged:connect(FlagChange);
	self._ChildParameters.Schema = WINDOW_SCHEMA;
	do
		local dragging = false;
		local resizing = false;
		local queuedFunction; --A function to call when finishing dragging/resizing.
		self._Cxns.Drag = self._Button.Drag:connect(function(state, x, y)
			Debug("Drag offset from UIS:GetMousePosition: %s", Vector2.new(x, y) - game:GetService("UserInputService"):GetMouseLocation());
			Debug("Drag(%s, %d, %d) fired; dragging: %s; resizing: %s", state, x, y, dragging, resizing);
			if state == "Down" then
				if self._Resizable then
					local button = self._Button;
					--if we click within EDGE_WIDTH pixels of the edge of 'button', we should resize.
					Debug("Position: %s, %s; top left: %s; bottom right: %s", x, y, button.AbsolutePosition, button.AbsolutePosition + button.AbsoluteSize);
					local left, right = x <= EDGE_WIDTH, x >= button.AbsoluteSize.x - EDGE_WIDTH;
					local top, bottom = y <= TOP_EDGE_WIDTH, y >= button.AbsoluteSize.y - EDGE_WIDTH;
					if left or right or top or bottom then
						dragging = UIS:GetMouseLocation();
						resizing = Vector2.new((left and -1 or 0) + (right and 1 or 0), (top and -1 or 0) + (bottom and 1 or 0));
					end
				end
				Debug("dragging: %s; resizing: %s; self._Draggable: %s", dragging, resizing, self._Draggable);
				if self._Draggable and not resizing then
					Debug("Starting to drag");
					local titleBar, params = self._ChildParameters:GetChildOfRole("TitleBar");
					local pos, size = titleBar.AbsolutePosition - self._Button.AbsolutePosition, titleBar.AbsoluteSize;
					Debug("Mouse pos: %d, %d; title bar range: <%d, %d> - <%d, %d>", x, y, pos.x, pos.y, pos.x + size.x, pos.y + size.y);
					if  x >= pos.x and x <= pos.x + size.x and
						y >= pos.y and y <= pos.y + size.y then
						dragging = UIS:GetMouseLocation();
					end
				end
				if dragging then
					if resizing then
						local angle = resizing.x == 0 and (resizing.y * -90) or ((resizing.x+1)*90+resizing.y*resizing.x*45);
						Utils.Mouse.SetGuiIcon{"rbxassetid://887553936"; Rotation = angle;};
					else
						Utils.Mouse.SetGuiIcon{"rbxassetid://887555985"};
					end
					return;
				end
			elseif dragging then
				Debug("Dragging");
				local delta = UIS:GetMouseLocation() - dragging;
				dragging = UIS:GetMouseLocation();
				if resizing then
					local px, py = resizing.x==-1 and delta.x or 0, resizing.y==-1 and delta.y or 0;
					local sx, sy = resizing.x * delta.x, resizing.y * delta.y;
					self.Position = self.Position + UDim2.new(0, px, 0, py);
					self.Size = self.Size + UDim2.new(0, sx, 0, sy);
					self:_ConditionalReflow();
				else
					self.Position = self.Position + UDim2.new(0, delta.x, 0, delta.y);
					self:_ConditionalReflow();
				end
				if state == "Up" then
					dragging = false;
					resizing = false;
					if queuedFunction then
						queuedFunction();
					end
				end
			end
		end)
		self._Cxns.Hover = self._Button.Hover:connect(function(enabled)
			Debug("Hover(%s) called", enabled);
			if not enabled then
				--If we're dragging or resizing, don't change the mouse state. Queue it for when we finish.
				if dragging then
					queuedFunction = function()
						Utils.Mouse.SetGuiIcon{Enabled = false};
						self._Cxns:Disconnect("Move");
					end
				else
					Utils.Mouse.SetGuiIcon{Enabled = false};
					self._Cxns:Disconnect("Move");
				end
			else
				queuedFunction = nil;
				if self._Draggable or self._Resizable then
					self._Cxns.Move = self._Button.Move:connect(function(x, y)
						if dragging then
							if resizing then
								local angle = resizing.x == 0 and (resizing.y * -90) or ((resizing.x+1)*90+resizing.y*resizing.x*45);
								Utils.Mouse.SetGuiIcon{"rbxassetid://887553936"; Rotation = angle;};
							else
								Utils.Mouse.SetGuiIcon{"rbxassetid://887555985"};
							end
							return;
						end

						local setIcon;
						local titleBar, params = self._ChildParameters:GetChildOfRole("TitleBar");
						local pos, size = self._AbsolutePosition, self._AbsoluteSize;
						if pos.x + size.x - self._ButtonsWidth <= x and x <= pos.x + size.x and pos.y <= y and y <= pos.y + titleBar.AbsoluteSize.y then
							setIcon = false;
						end
						--Check if we're near the window edges.
						if setIcon == nil and self._Resizable and not dragging then
							local left, right = x <= EDGE_WIDTH, x >= size.x - EDGE_WIDTH;
							local top, bottom = y <= TOP_EDGE_WIDTH, y >= size.y - EDGE_WIDTH;
							local r = ((left and 180 or 0) + (top and -90 or bottom and 90 or 0)) / (((left or right) and 1 or 0) + ((top or bottom) and 1 or 0));
							if left or right or top or bottom then
								Utils.Mouse.SetGuiIcon{"rbxassetid://887553936"; Rotation = r;};
								setIcon = true;
							end
						end
						--Check if we're draggable and hovering over the title bar.
						if setIcon == nil and self._Draggable and not dragging then
							local pos, size = titleBar.AbsolutePosition - self._Button.AbsolutePosition, titleBar.AbsoluteSize;
							if  x >= pos.x and x <= pos.x + size.x and
								y >= pos.y and y <= pos.y + size.y then
								Utils.Mouse.SetGuiIcon{"rbxassetid://887555985"; Rotation = 0;};
								setIcon = true;
							end
						end
						if not setIcon and not dragging then
							Utils.Mouse.SetGuiIcon{Enabled = false};
						end
					end)
				end
			end
		end)
	end
	return self;
end

function Gui.Test.Window_Default(sgui, cgui)
	local s = Window.new();
	s.Size = UDim2.new(0, 400, 0, 300);
	s.Parent = cgui;
end

local BUTTON_IMAGES = {
	Close = "rbxassetid://33191918";
	Expand = "rbxassetid://33191929";
	Collapse = "rbxassetid://33191924";
	Help = "rbxassetid://44555724";
	Check = "rbxassetid://33714981";
	Down = "rbxassetid://33191915";
	Up = "rbxassetid://36307823";
	Left = "rbxassetid://44532699";
	Right = "rbxassetid://44532707";
};

function Gui.Test.Window_WithButtons(sgui, cgui)
	local s = Window.new();
	s.Size = UDim2.new(0, 400, 0, 300);
	s.ButtonImages = {BUTTON_IMAGES.Close, BUTTON_IMAGES.Expand, BUTTON_IMAGES.Collapse};
	local x = Gui.Create "Image" {
		Size = UDim2.new(1, -4, 1, -4);
		Position = UDim2.new(0, 0, 0, 2);
		LayoutParams = {
			Role = "Button";
			SetDisplayImage = function(obj, image) obj.Image = image; end;
		};
		Name = "MyButton";
		Parent = s;
	};
	s.Title = "My Window";
	s.Resizable = true;
	s.Parent = cgui;
end

function Gui.Test.Window_WithChildren(sgui, cgui)
	local s = Window.new();
	s.Size = UDim2.new(0, 400, 0, 300);
	local x = Gui.Create "GridLayout" {
		GridSize = Vector2.new(5, 5);
		Cushion = Vector2.new(10, 10);
		RowAspectRatios = {0, 1, 1, 1, 0};
		ColumnAspectRatios = {0, 1, 1, 1, 0};
		RowWeights = {1, 0, 0, 0, 1};
		ColumnWeights = {1, 0, 0, 0, 1};
	};
	for i = 1, 9 do
		local y = Gui.Create "Rectangle" {
			Color = Color3.fromHSV((i-1)/9, 1, 1);
			Parent = x;
			LayoutParams = {
				Position = Vector2.new(
					1 + (i - 1) % 3 + 1,
					1 + math.floor((i - 1) / 3) + 1);
			};
		};
		Debug("Rectangle Position: <%s>", y.LayoutParams.Position);
	end
	s.Resizable = true;
	s.Parent = cgui;
	wait();
	x.Parent = s;
end

return Window;
