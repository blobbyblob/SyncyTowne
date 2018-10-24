local Utils = require(script.Parent.Parent);
local Gui = _G[script.Parent];
local Test = Gui.Test;
local Log = Utils.Log;

local Window = Utils.new("Class", "Window", require(script.Parent.View));
local Super = Window.Super;

local UIS = game:GetService("UserInputService");

Gui.Enum:newEnumClass("WindowLocation", "Content", "ButtonArray", "TitleBar");

-------------------
-- Properties --
-------------------
Window._Title = "Title";
Window._TitleBarHeight = 20;
Window._Resizable = false;
Window._Draggable = true;
Window._ButtonImages = {};
Window._TitleBarColor = Color3.new(0x00/255, 0x9D/255, 0xD1/255);
Window._ContentPaneColor = Color3.new(0xD1/255, 0xD1/255, 0xD1/255);

Window._ChildParameters = {
	Location = Gui.Enum.WindowLocation.Content;
};
Window._ChildPlacements = false;

Window._Handle = false;
Window._Header = false;
Window._TitleBar = false;
Window._Content = false;
Window._ContentPane = false;
Window._ResizableTab = false;
Window._Buttons = false;
Window._CornerButtons = false; --An array of ImageButtons.

Window._SizeDelta = Vector2.new(); --For when the user resizes the window.
Window._LastSizeDelta = Vector2.new();
Window._PosDelta = UDim2.new(); --For when the user moves the window.

-------------------------
-- Getters/Setters --
-------------------------
Window.Get.Title = "_Title";
Window.Get.TitleBarHeight = "_TitleBarHeight";
Window.Get.Resizable = "_Resizable";
Window.Get.Draggable = "_Draggable";
Window.Get.ChildProperties = "_ChildParameters";
Window.Get.TitleBarColor = "_TitleBarColor";
Window.Get.ContentPaneColor = "_ContentPaneColor";
function Window.Set:Title(v)
	Log.AssertNonNilAndType("Title", "string", v);
	self._Title = v;
	self._TitleBar.Text = v;
end
function Window.Set:TitleBarHeight(v)
	Log.AssertNonNilAndType("TitleBarHeight", "number", v);
	self._TitleBarHeight = v;
	for _, child in pairs(self:GetChildren()) do
		local LayoutParams = self._Buttons.ChildParameters:GetWritableParameters(child);
		if LayoutParams.Size ~= 0 then
			LayoutParams.Size = v;
		end
	end
	self._Handle.ChildProperties:GetWritableParameters(self._Header).Size = v;
	self._Handle._SignalReflowPre:Trigger();
end
function Window.Set:Resizable(v)
	Log.AssertNonNilAndType("Resizable", "boolean", v);
	self._Resizable = v;
	if not v then
		self._SizeDelta = Vector2.new();
	end
	self._ResizableTab.Visible = v;
end
function Window.Set:Draggable(v)
	Log.AssertNonNilAndType("Resizable", "boolean", v);
	self._PosDelta = UDim2.new();
	self._TitleBar.Active = v;
	self._TitleBar.Draggable = v;
end
function Window.Set:Name(v)
	Super.Set.Name(self, v);
	self._Handle.Name = self.Name .. "_LinearLayout";
	self._Header.Name = self.Name .. "_Header";
	self._TitleBar.Name = self.Name .. "_TitleBar";
	self._Buttons.Name = self.Name .. "_Buttons";
	self._Content.Name = self.Name .. "_Content";
	self._ContentPane.Name = self.Name .. "_ContentPane";
	self._ResizableTab.Name = self.Name .. "_ResizeTab";
end
function Window.Set:Parent(v)
	self._Handle.ParentNoNotify = v;
	Super.Set.Parent(self, v);
end
function Window.Set:ParentNoNotify(v)
	self._Handle.ParentNoNotify = v;
	Super.Set.ParentNoNotify(self, v);
end
function Window.Set:TitleBarColor(v)
	self._TitleBarColor = v;
	self._TitleBar.BackgroundColor3 = self._TitleBarColor;
end
function Window.Set:ContentPaneColor(v)
	self._ContentPaneColor = v;
	self._ContentPane.BackgroundColor3 = self._ContentPaneColor;
end
function Window.Set:Buttons(v)
	Log.AssertNonNilAndType("Buttons", "table", v);
	self._ButtonImages = v;
	self._SignalReflowPre:Trigger();
end

--The following functions defer to the LinearLayout this class wraps.
function Window:_GetHandle()
	return self._Handle:_GetHandle();
end

