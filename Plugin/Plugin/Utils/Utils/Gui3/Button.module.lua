--[[

An object which has events for user input.
It is non-rendering, but can be placed in rendering objects.

Events:
	Click1(x, y): fires when the left mouse button is clicked. x and y are in local space.
	Click2(x, y): fires when the right mouse button is clicked. x and y are in local space.
	Drag(event, x, y): fires when the button is dragged. Event can take the following values:
		"Down": when the drag begins. x and y are in local space.
		"Move": when the mouse moves during a drag. x and y are not supplied.
		"Up": when the drag ends. x and y are not supplied.
	Scroll(direction, x, y): fires when the mouse wheel is scrolled. direction is 1 when scrolling up, -1 when scrolling down. x and y are in local space.
	Hover(value): fires when the mouse enters the button. Value is true when the mouse enters, false when it exits.
	Move(x, y): fires when the mouse moves within the button. x and y are in local space.

--]]

local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local Debug = Utils.new("Log", "Button: ", false);

local Super = Gui.GuiBase2d;
local Button = Utils.new("Class", "Button", Super);

local EventList = Utils.new("EventLoaderBuilder");
EventList.EventConstructor = Utils.new["Event"];
EventList.Events = {"Click1", "Click2", "Drag", "Scroll", "Hover", "Move"};

Button._Frame = false;
Button._Cxns = false;
Button._Events = false;

for i, Event in pairs(EventList.Events) do
	Button.Get[Event] = function(self)
		return self._Events[Event];
	end
end

function Button:_Clone(new)

end

function Button:_GetRbxHandle()
	return self._Frame;
end

local UIS = game:GetService("UserInputService")
local CreateEvent = {};
function CreateEvent.Click2(self)
	local ticketTaker = Utils.new("LockoutTag");
	local ticket;
	self._Cxns["M2Down"] = self._Frame.InputBegan:connect(function(io, gameProcessedEvent)
		ticket = ticketTaker:Take();
	end)
	self._Cxns["M2Up"] = self._Frame.InputEnded:connect(function(io, gameProcessedEvent)
		if Enum.UserInputType.MouseButton2 == io.UserInputType then
			if ticketTaker:Valid(ticket) then
				local x = io.Position.x - self._Frame.AbsolutePosition.x;
				local y = io.Position.y - self._Frame.AbsolutePosition.y;
				self._Events:FireEvent("Click2", x, y);
			end
		end
	end);
	self._Cxns["M2UpUIS"] = game:GetService("UserInputService").InputEnded:connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local t = ticket;
			wait();
			ticketTaker:Return(t);
		end
	end);
end
function CreateEvent.Click1AndDrag(self)
	local downPos; --The initial drag position in screen space.
	local dragStartPos; --The initial drag position in local space.
	local dragging;
	local ticket = Utils.new("LockoutTag");
	local t;
	--[[ @brief Handles some internal stuff with regard to moving.
	     @param x The x coordinate of the mouse in local space.
	     @param y Ditto.
	--]]
	local function Move(x, y)
		if ticket:Valid(t) then
			if not dragging then
				local offset = downPos - Vector2.new(x, y);
				local offsetmagnitude = math.sqrt(offset.x^2 + offset.y^2);
				if offsetmagnitude > 5 then
					self._Events:FireEvent("Drag", "Down", dragStartPos.x, dragStartPos.y);
					dragging = true;
					self._Events:FireEvent("Drag", "Move");
				end
			else
				self._Events:FireEvent("Drag", "Move");
			end
		end
	end
	self._Cxns["M1Down"] = self._Frame.InputBegan:connect(function(io)
		--I'm about to have an aneurysm over the coordinate nonsense.
		--MouseButton1Down/Up are in absolute space.
		--UserInputService is in gui space... unless you use GetMouseLocation().
		--AbsolutePosition is in gui space.

		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			--Convert to gui space.
			local x = io.Position.x - self._Frame.AbsolutePosition.x;
			local y = io.Position.y - self._Frame.AbsolutePosition.y;
	
			dragStartPos = Vector2.new(x, y);
			downPos = game:GetService("UserInputService"):GetMouseLocation();
			dragging = false;
			t = ticket:Take();
			self._Cxns["M1Move"] = game:GetService("UserInputService").InputChanged:connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					local p = game:GetService("UserInputService"):GetMouseLocation();
					Move(p.x, p.y);
				end
			end)
			self._Cxns["M1Up"] = game:GetService("UserInputService").InputEnded:connect(function(input)
				if ticket:Valid(t) and input.UserInputType == Enum.UserInputType.MouseButton1 then
					local x = io.Position.x - self._Frame.AbsolutePosition.x;
					local y = io.Position.y - self._Frame.AbsolutePosition.y;
					local fr = self._Frame.AbsoluteSize;
					local mouseOverFrame = x >= 0 and x <= fr.x and y >= 0 and y <= fr.y;
		
					downPos = false;
					if not dragging then
						if mouseOverFrame then
							self._Events:FireEvent("Click1", x, y);
						end
					else
						self._Events:FireEvent("Drag", "Up");
					end
					dragging = false;
					self._Cxns:Disconnect("M1Move");
					self._Cxns:Disconnect("M1Up");
					ticket:Return(t);
				end
			end)
		end
	end)
