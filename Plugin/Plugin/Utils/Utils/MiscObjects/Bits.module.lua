--[[

A bitstream library. Supports typical bit operations.

--]]

local Utils = require(script.Parent.Parent);

--[[ @brief Iterate on a string bit-by-bit.
--]]
local function biterate(s)
	local charIndex = 0;
	local bitIndex = 9;
	local n = 0;
	return function()
		if bitIndex > 8 then
			bitIndex = 1;
			charIndex = charIndex + 1;
			n = string.byte(s:sub(charIndex, charIndex));
		end
		if charIndex > #s or charIndex == #s and n == 0 then
			return nil;
		end
		local v = n % 2;
		n = math.floor(n / 2);
		bitIndex = bitIndex + 1;
		return v;
	end;
end

local function _And(stream1, stream2)
	local s = {};
	local i1, i2 = biterate(stream1), biterate(stream2);
	local i, j;
	local k, l = 1, 0;
	while true do
		i, j = i1(), i2();
		if k == 256 or (not i or not j) then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i or not j then
			break;
		end
		if i==1 and j==1 then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local function _Or(stream1, stream2)
	local s = {};
	local i1, i2 = biterate(stream1), biterate(stream2);
	local i, j;
	local k, l = 1, 0;
	while true do
		i, j = i1(), i2();
		if k == 256 or (not i and not j) then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i and not j then
			break;
		end
		if i==1 or j==1 then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local function _Not(stream)
	local s = {};
	local iter = biterate(stream);
	local i;
	local k, l = 1, 0;
	while true do
		i = iter();
		if k == 256 or not i then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i then
			break;
		end
		if i==0 then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local function _Xor(stream1, stream2)
	local s = {};
	local i1, i2 = biterate(stream1), biterate(stream2);
	local i, j;
	local k, l = 1, 0;
	while true do
		i, j = i1(), i2();
		if k == 256 or (not i and not j) then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i and not j then
			break;
		end
		if (i or 0) ~= (j or 0) then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local function _LShift(stream, distance)
	local s = {};
	local iter = biterate(stream);
	local k, l = 1, 0;
	for i = 1, distance do
		if k == 256 then
			k = 1;
			table.insert(s, l);
		end
		k = k * 2;
	end
	while true do
		local i = iter();
		if k == 256 or (not i) then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i then
			break;
		end
		if i == 1 then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local function _RShift(stream, distance)
	local s = {};
	local iter = biterate(stream);
	local k, l = 1, 0;
	for i = 1, distance do
		iter();
	end
	while true do
		local i = iter();
		if k == 256 or (not i) then
			k = 1;
			table.insert(s, l);
			l = 0;
		end
		if not i then
			break;
		end
		if i == 1 then
			l = l + k;
		end
		k = k * 2;
	end
	return string.char(unpack(s));
end

local Bits = Utils.new("Class", "Bits");

Bits._bits = ""; --lowest indices are least significant

function Bits:And(other)
	return Bits.new(_And(self._bits, other._bits));
end

function Bits:Or(other)
	return Bits.new(_Or(self._bits, other._bits));
end

function Bits:Not()
	return Bits.new(_Not(self._bits));
end

function Bits:Xor(other)
	return Bits.new(_Xor(self._bits, other._bits));
end

function Bits:Shift(leftDistance)
	if leftDistance > 0 then
		return Bits.new(_LShift(self._bits, leftDistance));
	elseif leftDistance < 0 then
		return Bits.new(_RShift(self._bits, -leftDistance));
	else
		return self;
	end
end

function Bits:ToNumber()
	local n = 0;
	local i = 1;
	for x in biterate(self._bits) do
		if x==1 then
			n = n + i;
		end
		i = i * 2;
	end
	return n;
end

local A = string.byte('A');
local ZERO = string.byte('0');
function Bits:ToHex()
	local s = {};
	for c in string.gmatch(self._bits, ".") do
		local v = string.byte(c);
		local r = v % 16;
		if 0 <= r and r <= 9 then
			r = r + ZERO;
		else
			r = r + A - 10;
		end
		table.insert(s, 1, r);
		r = math.floor(v / 16);
		if 0 <= r and r <= 9 then
			r = r + ZERO;
		else
			r = r + A - 10;
		end
		table.insert(s, 1, r);
	end
	return "0x" .. string.char(unpack(s));
end

Bits.__add = Bits.Or;
Bits.__mult = Bits.And;
Bits.__pow = Bits.Xor;
Bits.__tostring = Bits.ToHex;

function Bits:__eq(other)
	return self._bits == other._bits;
end

function Bits.FromBinary(n)
	local s = {};
	local j = 1;
	local k = 0;
	for i, v in pairs(n) do
		if v then
			k = k + j;
		end
		j = j * 2;
		if j == 256 then
			table.insert(s, k);
			k = 0;
			j = 1;
		end
	end
	if k > 0 then
		table.insert(s, k);
	end
	return Bits.new(string.char(unpack(s)));
end

function Bits.FromInt(n)
	local s = {};
	while n > 0 do
		table.insert(s, n % 256);
		n = math.floor(n / 256);
	end
	return Bits.new(string.char(unpack(s)));
end

function Bits.new(src)
	local self = setmetatable({}, Bits.Meta);
	self._bits = src;
	return self;
end

function Bits.test()
	local b = Bits.new;
	local n = Bits.FromInt;
	Utils.Log.AssertEqual("FromInt", b("\000\010\100"), Bits.FromInt(0 + 10 * 256 + 100 * 256 * 256));
	Utils.Log.AssertEqual("FromBinary", n(0xA), Bits.FromBinary({false, true, false, true}));
	Utils.Log.AssertEqual("And", n(0xAACCAA), n(0xABCDEF):And(n(0xFEDCBA)));
	Utils.Log.AssertEqual("Or", n(0xFFDDFF), n(0xABCDEF):Or(n(0xFEDCBA)));
	Utils.Log.AssertEqual("Not", n(0x543210), n(0xABCDEF):Not());
	Utils.Log.AssertEqual("Xor", n(0x551155), n(0xABCDEF):Xor(n(0xFEDCBA)));
	Utils.Log.AssertEqual("LShift", n(0xABCDEF0), n(0xABCDEF):Shift(4));
	Utils.Log.AssertEqual("RShift", n(0xABCDE), n(0xABCDEF):Shift(-4));
	Utils.Log.AssertEqual("ToNumber", 0xABCDEF, n(0xABCDEF):ToNumber());
end
Bits.Test = Bits.test;

return Bits;
