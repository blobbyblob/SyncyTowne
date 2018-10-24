local Utils = require(script.Parent.Parent);
local Gui = require(script.Parent);

local ARROW_SCROLL_COUNT = 12;

local Debug = Utils.new("Log", "DropDown: ", false);
local ListenToOptions;
local DROPDOWN_SCHEMA = {
	Main = {
		Type = "Single";
		LayoutParams = {
			SetShown = function(gui, isShown)
				Debug("SetShown(%s, %s) called", gui, isShown);
			end;
			GetClickSignal = function(gui)
				Utils.Log.Error("GetClickSignal(%s) called; implementation not defined", gui);
			end;
			SetText = function(gui, text)
				Debug("SetText(%s, %s) called", gui, text);
			end;
		};
		Default = Gui.Create "Button" {
			Name = "MainButton";
			ZIndex = 2;
			LayoutParams = {
				GetClickSignal = function(gui)
					return gui.Click1;
				end;
				SetText = function(gui, text)
					gui.MainText.Text = text;
				end;
				SetShown = function(gui, isShown)
					gui.MainDropDown.Visible = not isShown;
					gui.MainText.Visible = not isShown;
					if isShown then
						gui.MainBackground.Color = Utils.Math.HexColor(0xC9C9C9);
					else
						gui.MainBackground.Color = Utils.Math.HexColor(0xF6F9FF);
					end
				end;
			};
			Gui.Create "SliceFrame" {
				Name = "MainBackground";
				Color = Utils.Math.HexColor(0xF6F9FF);
				Image = "rbxassetid://898708539";
				SliceCenter = Rect.new(Vector2.new(3, 3), Vector2.new(13, 13));
				ZIndex = 1;
			};
			Gui.Create "SliceFrame" {
				Name = "MainDropDown";
				Color = Utils.Math.HexColor(0x0C2E7D);
				Image = "rbxassetid://898750109";
--				Size = UDim2.new(1, -40, .5, -1);
--				Position = UDim2.new(1, -45, .25, 0);
				--Gui3Task: once constraints work, use an aspect ratio constraint for this.
				Position = UDim2.new(1, -19, .5, -5);
				Size = UDim2.new(0, 14, 0, 10);
				ZIndex = 2;
			};
			Gui.Create "Text" {
				Name = "MainText";
				Gravity = 5;
				Color = Utils.Math.HexColor(0x000000);
				ZIndex = 2;
			};
		};
		ParentName = "_Frame";
	};
	Option = {
		Type = "Many";
		LayoutParams = {
			Format = function(gui, text)
				Debug("Format(%s, %s) called", gui, text);
			end;
			GetClickSignal = function(gui)
				Utils.Log.Error("GetClickSignal(%s) called; implementation not defined", gui);
			end;
			SizeScale = 0;
			SizeOffset = 0;
			SizeAspect = 0;
		};
		ParentName = "_Frame";
		Default = Gui.Create "Button" {
			Name = "Option";
--			Color = Utils.Math.HexColor(0x000000);
			LayoutParams = {
				GetClickSignal = function(gui)
					return gui.Click1;
				end;
				Format = function(gui, text)
					gui.Name = "Option"..text;
					for i, v in pairs(gui:GetChildren()) do
						if v.ClassName == "Text" then
							v.Text = text;
							v.Name = "OptionLabel"..text;
						elseif v.ClassName == "Rectangle" then
							v.Name = "OptionRect"..text;
						end
					end
				end;
				SizeScale = 1;
			};
			Gui.Create "SliceFrame" {
				Name = "MainBackground";
				Color = Utils.Math.HexColor(0xF6F9FF);
				Image = "rbxassetid://898708539";
				SliceCenter = Rect.new(Vector2.new(3, 3), Vector2.new(13, 13));
				ZIndex = 1;
			};
			Gui.Create "Text" {
				Name = "OptionLabel";
				Text = "OptionLabel";
				ZIndex = 2;
				Gravity = "Center";
			};
		};
	};
	DefaultRole = "Main";
};

--Gui3Task: refactor this class so it can swap out to a scrolling drop down when the number of options exceeds some number.

local Super = Gui.SpecializedLayout;
local DropDown = Utils.new("Class", "DropDown", Super);

