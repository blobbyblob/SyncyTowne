local Utils = require(script.Parent.Parent.Parent.Utils);
local Debug = Utils.new("Log", "Helpers: ", false);
local ImageButtonWrapper = require(script.ImageButton);

local module = {}

local COPY_PROPERTIES = {
	"Position", "Size", "LayoutOrder", "Name", "Parent", "AnchorPoint",
};
local IMAGE_COPY_PROPERTIES = {
	"TileSize", "SliceCenter", "ScaleType", "Image", "ImageRectOffset", "ImageRectSize", "ImageTransparency", "ImageColor3",
};
local TEXT_COPY_PROPERTIES = {
	"Text", "Font", "TextColor3", "TextScaled", "TextSize", "TextStrokeColor3", "TextStrokeTransparency", "TextTransparency", "TextTruncate", "TextWrapped", "TextXAlignment", "TextYAlignment",
};
local IMAGE_RECT_PROPERTIES = {
	"Image", "ImageRectSize", "ImageRectOffset", "ImageColor3",
};

local function Copy(from, to, properties)
	for i, property in pairs(properties) do
		to[property] = from[property];
	end
end

--[[ @brief Iterates through a GUI, converting all image buttons into a common style, and making them listen for enable/disable tokens.
	@param gui The GUI to traverse through.
	@return gui The same GUI.
--]]
function module.FixImageButtons(gui, maid)
	local buttons = {};
	for i, v in pairs(gui:GetDescendants()) do
		if v:IsA("ImageButton") or v:IsA("TextButton") then
			if not buttons[v.Name] then
				Debug("Adding Button %s", v.Name);
				local button;
				if v:IsA("ImageButton") then
					button = ImageButtonWrapper.new("Image");
					Copy(v, button.Button, IMAGE_COPY_PROPERTIES);
					if v.ImageRectSize.X > 0 and v.ImageRectSize.Y > 0 then
						local label = Utils.Misc.Create{
							ClassName = "ImageLabel";
							Name = "CenteredImage";
							Size = UDim2.new(1, 0, 1, 0);
							Position = UDim2.new(.5, 0, .5, 0);
							AnchorPoint = Vector2.new(.5, .5);
							{
								ClassName = "UISizeConstraint";
								MaxSize = v.ImageRectSize;
							};
							{
								ClassName = "UIAspectRatioConstraint";
								AspectRatio = v.ImageRectSize.X / v.ImageRectSize.Y;
							};
						};
						label.BackgroundTransparency = 1;
						Copy(v, label, IMAGE_RECT_PROPERTIES);
						button.Button.Image = "";
						label.Parent = button.Button;
					end
				else
					button = ImageButtonWrapper.new("Text");
					Copy(v, button.Button, TEXT_COPY_PROPERTIES);
				end
				Copy(v, button.Button, COPY_PROPERTIES);
				v.Parent = nil;
				for i, child in pairs(v:GetChildren()) do
					child.Parent = button.Button;
				end
				buttons[v.Name] = button;
			else
				Utils.Log.Warn("Gui %s contains two Button descendants with same name: %s", gui, v.Name);
			end
		end
	end
	return gui, buttons;
end

return module
