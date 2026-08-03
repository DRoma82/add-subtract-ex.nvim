-- Core logic for add-subtract-ex: act on the earliest target at or after the
-- cursor. Word pairs and symbol pairs invert to their counterpart, numbers use
-- the native Ctrl-a/Ctrl-x command, and letters shift alphabetically without
-- cycling. Whichever appears first wins, matching how native Ctrl-a targets the
-- nearest number rather than always preferring letters.

local M = {}

-- Return `target` cased like `source` (all lower, all UPPER, or Title case).
local function match_case(source, target)
	if source == source:upper() and source ~= source:lower() then
		return target:upper()
	end
	if source:sub(1, 1):upper() .. source:sub(2):lower() == source then
		return target:sub(1, 1):upper() .. target:sub(2)
	end
	return target
end

local function shifted_letter(letter, step)
	local byte = letter:byte()
	local lower_a = ("a"):byte()
	local lower_z = ("z"):byte()
	local upper_a = ("A"):byte()
	local upper_z = ("Z"):byte()

	if lower_a <= byte and byte <= lower_z then
		return string.char(math.min(lower_z, math.max(lower_a, byte + step)))
	end

	if upper_a <= byte and byte <= upper_z then
		return string.char(math.min(upper_z, math.max(upper_a, byte + step)))
	end
end

local function native_number(native_key)
	-- Preserve native Ctrl-a/Ctrl-x number behavior, including any pending count.
	-- The "x" flag runs the keys synchronously so direct increment()/decrement()
	-- API calls have the buffer updated by the time they return, like the other paths.
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(vim.v.count1 .. native_key, true, false, true), "nx", false)
end

-- True when the character at `col` belongs to a 0x.../0b... literal, so native
-- Ctrl-a/Ctrl-x handles the number instead of the letter branch shifting a hex
-- digit into garbage (e.g. 0xFF with the cursor on F would become 0xGF).
-- Underscores are tolerated as digit-group separators (e.g. 0xFF_FF); note that
-- native Ctrl-a stops at the underscore, so only the group at the cursor moves.
local function in_number_literal(line, col)
	local start_col = col
	while start_col > 1 and line:sub(start_col - 1, start_col - 1):match("[%w_]") do
		start_col = start_col - 1
	end
	local end_col = col
	while end_col < #line and line:sub(end_col + 1, end_col + 1):match("[%w_]") do
		end_col = end_col + 1
	end
	local token = line:sub(start_col, end_col)
	return token:match("^0[xX][%x_]+$") ~= nil or token:match("^0[bB][01_]+$") ~= nil
end

-- Earliest symbol pair whose match still covers or follows the cursor.
local function find_symbol(symbols, line, cursor_col)
	local best_col, best_end, best_symbol
	for symbol in pairs(symbols) do
		local from = 1
		while true do
			local start_col, end_col = line:find(symbol, from, true)
			if not start_col then
				break
			end
			if cursor_col <= end_col then
				-- Prefer the earliest match; on a tie prefer the longer symbol so a
				-- user-added "+" cannot shadow the built-in "++".
				if not best_col or start_col < best_col or (start_col == best_col and end_col > best_end) then
					best_col, best_end, best_symbol = start_col, end_col, symbol
				end
				break
			end
			from = end_col + 1
		end
	end
	return best_col, best_end, best_symbol
end

-- Act on the current line. `config` provides `words`/`symbols` lookups and a
-- `letters` flag; `direction` is 1 to add or -1 to subtract.
function M.act(config, direction)
	local native_key = direction < 0 and "<C-x>" or "<C-a>"

	-- Work with the current line directly so replacing a word does not disturb other text.
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_col = cursor[2] + 1

	-- Earliest word pair whose word still covers or follows the cursor.
	local word_col, word_end, word_repl
	for start_col, word, end_col in line:gmatch("()%f[%w_](%a+)%f[^%w_]()") do
		-- end_col is the position after the word, so the word covers up to end_col - 1.
		if cursor_col < end_col then
			local target = config.words[word:lower()]
			if target then
				word_col, word_end, word_repl = start_col, end_col, match_case(word, target)
				break
			end
		end
	end

	-- Earliest symbol pair, number, and letter at or after the cursor.
	local sym_col, sym_end, sym_symbol = find_symbol(config.symbols, line, cursor_col)
	local num_col = line:find("%d", cursor_col) or math.huge
	local letter_col = config.letters and (line:find("[A-Za-z]", cursor_col) or math.huge) or math.huge
	word_col = word_col or math.huge
	sym_col = sym_col or math.huge

	local earliest = math.min(word_col, sym_col, num_col, letter_col)

	if earliest == math.huge then
		-- Nothing actionable on the line, so still let native Ctrl-a/Ctrl-x try.
		native_number(native_key)
		return
	end

	-- Word/symbol replacements win ties against their own leading character.
	if word_col == earliest then
		vim.api.nvim_set_current_line(line:sub(1, word_col - 1) .. word_repl .. line:sub(word_end))
		vim.api.nvim_win_set_cursor(0, { cursor[1], word_col - 1 })
		return
	end

	if sym_col == earliest then
		-- In sign-aware mode a +/- directly before a digit is a number sign, so let
		-- native Ctrl-a/Ctrl-x increment the signed number instead of flipping it.
		if
			config.sign_aware
			and (sym_symbol == "+" or sym_symbol == "-")
			and line:sub(sym_end + 1, sym_end + 1):match("%d")
		then
			native_number(native_key)
			return
		end

		local replacement = config.symbols[sym_symbol]
		vim.api.nvim_set_current_line(line:sub(1, sym_col - 1) .. replacement .. line:sub(sym_end + 1))
		vim.api.nvim_win_set_cursor(0, { cursor[1], sym_col - 1 })
		return
	end

	if num_col == earliest then
		native_number(native_key)
		return
	end

	-- A hex digit inside a 0x.../0b... literal belongs to native number handling.
	if in_number_literal(line, letter_col) then
		native_number(native_key)
		return
	end

	local step = direction * vim.v.count1
	local replacement = shifted_letter(line:sub(letter_col, letter_col), step)

	vim.api.nvim_set_current_line(line:sub(1, letter_col - 1) .. replacement .. line:sub(letter_col + 1))
	vim.api.nvim_win_set_cursor(0, { cursor[1], letter_col - 1 })
end

return M