end
function CreateEvent.Scroll(self)
	self._Cxns["ScrollUIS"] = self._Frame.InputChanged:connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessedEvent then
			self._Events:FireEvent("Scroll", input.Position.z, input.Position.x - self._Frame.AbsolutePosition.x, input.Position.y - self._Frame.AbsolutePosition.y);
		end
	end)
end
function CreateEvent.Hover(self)
	self._Cxns["MouseEnter"] = self._Frame.InputBegan:connect(function(io, gameProcessedEvent)
		if io.UserInputType == Enum.UserInputType.MouseMovement then
			local x = io.Position.x - self._Frame.AbsolutePosition.x;
			local y = io.Position.y - self._Frame.AbsolutePosition.y;
			self._Events:FireEvent("Hover", true);
			self._Events:FireEvent("Move", x, y);
			self._Cxns["MouseLeave"] = self._Frame.InputEnded:connect(function(io, gameProcessedEvent)
				if io.UserInputType == Enum.UserInputType.MouseMovement then
					self._Events:FireEvent("Hover", false);
					self._Cxns:Disconnect("MouseLeave");
					self._Cxns:Disconnect("MouseMoved");
				end
			end);
			self._Cxns["MouseMoved"] = self._Frame.InputChanged:connect(function(io, gameProcessedEvent)
				if io.UserInputType == Enum.UserInputType.MouseMovement then
					local x = io.Position.x - self._Frame.AbsolutePosition.x;
					local y = io.Position.y - self._Frame.AbsolutePosition.y;
					self._Events:FireEvent("Move", x, y);
				end
			end);
		end
	end)
end

function Button.new()
	local self = setmetatable(Super.new(), Button.Meta);
	self._Frame = Instance.new("TextButton");
	self._Frame.BackgroundTransparency = 1;
	self._Frame.AutoButtonColor = false;
	self._Frame.Text = "";
	self._Cxns = Utils.new("ConnectionHolder");
	self._Events = EventList:Instantiate();
	self._Events.OnEventCreated = function(event)
		if event == "Click1" or event == "Drag" then
			CreateEvent.Click1AndDrag(self);
		elseif event == "Click2" then
			CreateEvent.Click2(self);
		elseif event == "Scroll" then
			CreateEvent.Scroll(self);
		elseif event == "Hover" or event == "Move" then
			CreateEvent.Hover(self);
		end
	end
	return self;
end

function Gui.Test.Button_Default(sgui, cgui)
	local r = Button.new();
	r.Size = UDim2.new(.5, 0, .5, 0);
	r.Position = UDim2.new(.25, 0, .25, 0);
	r.Parent = cgui;
	local f = Gui.new("Rectangle");
	f.Parent = r;
	f.Size = UDim2.new(1, 0, 1, 0);

	r.Click1:connect(function(x, y)
		Debug("Click1(%s, %s) called", x, y);
	end)
	r.Drag:connect(function(m, x, y)
		Debug("Drag(%s, %s, %s) called", m, x, y);
	end)

	r.Click2:connect(function(x, y)
		Debug("Click2(%s, %s) called", x, y);
	end)

	r.Hover:connect(function(value)
		Debug("Hover(%s) called", value);
	end)
	r.Move:connect(function(x, y)
		Debug("Move(%s, %s) called", x, y);
	end)

	r.Scroll:connect(function(dir, x, y)
		Debug("Scroll(%s, %s, %s) called", dir, x, y);
	end)
end

return Button;