--[[ @brief Returns the roblox instance in which to place child.
     @details Based on the LayoutParams of child, it can either be placed in the main content pane or the title bar.
--]]
function Window:_GetChildContainerRaw(child)
--	local LayoutParams = self._Buttons.ChildProperties:GetWritableParameters(child);
	--Not Doing: is this right? Should it instead be:
	local LayoutParams = self._ChildParameters[child];
	if LayoutParams.Location == Gui.Enum.WindowLocation.ButtonArray then
		return self._Buttons:_GetChildContainer(child);
	elseif LayoutParams.Location == Gui.Enum.WindowLocation.TitleBar then
		return self._TitleBar:_GetChildContainer(child);
	else
		return self._ContentPane:_GetChildContainer(child);
	end
end
--@brief Removes child from the underlying representation & delegates to superiors.
function Window:_RemoveChild(child)
	self._ChildPlacements:RemoveChild(child);
	Super._RemoveChild(self, child);
end

function Window:ForceReflow()
	Super.ForceReflow(self);
	self._Handle:ForceReflow();
	self._Header:ForceReflow();
	self._TitleBar:ForceReflow();
	self._Buttons:ForceReflow();
	self._Content:ForceReflow();
	self._ContentPane:ForceReflow();
	self._ResizableTab:ForceReflow();
end

