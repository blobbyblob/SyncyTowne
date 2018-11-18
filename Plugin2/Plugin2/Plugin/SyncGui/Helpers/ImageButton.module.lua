--[[

Brief description of the class.

Properties:
	Button (read-only): the actual button object.
	OnClick (function(invariant)): a callback fired when the button is clicked.
	Selected (boolean): when true, the button will be slightly darker in color to help indicate a "selected" state.
	Enabled (boolean): when false, the button will be grey and not respond to user input.
	Invariant: some variable to pass to the OnClick callback on each invocation.

Methods:

Events:
	Hovered(isHovered): fires when the mouse enters or exits a button.

Constructors:
	new(): construct with default settings.

--]]

local Utils = require(script.Parent.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "ImageButton: ", false);

local ImageButton = Utils.new("Class", "ImageButton");

ImageButton.Button = false;
ImageButton.OnClick = function() Debug("OnClick() called"); end
ImageButton._Selected = false;
ImageButton._Enabled = true;
ImageButton.Invariant = false;
ImageButton._HoveredEvent = false;
ImageButton.ToolTip = "";

ImageButton._Hovered = false;
ImageButton._Clicked = false;
ImageButton._Maid = false;

function ImageButton.Get:Hovered()
	return self._HoveredEvent.Event;
end
ImageButton.Get.Selected = "_Selected";
ImageButton.Get.Enabled = "_Enabled";

function ImageButton.Set:Selected(v)
	self._Selected = v;
	self:_UpdateButtonVisual();
end
function ImageButton.Set:Enabled(v)
	self._Enabled = v;
	self:_UpdateButtonVisual();
end

local TOOL_TIP = Instance.new("TextLabel");
TOOL_TIP.Name = "ToolTip";
TOOL_TIP.Size = UDim2.new(0, 160, 0, 40);
TOOL_TIP.Archivable = false;
TOOL_TIP.BackgroundColor3 = Color3.fromRGB(228, 238, 254);
TOOL_TIP.BorderColor3 = Color3.fromRGB(0, 0, 0);
TOOL_TIP.BackgroundTransparency = 0;
TOOL_TIP.TextColor3 = Color3.fromRGB(0, 0, 0);
TOOL_TIP.TextWrapped = true;

--[[ @brief Gets the first LayerCollector ancestor and returns it.
	@param gui The GUI whose ancestor we want to find.
	@return The first ancestor LayerCollector, or nil if none could be found.
--]]
local function GetAncestorLayerCollector(gui)
	while gui and not gui:IsA("LayerCollector") do
		gui = gui.Parent;
	end
	return gui;
end

--[[ @brief Gets the location to place the ToolTip.

	This places the tooltip to the upper right corner of the mouse, unless doing so would result in it going off-screen.
	@param pos A Vector2 or Vector3 indicating where we should approximately locate the ToolTip.
	@param parent The layer collector that holds this image button.
--]]
local function GetToolTipLocation(pos, parent)
	local xAdjust = 5;
	local yAdjust = -TOOL_TIP.Size.Y.Offset - 5;
	if pos.x + xAdjust > parent.AbsoluteSize.x - TOOL_TIP.Size.X.Offset and pos.x > (parent.AbsoluteSize.x - pos.x) then
		xAdjust = -TOOL_TIP.Size.X.Offset - 5;
	end
	if (pos.y + yAdjust) < 0 and pos.y < (parent.AbsoluteSize.y - pos.y) then
		yAdjust = 5;
	end
	return UDim2.new(0, pos.x + xAdjust, 0, pos.y + yAdjust);
end

