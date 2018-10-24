local Utils = require(script.Parent.Parent.Parent);
local Log = Utils.Log;

local Debug = Log.new("ParseExpr:\t", false);

local PATTERNS = {
	hex = "^[ \t\r\n]*0x[0-9A-Fa-f]+";
	binary = "^[ \t\r\n]*0b[01]+";
	octal = "^[ \t\r\n]*0[0-7]+";
	decimal = "^[ \t\r\n]*[0-9]+%.?[0-9]*";
	decimal2 = "^[ \t\r\n]*%.?[0-9]+";
	operator = "^[ \t\r\n]*[-+*/^%%]";
	paren = "^[ \t\r\n]*[%(%)]";
	comma = "^[ \t\r\n]*[,]";
	variable = "^[ \t\r\n]*[a-zA-Z_][a-zA-Z_0-9]*";
};
local SPECIAL_FUNCTIONS = {
	cos = true;
	sin = true;
	tan = true;
	acos = true;
	asin = true;
	atan = true;
	atan2 = true;
	log2 = true;
	log10 = true;
	ln = true;
	exp = true;
};
local SPECIAL_VARIABLES = {
	pi = math.pi;
	inf = math.huge;
	e = 2.7182818284;
};

--[[ @brief Convert a string expression into a list of tokens.
     @param expr The expression to convert.
     @return An array containing the tokens themselves.
     @return A parallel array containing the classes of tokens. Values include number, operator, function, paren, comma, and variable.
     @note If an error occurs, the value false & a string error code will be returned.
--]]
function Tokenize(expr)
	local TokenStream = {};
	local TokenType = {};
	while #expr > 0 do
		local len = #expr;
		Debug("Searching for pattern at %s", expr);
		for i, v in pairs(PATTERNS) do
			local token = expr:match(v);
			if token then
				expr = expr:sub(#token+1);
				token = token:gsub("^[ \t\r\n]+", "");
				Debug("Pattern match at %s (%s)", token, i);
				if i=="hex" then
					i = "number";
					token = tonumber(token:sub(3), 16);
				elseif i=="binary" then
					i = "number";
					token = tonumber(token:sub(3), 2);
				elseif i=="octal" then
					i = "number";
					token = tonumber(token:sub(2), 8);
				elseif i=="decimal" or i=="decimal2" then
					i = "number";
					token = tonumber(token);
				end
				if i=="variable" then
					if SPECIAL_FUNCTIONS[token] then
						i = "function";
					elseif SPECIAL_VARIABLES[token] then
						i = "number";
						token = SPECIAL_VARIABLES[token];
					end
				end
				table.insert(TokenStream, token);
				table.insert(TokenType, i);
			end
		end
		if len == #expr then
			return false, string.format("Bad token: %s", expr);
		end
	end
	return TokenStream, TokenType;
end


--[[ @brief Returns the priority level of an operator. Unary operators always take precedence over binary operators (except for unary minus).
     @param A token including any binary operator, unary operator ('unary-', functions).
     @return A priority level for this operator where 1 is low priority, 4 is highest.
--]]
function GetPriority(token)
	if token=='+' or token=='-' or token=='unary-' then
		return 1;
	elseif token=='*' or token=="/" or token=='^' then
		return 2;
	elseif token=="^" then
		return 3;
	else
		return 4;
	end
end

--[[ @brief Searches for an operand at a given location. Unary operators are also allowed.
     @param tokens A list of all tokens.
     @param types A list of the token classes.
     @param i The index at which we start searching.
     @return operand: a table which can be injected into the table as the subject of the current operator.
     @return isOperator: whether operand itself is an operator (as is the case for unary operators).
     @return tokensConsumed: how many tokens were read in order to attain this operator.
     @return isFunction: true if operand represents a function which will likely be followed by a parentheses.
     @note When this function fails, it returns false followed by an error message.
--]]
function ParseOperand(tokens, types, i)
	local token, typ = tokens[i], types[i];
	if typ == "operator" and token=='-' or typ == 'function' then
		--We instead got a unary operator. All unary operators take precedence over binary operators.
		local newOperator = {op = (typ=='function' and token or 'unary-')};
		return newOperator, true, 1, typ == 'function';
	elseif typ == "paren" then
		if token == ')' then return false, string.format("Got unexpected close parenthesis token at index %d", i); end
		--It is possible we instead get a parenthesized argument. This is A-OK! Parse it.
		local j = i;
		local openParens = 1;
		local limit = Utils.new("WhileLoopLimiter", 1000, "parenthesisSearcher");
		while openParens > 0 and limit() do
			j = j + 1;
			if types[j] == 'paren' then
				if tokens[j] == '(' then
					openParens = openParens + 1;
				elseif tokens[j] == ')' then
					openParens = openParens - 1;
				else
					return false, string.format("Token of form %s unexpectedly given type 'paren' at index %d", tokens[j], j);
				end
			end
		end
		if j == i+1 then
			return false, string.format("Found parentheses with no inner contents at index %d", i);
		end
		local results = {TreeifyTokens(tokens, types, i + 1, j - 1)};
		if not results[1] then
			--If we have been returned something of the form false, ... we just hit an assertion. Pass it to the calling function.
			return unpack(results);
		else
			--A parenthesized statement may have any number of comma-separated values. These can be interpreted as arguments or a vector based on the parent operation. E.g., in the expression max(1, 2), max will interpret them as arguments. However, in the expression -(1, 2), the unary minus will interpret them as a vector.
			local newOperand = {op = 'identity', unpack(results)};
			return newOperand, false, j - i + 1, false;
		end
	elseif typ == 'comma' then
		return false, string.format("Unexpected comma at token %d", i), 1;
	elseif typ == 'number' then
		return {op = 'identity', [1] = token}, false, 1, false;
	elseif typ == 'variable' then
		return {op = 'variable', [1] = token}, false, 1, false;
	elseif typ == 'operator' then
		return false, string.format("Unexpected binary operator %s at token %d", token, i);
	end
end

--[[ @brief Injects an operation into the tree.
     @param opToken An operator (string) with value +, -, *, /, %, or ^.
     @return newOperation: the newly added operation.
     @return replaceRoot: true if the operation belongs at the root of the expression tree.
--]]
function InjectOperation(opToken, root)
	local newOperation = {op = opToken};
	--If it is equal* or lower priority than the current root, then we become the new root & move root to the left.
	--If it is greater priority than the previous root then we trace down the right side of the tree until we are equal* or lower priority.
	--* equal priority only matters if the operator is left-associative.
	local isLeftAssociative = opToken~='^';
	local tokenPriority = GetPriority(opToken);
	local rootPriority = GetPriority(root.op);
	if (tokenPriority < rootPriority) or (isLeftAssociative and tokenPriority == rootPriority) then
		table.insert(newOperation, root);
		return newOperation, true;
	else
		local seek = root[#root];
		local seekPriority = GetPriority(seek.op);
		local seekParent = root;
		while tokenPriority > seekPriority or (not isLeftAssociative and tokenPriority >= seekPriority) do
			seekParent = seek;
			seek = seek[#seek];
			seekPriority = GetPriority(seek.op);
		end
		table.insert(newOperation, seek);
		for i = 1, #seekParent do
			if seekParent[i] == seek then
				table.remove(seekParent, i);
				break;
			end
		end
		table.insert(seekParent, newOperation);
		return newOperation, false;
	end
end

--[[ @brief Converts a stream of tokens & their type into an expression tree.
     @param tokens A stream of tokens.
     @param types A parallel array of token types.
     @param low The lowest index we should parse from.
     @param high The highest index we should parse to.
     @return Several trees representing each comma-separated expression.
--]]
function TreeifyTokens(tokens, types, low, high)
	local roots = {};
	local function TreeToString(root, depth, s)
		if not root then return; end
		local PrintAtFinish = false;
		if not s then
			PrintAtFinish = true;
			s = {};
			depth = 0;
		end
		if type(root)=='table' then
			table.insert(s, string.rep(".   ", depth) .. root.op .. " (" .. #root .. " operands)")
			for i = 1, #root do
				TreeToString(root[i], depth + 1, s);
			end
		else
			table.insert(s, string.rep(".   ", depth) .. tostring(root));
		end
		if PrintAtFinish then
			return table.concat(s, "\n");
		end
	end
	local operation = nil; --A table which contains operands as its children and the key 'op' indicating how to evaluate it.
	local root = nil;
	local isFunction = false; --A flag set to true if the current operation is a prefix-parenthesized function.
	local i = low;
	local limit = Utils.new("WhileLoopLimiter", 2000, "treeifyer");
	while i <= high and limit() do
		local token, typ = tokens[i], types[i];
		--typ may be 'number', 'operator', 'variable', 'function', or 'paren'. operator means a binary operator except for the case of '-'.
		Debug("%s; token, type: %s, %s", i, token, typ);

		--[[
			Control flow:
				Expecting operand
					--> Parse an operand
				Expecting first operand (root)
					--> Parse an operand
				Expecting binary operator/comma
					Got binary operator
						--> Inject operation into tree & expect succeeding operand.
					Got comma
						--> Add the current expression tree to a list & start a new one.
					Got parentheses, number, or variable:
						--> Inject implicit multiplication. Re-evaluate this token.

			Parse an operand:
				Got unary minus or function
					--> Expect succeeding operand
				Got parentheses
					--> Parse it as the operand.
				Got number
					--> Treat as the operand.
				Got variable
					--> Treat as the operand.
				Got comma
					--> Error!
				Got binary operator
					--> Error!
		--]]

		if operation then
			--In this state, we are waiting for the final operand for either a binary or unary operation.
			local newOp, isOperation, consumedTokens, isFunc = ParseOperand(tokens, types, i);
			Debug("ParseOperand(tokens, types, %s) = %s, %s, %s, %s", i, newOp, isOperation, consumedTokens, isFunc);
			--> We may have encountered an error. Pass it upward.
			if not newOp then
				return newOp, isOperation;
			end
			i = i + consumedTokens -1;
			if isFunction and newOp.op == 'identity' then
				--If the operation is a prefix-parenthesized function (e.g., max(x, y) ), we should unpack newOp if it takes the form of 'identity'.
				for i, v in ipairs(newOp) do
					table.insert(operation, v);
				end
			else
				table.insert(operation, newOp);
			end
			if isOperation then
				operation = newOp;
			else
				operation = nil;
			end
			isFunction = isFunc;
		elseif root==nil then
			--In this state, we are waiting for the first operand.
			local newOp, isOperation, consumedTokens, isFunc = ParseOperand(tokens, types, i);
			--> We may have encountered an error. Pass it upward.
			if not newOp then
				return newOp, isOperation;
			end
			i = i + consumedTokens - 1;
			root = newOp;
			if isOperation then
				operation = newOp;
			else
				operation = nil;
			end
			isFunction = isFunc;
		else
			--When operation is nil, we are expecting a binary operator.
			if typ=='operator' then
				local newOperation, isRoot = InjectOperation(token, root);
				operation = newOperation;
				if isRoot then
					root = newOperation;
				end
			elseif typ=='comma' then
				Debug("Got comma. Previous tree:\n===================\n%s\n===================", TreeToString(root));
				table.insert(roots, root);
				root = nil;
				operation = nil;
			else
				Debug("Got %s ('%s') when expected binary operator", typ, token);
				--Jamming several numbers/function calls/variables together should be interpreted as a string of multiplications.
				--E.g., 5x cos x ==> 5 * x * cos(x)
				local newOperation, isRoot = InjectOperation("*", root);
				operation = newOperation;
				if isRoot then
					root = newOperation;
				end
				--We wish to reinterpret this token.
				i = i - 1;
			end
		end
		i = i + 1;
	end
	Debug("Complete Tree:\n===================\n%s\n===================", TreeToString(root));
	table.insert(roots, root);
	return unpack(roots);
end


--[[ @brief Returns the numerical value of an expession tree.
     @param tree The expression tree obtained from TreeifyTokens
     @param variables A map indicating the numerical values of several variables.
     @return The value of the tree.
--]]
function EvaluateTree(tree, variables)
	if type(tree)=='number' then
		return tree;
	end
	if tree.op == 'identity' then
		return EvaluateTree(tree[1], variables);
	elseif tree.op == "+" then
		return EvaluateTree(tree[1], variables) + EvaluateTree(tree[2], variables);
	elseif tree.op == "-" then
		return EvaluateTree(tree[1], variables) - EvaluateTree(tree[2], variables);
	elseif tree.op == "*" then
		return EvaluateTree(tree[1], variables) * EvaluateTree(tree[2], variables);
	elseif tree.op == "/" then
		return EvaluateTree(tree[1], variables) / EvaluateTree(tree[2], variables);
	elseif tree.op == "%" then
		return EvaluateTree(tree[1], variables) % EvaluateTree(tree[2], variables);
	elseif tree.op == "^" then
		return EvaluateTree(tree[1], variables) ^ EvaluateTree(tree[2], variables);
	elseif tree.op == "unary-" then
		return -EvaluateTree(tree[1], variables);
	elseif tree.op == 'cos' then
		return math.cos(EvaluateTree(tree[1], variables));
	elseif tree.op == 'sin' then
		return math.sin(EvaluateTree(tree[1], variables));
	elseif tree.op == 'tan' then
		return math.tan(EvaluateTree(tree[1], variables));
	elseif tree.op == 'acos' then
		return math.acos(EvaluateTree(tree[1], variables));
	elseif tree.op == 'asin' then
		return math.asin(EvaluateTree(tree[1], variables));
	elseif tree.op == 'atan' then
		return math.atan(EvaluateTree(tree[1], variables));
	elseif tree.op == 'atan2' then
		return math.atan2(EvaluateTree(tree[1], variables), EvaluateTree(tree[2], variables));
	elseif tree.op == 'log2' then
		return math.log(EvaluateTree(tree[1], variables)) / math.log(2);
	elseif tree.op == 'log10' then
		return math.log10(EvaluateTree(tree[1], variables));
	elseif tree.op == 'ln' then
		return math.log(EvaluateTree(tree[1], variables));
	elseif tree.op == 'exp' then
		return math.exp(EvaluateTree(tree[1], variables));
	elseif type(tree.op)=='number' then
		return tree.op;
	elseif tree.op=='variable' then
		Debug("Looking up variable: %s", tree[1]);
		return variables[tree[1]];
	else
		Log.Assert(false, "Unknown operation: %s", tree.op);
	end
end


--[[ @brief Interprets & returns the value(s) of an expression.
     @param expr The expression to compute.
     @param variables Variable substitutions to make in dictionary form.
     @return Several values indicating the numerical values of each comma-separated expression.
--]]
function InterpretExpression(expr, variables)
	local TokenStream, TokenType = Tokenize(expr);
	if not TokenStream then
		return false, TokenType;
	end

	Debug("Token Stream: ");
	for i, v in pairs(TokenStream) do
		Debug("%s", v);
	end

	--When this is done, create a tree.
	local trees = {TreeifyTokens(TokenStream, TokenType, 1, #TokenStream)};
	if not trees[1] then
		return false, trees[2];
	end
	if #trees==1 then
		return EvaluateTree(trees[1], variables);
	else
		local values = {};
		for i = 1, #trees do
			values[i] = EvaluateTree(trees[i], variables);
		end
		return unpack(values);
	end
end

return {Parse = InterpretExpression};