--[[ @brief Place all children in the proper directory element, then delegate to the underlying View.
--]]
function Window:_Reflow(pos, size)
	--Place children in the proper location based on their LayoutParams.Location value.
	for _, child in pairs(self:GetChildren()) do
		local DesiredLocation = self._ChildParameters[child].Location;
		if DesiredLocation == Gui.Enum.WindowLocation.Content then
			self._ChildPlacements:AddChildTo(child, self._ContentPane);
		elseif DesiredLocation == Gui.Enum.WindowLocation.TitleBar then
			self._ChildPlacements:AddChildTo(child, self._Header);
		elseif DesiredLocation == Gui.Enum.WindowLocation.ButtonArray then
			self._ChildPlacements:AddChildTo(child, self._Buttons);
			local LayoutParams = self._Buttons.ChildParameters:GetWritableParameters(child);
			LayoutParams.Weight = 0;
			LayoutParams.Size = self._TitleBarHeight;
		end
	end
	--Verify that the button array is correct.
	local maxn = math.max(#self._ButtonImages, #self._CornerButtons);
	for i = 1, maxn do
		local img = self._ButtonImages[i];
		local element = self._CornerButtons[i];
		if not element then
			element = Gui.new("ImageButton", self._Buttons);
			element.Image = img;
			element.LayoutParams = {Index = i; AspectRatio = 1;};
			self._CornerButtons[i] = element;
		elseif not img then
			element:Destroy();
			self._CornerButtons[i] = nil;
		else
			element.Image = img;
		end
	end

	--Defer the rest of the flowing operation to the object this wraps.
	self._Handle:_SetPPos(pos + self._PosDelta);

	--Verify that the size doesn't shrink below Vector2.new(MinimumX, MinimumY) when adding SizeDelta.
	local totSize = self._Handle:_GetHandle().AbsoluteSize - self._LastSizeDelta;
	local newSize = Vector2.new(math.max(self._MinimumX, totSize.x + self._SizeDelta.x), math.max(self._MinimumY, totSize.y + self._SizeDelta.y));
	local adjSize = newSize - totSize;
	self._LastSizeDelta = adjSize;

	self._Handle:_SetPSize(size + UDim2.new(0, adjSize.x, 0, adjSize.y));
end


function Window.new()
	local self = setmetatable(Super.new(), Window.Meta);
	--[[
		LinearLayout (_Handle)
			View (_Header)
				TextLabel (_TitleBar)
					LinearLayout (_Buttons)
			View (_Content)
				Frame (_ContentPane)
				ImageButton (_ResizableTab)
	--]]
	self._Handle = Gui.new("LinearLayout");
	self._Handle.Name = self.Name .. "_LinearLayout";
	self._Handle.AlwaysUseFrame = true;
	self._Handle.InferSize = false;
	self._Handle.Direction = Gui.Enum.LinearLayoutDirection.Vertical;
	self._Handle:ForceReflow();

	self._Header = Gui.new("View", self._Handle);
	self._Header.Name = self.Name .. "_Header";
	self._Header.LayoutParams = {Index = 1; Weight = 0; Size = self._TitleBarHeight};

	self._TitleBar = Gui.new("TextLabel", self._Header);
	self._TitleBar.Name = self.Name .. "_TitleBar";
	self._TitleBar.TextXAlignment = Enum.TextXAlignment.Left;
	self._TitleBar.Active = true;
	self._TitleBar.Draggable = true;
	self._TitleBar.BackgroundColor3 = self._TitleBarColor;

	self._Buttons = Gui.new("LinearLayout");
	self._Buttons.Name = self.Name .. "_Buttons";
	self._Buttons.Parent = self._TitleBar;
	self._Buttons.FillX = false;
	self._Buttons.Direction = Gui.Enum.LinearLayoutDirection.Horizontal;
	self._Buttons.Gravity = Gui.Enum.ViewGravity.CenterRight;

	self._Content = Gui.new("View", self._Handle);
	self._Content.Name = self.Name .. "_Content";
	self._Content.LayoutParams = {Index = 2; Weight = 1; Size = 0};
	
	self._ContentPane = Gui.new("Frame", self._Content);
	self._ContentPane.Name = self.Name .. "_ContentPane";
	self._ContentPane.BackgroundColor3 = self._ContentPaneColor;

	self._ResizableTab = Gui.new("ImageButton", self._Content);
	self._ResizableTab.Gravity = Gui.Enum.ViewGravity.BottomRight;
	self._ResizableTab.FillX = false;
	self._ResizableTab.FillY = false;
	self._ResizableTab.MinimumX = 12;
	self._ResizableTab.MinimumY = 12;
	self._ResizableTab.Image = "rbxassetid://476280714";
	self._ResizableTab.ImageRectOffset = Vector2.new(0, 0);
	self._ResizableTab.ImageRectSize = Vector2.new(12, 12);
	self._ResizableTab.BackgroundTransparency = 1;
	self._ResizableTab.Visible = self._Resizable;
	self._ResizableTab.Active = true;
	self._ResizableTab.Draggable = true;
	
	self._CornerButtons = {};

	--These events have the most ridiculous parameters. One gets the UDim2 of the location, the other gets the AbsolutePosition?

	local cxn;
	local function onMoved(input)
		self._PosDelta = self._PosDelta + self._TitleBar:_GetHandle().Position;
		self._TitleBar:_GetHandle().Position = UDim2.new(0, 0, 0, 0);
		self:ForceReflow();
	end
	self._TitleBar.DragBegin:connect(function()
		if cxn then cxn:disconnect(); cxn = nil; end
		cxn = UIS.InputChanged:connect(onMoved);
	end)
	self._TitleBar.DragStopped:connect(function()
		if cxn then cxn:disconnect(); cxn = nil; end
	end)


	local cxn, StartPosition;
	local function onMoved(inputObj)
		if not StartPosition then StartPosition = inputObj.Position; end
		local delta = inputObj.Position - StartPosition;
		StartPosition = inputObj.Position;
		self._SizeDelta = self._SizeDelta + Vector2.new(delta.x, delta.y);
		self:ForceReflow();
	end
	self._ResizableTab.DragBegin:connect(function(start)
		if cxn then cxn:disconnect(); cxn = nil; end
		cxn = UIS.InputChanged:connect(onMoved);
		StartPosition = nil;
	end)
	self._ResizableTab.DragStopped:connect(function(x, y)
		if cxn then cxn:disconnect(); cxn = nil; end
		self._SizeDelta = self._LastSizeDelta;
	end)

	self._ChildParameters = Gui.ChildProperties(Window._ChildParameters);
	self._ChildPlacements = Gui.ChildPlacements();

	return self;
end

function Gui.Test.Window_Basic()
	local sgui = Instance.new("ScreenGui", game.StarterGui);
	sgui.Name = "Window_Basic";
	local window = Gui.new("Window", sgui);
	window.MinimumX = 400;
	window.MinimumY = 300;
	window.FillX = false;
	window.FillY = false;
	window.Gravity = Gui.Enum.ViewGravity.Center;
	window.Title = "Test Window";
	window.Name = "WindowTest";
	window.Draggable = true;
	window.Resizable = true;
	window.TitleBarHeight = 36;
	window.TitleBarColor = Color3.new(0, 1, 0);
	window.ContentPaneColor = Color3.new(0, 0, 1);
	Log.AssertEqual("window.Parent", sgui, window:_GetHandle().Parent);

	local text = Gui.new("TextLabel", window);
	text.LayoutParams = {Location = Gui.Enum.WindowLocation.Content};
	text.Margin = 20;
	text.Text = "Hello, world";
	text.BackgroundColor3 = Color3.new(1, 0, 0);
end

return Window;