DropDown._Name = "DropDown";
DropDown._Index = 1;
DropDown._Options = {};
DropDown._DropDownSpacing = 0;
DropDown._DropDownCushion = 0;
DropDown._Expanded = false;

DropDown._Frame = false;
DropDown._LastPos = UDim2.new();
DropDown._LastSize = UDim2.new();
DropDown._LastExpanded = true;
DropDown._Cxns = false;
DropDown._ScreenGui = false;

function DropDown.Set:Options(v)
	self._Options = v;
	self._ChildParameters:SetRoleCount("Option", #v);
	for i = 1, #v do
		local child, params = self._ChildParameters:GetChildOfRole("Option", i);
		params.Format(child, v[i]);
	end
	ListenToOptions(self);
	self:_TriggerReflow();
end
DropDown.Get.Options = "_Options";

function DropDown.Set:Index(v)
	self._Index = v;
	local main, params = self._ChildParameters:GetChildOfRole("Main");
	params.SetText(main, self._Options[v]);
	self:_TriggerReflow();
end
DropDown.Get.Index = "_Index";

function DropDown.Set:SelectedOption(v)
	for i, option in pairs(self._Options) do
		if v==option then
			self.Index = i;
			return;
		end
	end
	Utils.Log.Warn("SelectedOption %s not valid", v);
end
function DropDown.Get:SelectedOption(v)
	if #self._Options > 0 then
		return self._Options[self._Index];
	else
		return "";
	end
end

function DropDown.Set:DropDownSpacing(v)
	self._DropDownSpacing = v;
	self:_TriggerReflow();
end
DropDown.Get.DropDownSpacing = "_DropDownSpacing";

function DropDown.Set:DropDownCushion(v)
	self._DropDownCushion = v;
	self:_TriggerReflow();
end
DropDown.Get.DropDownCushion = "_DropDownCushion";

function DropDown.Set:Expanded(v)
	self._Expanded = v;
	local main, params = self._ChildParameters:GetChildOfRole("Main");
	params.SetShown(main, self._Expanded);
	self:_TriggerReflow();
end
DropDown.Get.Expanded = "_Expanded";

function DropDown.Set:Name(v)
	self._Frame.Name = v;
	return Super.Set.Name(self, v);
end

function DropDown:_GetRbxHandle()
	return self._Frame;
end

function DropDown:_Reflow()
	Debug("DropDown._Reflow(%s) called", self);
	local pos, size = Super._Reflow(self, true);
	local coordinatesChanged = pos ~= self._LastPos or size ~= self._LastSize;
	self._LastPos = pos;
	self._LastSize = size;
	Utils.Log.AssertEqual("size.X.Scale", 0, size.X.Scale);
	Utils.Log.AssertEqual("size.Y.Scale", 0, size.Y.Scale);

	local main, mainParams = self._ChildParameters:GetChildOfRole("Main");
	main._Position = UDim2.new();
	main._Size = size;
	main:_ConditionalReflow();

	--If we are expanded or we were recently expanded, operate on the options.
	if self._Expanded ~= self._LastExpanded then
		mainParams.SetShown(main, self._Expanded);
	end
	if self._Expanded or self._LastExpanded then
		if self._Expanded and #self._Options > 0 then
			local option, optionParams = self._ChildParameters:GetChildOfRole("Option", 1);
			local aspectRatio = optionParams.SizeAspect;
			if aspectRatio ~= 0 then
				aspectRatio = 1 / aspectRatio;
			end
			local elementHeight = size.X.Offset*aspectRatio + size.Y.Offset*optionParams.SizeScale + optionParams.SizeOffset;

			local dropDown = true;
			if self._ScreenGui then
				local totalSize = self._ScreenGui.AbsoluteSize;
				local dp, ds = self._AbsolutePosition.y, self._AbsoluteSize.y;
				local sp, ss = self._ScreenGui.AbsolutePosition.y, self._ScreenGui.AbsoluteSize.y;
				local spaceBefore, spaceAfter = dp - sp, sp+ss - (dp+ds);
				local requiredSpace = self._DropDownSpacing + (#self._Options - 1) * (self._DropDownCushion + elementHeight) + elementHeight;
				Debug("Space After: %s; Required Space: %s", spaceAfter, requiredSpace);
				if spaceAfter < requiredSpace and spaceBefore > spaceAfter then
					dropDown = false;
				end
			end

			for i = 1, #self._Options do
				local option = self._ChildParameters:GetChildOfRole("Option", i);
				option._Size = UDim2.new(0, size.X.Offset, 0, elementHeight);
				if dropDown then
					option._Position = UDim2.new(0, 0, 0, size.Y.Offset + self._DropDownSpacing + (i - 1) * (elementHeight + self._DropDownCushion));
				else
					option._Position = UDim2.new(0, 0, 0, -self._DropDownSpacing - (#self._Options - i) * (elementHeight + self._DropDownCushion) - elementHeight);
				end
				option.Visible = true;
				option:_ConditionalReflow();
			end
		else
			for i = 1, #self._Options do
				local option = self._ChildParameters:GetChildOfRole("Option", i);
				option.Visible = false;
			end
		end
		self._LastExpanded = self._Expanded;
	end
end

local function ListenToMain(self)
	Debug("ListenToMain(%s) called", self);
	local main, mainParams = self._ChildParameters:GetChildOfRole("Main");
	mainParams.SetShown(main, self._Expanded);
	if self._Options[self._Index] then
		mainParams.SetText(main, self._Options[self._Index]);
	end
	self._Cxns["Main"] = mainParams.GetClickSignal(main):connect(function(x, y)
		self.Expanded = not self._Expanded;
		self:_ConditionalReflow();
	end)
end

function ListenToOptions(self)
	Debug("ListenToOptions(%s) called", self);
	local NumberOfOptions = #self._Options;
	for i = 1, NumberOfOptions do
		local element, params = self._ChildParameters:GetChildOfRole("Option", i);
		self._Cxns["Option" .. tostring(i)] = params.GetClickSignal(element):connect(function(x, y)
			self.Index = i;
			self.Expanded = false;
			self:_ConditionalReflow();
		end)
	end
end

local function GetScreenGui(self)
	local sgui = self._Parent;
	while sgui and type(sgui)=='table' do
		sgui = sgui._Parent;
	end
	while sgui and type(sgui) == 'userdata' and not sgui:IsA("LayerCollector") do
		sgui = sgui.Parent;
	end
	if sgui and sgui:IsA("LayerCollector") then
		self._ScreenGui = sgui;
	else
		self._ScreenGui = false;
	end
end

function DropDown.new()
	local self = setmetatable(Super.new(), DropDown.Meta);
	self._Frame = Instance.new("Frame");
	self._Frame.BackgroundTransparency = 1;
	self._Frame.Name = "DropDown";
	self._Cxns = Utils.new("ConnectionHolder");
	self._ChildParameters.Schema = DROPDOWN_SCHEMA;
	self._ChildParameters.RoleSourceChanged:connect(function(role)
		if role == "Main" then
			ListenToMain(self);
		elseif role == "Option" then
			ListenToOptions(self);
		end
	end)
	ListenToMain(self);
	ListenToOptions(self);
	self.AncestryChanged:connect(function()
		GetScreenGui(self);
	end)
	GetScreenGui(self);
	return self;
end

function Gui.Test.DropDown_Default(sgui, cgui)
	local s = DropDown.new();
	s.Size = UDim2.new(0, 150, 0, 25);
	s.Position = UDim2.new(.5, -75, .5, -12);
	s.Parent = sgui;
end

function Gui.Test.DropDown_Basic(sgui, cgui)
	local s = DropDown.new();
	s.Size = UDim2.new(0, 150, 0, 25);
	s.Position = UDim2.new(.5, -75, .5, -12);
	s.Options = {"A", "B", "C", "D", "E"};
	s.DropDownSpacing = 2;
	s.DropDownCushion = 2;
	s.Parent = cgui;
	s.SelectedOption = "C";
end

function Gui.Test.DropDown_NearBottom(sgui, cgui)
	local s = DropDown.new();
	s.Size = UDim2.new(0, 150, 0, 25);
	s.Position = UDim2.new(.5, -75, 1, -50);
	s.Options = {"A", "B", "C", "D", "E"};
	s.DropDownSpacing = 2;
	s.DropDownCushion = 2;
	s.Expanded = true;
	s.Parent = cgui;
end

return DropDown;