function ImageButton:_HookUpListeners()
	self.Button.InputBegan:connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseMovement then
			self._Hovered = true;
			self:_UpdateButtonVisual();
			if self.ToolTip and self.ToolTip ~= "" then
				TOOL_TIP.Text = self.ToolTip;
				--TODO: size TOOL_TIP properly for its text contents.
				local parent = GetAncestorLayerCollector(self.Button);TOOL_TIP.Position = GetToolTipLocation(io.Position, parent);
				TOOL_TIP.Parent = nil;
				local removeOnCleanup = true;
				self._Maid.ToolTipMove = self.Button.InputChanged:Connect(function(io)
					TOOL_TIP.Position = GetToolTipLocation(io.Position, parent);
				end);
				self._Maid.ToolTipParentChanged = TOOL_TIP:GetPropertyChangedSignal("Parent"):Connect(function()
					if TOOL_TIP.Parent ~= parent then
						removeOnCleanup = false;
					end
				end);
				self._Maid.ToolTipCleanup = function()
					--Debug("Attempting to clean up tooltip; parent matches expected? %s; remove on cleanup? %s", TOOL_TIP.Parent == parent, removeOnCleanup);
					if TOOL_TIP.Parent == parent and removeOnCleanup then
						TOOL_TIP.Parent = nil;
					end
					self._Maid.ToolTipParentChanged = nil;
					self._Maid.ToolTipMove = nil;
				end;
				TOOL_TIP.Parent = parent;
			end
			self._HoveredEvent:Fire(self._Hovered);
		end
	end)
	self.Button.InputEnded:connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseMovement then
			self._Hovered = false;
			self:_UpdateButtonVisual();
			self._Maid.ToolTipCleanup = nil;
			self._HoveredEvent:Fire(self._Hovered);
		end
	end)
	self.Button.MouseButton1Down:connect(function()
		self._Clicked = true;
		self:_UpdateButtonVisual();
	end)
	self.Button.MouseButton1Up:connect(function()
		self._Clicked = false;
		self:_UpdateButtonVisual();
		if self._Enabled then
			self.OnClick(self.Invariant);
		end
	end)
end

--[[

To match studio:

1. not Enabled: white background, grayscale the image & text with darkest at 120, 120, 120
2. Clicked: 219, 219, 219
3. Hovered + not Selected: 229, 239, 254 & border is invisible
4. Hovered + Selected: 228, 238, 254
5. Selected: 219, 219, 219
6. not Selected: 255, 255, 255

I don't believe there is a concept of not Enabled + Selected, so free reign there.
--]]

local COLOR_CONSTANTS = {
	BASE = Color3.fromRGB(255, 255, 255); --Enabled, not hovered, not selected.
	BASE_BORDER = Color3.fromRGB(182, 182, 182);

	CLICKED = Color3.fromRGB(219, 219, 219); --The mouse is depressed on the button at the moment.

	HOVERED_SELECTED = Color3.fromRGB(147, 190, 255); --The mouse is hovering over a selected object.
	HOVERED_DESELECTED = Color3.fromRGB(228, 238, 254); --the mouse is hovering over a non-selected object.

	SELECTED = Color3.fromRGB(181, 210, 255); --selected, but not hovering or clicked.
	DISABLED_SELECTED = Color3.fromRGB(220, 220, 220);
	DISABLED_DESELECTED = Color3.fromRGB(230, 230, 230);
};

function ImageButton:_UpdateButtonVisual()
	Debug("State: %s, %s, %s, %s", self.Enabled and "Enabled" or "not Enabled", self.Selected and "Selected" or "not Selected", self._Hovered and "Hovered" or "not Hovered", self._Clicked and "Clicked" or "not Clicked");
	--Potential states in priority order:
	--not Enabled + Selected
	--not Enabled + not Selected
	--Enabled + Clicked
	--Enabled + Hovered + Selected
	--Enabled + Hovered + not Selected
	--Enabled + Selected
	--Enabled + not Selected
	local bg = COLOR_CONSTANTS.BASE;
	local border = COLOR_CONSTANTS.BASE_BORDER;
	if self._Enabled then
		if self._Clicked then
			bg = COLOR_CONSTANTS.CLICKED;
		elseif self._Hovered then
			if self._Selected then
				bg = COLOR_CONSTANTS.HOVERED_SELECTED;
				border = bg;
			else
				bg = COLOR_CONSTANTS.HOVERED_DESELECTED;
			end
		else
			if self._Selected then
				bg = COLOR_CONSTANTS.SELECTED;
			else
				--Use defaults.
			end
		end
	else
		if self._Selected then
			bg = COLOR_CONSTANTS.DISABLED_SELECTED;
		else
			bg = COLOR_CONSTANTS.DISABLED_DESELECTED;
		end
	end
	self.Button.BackgroundColor3 = bg;
	self.Button.BorderColor3 = border;
end

function ImageButton.new(type)
	local self = setmetatable({}, ImageButton.Meta);
	self._HoveredEvent = Instance.new("BindableEvent");
	local b;
	if type == "Text" then
		b = Instance.new("TextButton");
		b.Text = "";
	else
		b = Instance.new("ImageButton");
		b.Image = "";
	end
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
	b.BackgroundTransparency = 0;
	b.BorderColor3 = Color3.fromRGB(196, 196, 196);
	b.AutoButtonColor = false;
	self.Invariant = self;
	self.Button = b;
	self._Maid = Utils.new("Maid");
	self:_HookUpListeners();
	self:_UpdateButtonVisual();
	return self;
end

return ImageButton;
