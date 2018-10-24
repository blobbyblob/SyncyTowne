--Many thanks to NoliCAIKS for deducing this mystery!

local ChatColors = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Earth green"),
	BrickColor.new("Bright violet"),
	BrickColor.new("Bright orange"),
	BrickColor.new("Bright yellow"),
	BrickColor.new("Light reddish violet"),
	BrickColor.new("Brick yellow"),
}

local function GetNameValue(pName)
	local value = 0
	for index = 1, #pName do
		local cValue = string.byte(string.sub(pName, index, index))
		local reverseIndex = #pName - index + 1
		if #pName%2 == 1 then
			reverseIndex = reverseIndex - 1	
		end
		if reverseIndex%4 >= 2 then
			cValue = -cValue
		end
			value = value + cValue
	end
	return value%8
end

function ComputeChatColor(pName)
	return ChatColors[GetNameValue(pName) + 1].Color
end

return ComputeChatColor;
