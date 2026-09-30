-- Core logic for add-subtract-ex: act on the earliest target at or after the
-- cursor. Word pairs and symbol pairs invert to their counterpart, dates and
-- times step the part under the cursor, numbers use
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
	-- :normal! runs synchronously and only its own keys, leaving any pending
	-- typeahead (a macro, a mapping) for after this call.
	vim.cmd.normal({ vim.v.count1 .. vim.keycode(native_key), bang = true })
	return true
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
local function find_symbol(symbols, line, cursor_col, min_start)
	local best_col, best_end, best_symbol
	for symbol in pairs(symbols) do
		local from = 1
		while true do
			local start_col, end_col = line:find(symbol, from, true)
			if not start_col then
				break
			end
			if cursor_col <= end_col and (not min_start or start_col >= min_start) then
				-- Prefer the earliest match; on a tie prefer the longer symbol so a
				-- user-added "+" cannot shadow the built-in "++".
				if not best_col or start_col < best_col or (start_col == best_col and end_col > best_end) then
					best_col, best_end, best_symbol = start_col, end_col, symbol
				end
				break
			end
			from = min_start and start_col + 1 or end_col + 1
		end
	end
	return best_col, best_end, best_symbol
end

local function days_in_month(year, month)
	if month == 2 then
		local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
		return leap and 29 or 28
	end
	return ({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[month]
end

-- Earliest date (ISO yyyy-M-d, or d/M/y[y]yy in `dates.format` order) that
-- covers or follows the cursor. Returns nil when none; `date.valid` is false
-- for date-shaped text that is not a real calendar date.
local function find_date(dates, line, cursor_col, min_start)
	local best
	local function consider(start_col, end_col, sep, order, a, b, c)
		if cursor_col >= end_col or (min_start and start_col < min_start) or (best and best.start_col <= start_col) then
			return
		end
		local date = { start_col = start_col, end_col = end_col, kind = "date", sep = sep, order = order, text = {} }
		local col = start_col
		for i, raw in ipairs({ a, b, c }) do
			date.text[order[i]] = raw
			date[order[i] .. "_col"] = col
			col = col + #raw + 1
		end
		local year = tonumber(date.text.y)
		if #date.text.y == 2 then
			date.lo = 1900 + dates.century_pivot
			year = year < dates.century_pivot and 2000 + year or 1900 + year
		else
			date.lo = 0
		end
		date.hi = date.lo == 0 and 9999 or date.lo + 99
		date.y, date.m, date.d = year, tonumber(date.text.m), tonumber(date.text.d)
		date.valid = 1 <= date.m and date.m <= 12 and 1 <= date.d and date.d <= days_in_month(date.y, date.m)
		best = date
	end

	for s, y, m, d, e in line:gmatch("%f[%d]()(%d%d%d%d)%-(%d%d?)%-(%d%d?)()%f[%D]") do
		consider(s, e, "-", { "y", "m", "d" }, y, m, d)
	end
	local slash_order = dates.format == "mdy" and { "m", "d", "y" } or { "d", "m", "y" }
	for s, a, b, y, e in line:gmatch("%f[%d]()(%d%d?)/(%d%d?)/(%d+)()%f[%D]") do
		if #y == 2 or #y == 4 then
			consider(s, e, "/", slash_order, a, b, y)
		end
	end
	return best
end

-- Step the part of `date` under the cursor (a separator belongs to the part
-- before it; before the date uses `dates.default_part`). Returns the new text
-- and the column where the stepped part now starts.
local function stepped_date(dates, date, cursor_col, step)
	local part = dates.default_part:sub(1, 1)
	for _, key in ipairs(date.order) do
		if date[key .. "_col"] <= cursor_col then
			part = key
		end
	end

	local y, m, d = date.y, date.m, date.d
	if part == "d" then
		-- ponytail: walks month by month, fine unless counts reach the millions.
		d = d + step
		while d > days_in_month(y, m) do
			d = d - days_in_month(y, m)
			m = m + 1
			if m > 12 then
				m, y = 1, y + 1
			end
		end
		while d < 1 do
			m = m - 1
			if m < 1 then
				m, y = 12, y - 1
			end
			d = d + days_in_month(y, m)
		end
	elseif part == "m" then
		local months = y * 12 + m - 1 + step
		y, m = math.floor(months / 12), months % 12 + 1
	else
		y = y + step
	end
	if y < date.lo or y > date.hi then
		local low = y < date.lo
		y = low and date.lo or date.hi
		if part == "m" then
			m = low and 1 or 12
		elseif part == "d" then
			m, d = low and 1 or 12, low and 1 or 31
		end
	end
	d = math.min(d, days_in_month(y, m))

	local values = { y = y, m = m, d = d }
	local pieces, part_col, col = {}, date.start_col, date.start_col
	for i, key in ipairs(date.order) do
		local width = #date.text[key]
		if key ~= "y" and dates.pad then
			width = 2
		end
		pieces[i] = ("%0" .. width .. "d"):format(key == "y" and width == 2 and y % 100 or values[key])
		if key == part then
			part_col = col
		end
		col = col + #pieces[i] + 1
	end
	return table.concat(pieces, date.sep), part_col
end

-- Earliest time (HH:mm[:ss], or h:mm[:ss] with an AM/PM suffix) that covers or
-- follows the cursor. Unpadded hours need AM/PM so ratios like 3:16 are skipped.
-- `time.valid` is false for time-shaped text that is not a real time.
local function find_time(times, line, cursor_col, min_start)
	for start_col, first, second, e in line:gmatch("%f[%d]()(%d%d?):(%d%d)()") do
		local third = line:match("^:(%d%d)", e)
		local digits_end = third and e + 3 or e
		local space, meridiem, end_col = line:match("^( ?)([AaPp][Mm])%f[^%w_]()", digits_end)
		end_col = end_col or digits_end
		if
			cursor_col < end_col
			and (not min_start or start_col >= min_start)
			and not line:sub(digits_end, digits_end):match("%d")
			and (meridiem or #first == 2)
		then
			local keys = (third or meridiem or times.two_part ~= "ms") and { "h", "m", "s" } or { "m", "s" }
			local time = { start_col = start_col, end_col = end_col, kind = "time", text = {}, parts = {} }
			local col = start_col
			for i, raw in ipairs({ first, second, third }) do
				time.text[keys[i]] = raw
				time.parts[i] = { key = keys[i], col = col }
				col = col + #raw + 1
			end
			local h, m, s = tonumber(time.text.h or 0), tonumber(time.text.m), tonumber(time.text.s or 0)
			if meridiem then
				time.meridiem, time.space = meridiem, space
				table.insert(time.parts, { key = "p", col = digits_end + #space })
				time.valid = 1 <= h and h <= 12
				h = h % 12 + (meridiem:lower() == "pm" and 12 or 0)
			else
				time.valid = h < 24
			end
			time.valid = time.valid and m < 60 and s < 60
			time.seconds = h * 3600 + m * 60 + s
			time.wrap = time.text.h and 86400 or 3600
			return time
		end
	end
end

-- Step the part of `time` under the cursor on a wrapping clock (24h, or one
-- hour for mm:ss). The AM/PM part toggles by 12 hours and ignores the count.
local function stepped_time(times, time, cursor_col, step)
	local part = time.parts[1].key
	for _, p in ipairs(time.parts) do
		if p.key == times.default_part:sub(1, 1) then
			part = p.key
		end
	end
	for _, p in ipairs(time.parts) do
		if p.col <= cursor_col then
			part = p.key
		end
	end

	local delta = part == "p" and 43200 or step * ({ h = 3600, m = 60, s = 1 })[part]
	local seconds = (time.seconds + delta) % time.wrap
	local values = { h = math.floor(seconds / 3600), m = math.floor(seconds / 60) % 60, s = seconds % 60 }
	if time.meridiem then
		values.h = (values.h + 11) % 12 + 1
	end

	local pieces, part_col, col = {}, time.start_col, time.start_col
	for i, p in ipairs(time.parts) do
		if p.key == "p" then
			local letter = seconds >= 43200 and "p" or "a"
			if time.meridiem:sub(1, 1):match("%u") then
				letter = letter:upper()
			end
			pieces[i] = time.space .. letter .. time.meridiem:sub(2)
			col = col - 1 + #time.space
		else
			pieces[i] = ("%0" .. #time.text[p.key] .. "d"):format(values[p.key])
		end
		if p.key == part then
			part_col = col
		end
		col = col + #pieces[i] + 1
	end
	local digits = table.concat(pieces, ":", 1, time.meridiem and #pieces - 1 or #pieces)
	return digits .. (time.meridiem and pieces[#pieces] or ""), part_col
end

local function number_span(config, line, cursor_col, min_start)
	local formats = "," .. vim.bo.nrformats .. ","
	local from = 1
	while true do
		local start_col = line:find("%d", from)
		if not start_col then
			return
		end
		local tail = line:sub(start_col)
		local literal = formats:find(",hex,", 1, true) and tail:match("^0[xX]%x+")
			or formats:find(",bin,", 1, true) and tail:match("^0[bB][01]+")
		local text = literal or tail:match("^%d+")
		local end_col = start_col + #text - 1
		if cursor_col <= end_col then
			local sign = line:sub(start_col - 1, start_col - 1)
			if
				(
					sign == "-"
					and not literal
					and not formats:find(",unsigned,", 1, true)
					and (config.sign_aware or not config.symbols[sign])
				) or (config.sign_aware and (sign == "+" or sign == "-"))
			then
				start_col = start_col - 1
			end
			if not min_start or start_col >= min_start then
				return { kind = "number", start_col = start_col, end_col = end_col }
			end
		end
		from = end_col + 1
	end
end

local function find_target(config, line, cursor_col, last_col, min_start)
	-- Markdown task checkbox wins over the list marker before it ("-" is a symbol pair).
	if vim.bo.filetype:find("markdown") then
		local box_col, box_end = line:match("^%s*[-*+]%s+()%[[ xX]%]()")
		if not box_col then
			box_col, box_end = line:match("^%s*%d+[.)]%s+()%[[ xX]%]()")
		end
		if box_col and cursor_col < box_end and (not last_col or box_col <= last_col) then
			local mark = line:sub(box_col + 1, box_col + 1) == " " and "x" or " "
			return { start_col = box_col, end_col = box_end - 1, replacement = "[" .. mark .. "]" }
		end
	end

	-- Earliest word pair whose word still covers or follows the cursor.
	local word_col, word_end, word_repl
	for start_col, word, end_col in line:gmatch("()%f[%w_](%a+)%f[^%w_]()") do
		-- end_col is the position after the word, so the word covers up to end_col - 1.
		if cursor_col < end_col and (not min_start or start_col >= min_start) then
			local target = config.words[word:lower()]
			if target then
				word_col, word_end, word_repl = start_col, end_col, match_case(word, target)
				break
			end
		end
	end

	-- Earliest symbol pair, number, and letter at or after the cursor.
	local sym_col, sym_end, sym_symbol = find_symbol(config.symbols, line, cursor_col, min_start)
	local date = config.dates and find_date(config.dates, line, cursor_col, min_start)
	local date_col = date and date.start_col or math.huge
	local time = config.times and find_time(config.times, line, cursor_col, min_start)
	local time_col = time and time.start_col or math.huge
	local num_col = line:find("%d", cursor_col) or math.huge
	local letter_col = config.letters and (line:find("[A-Za-z]", cursor_col) or math.huge) or math.huge
	word_col = word_col or math.huge
	sym_col = sym_col or math.huge

	local earliest = math.min(word_col, sym_col, date_col, time_col, num_col, letter_col)

	if earliest == math.huge then
		return
	end

	-- Word/symbol replacements win ties against their own leading character.
	if word_col == earliest then
		return { start_col = word_col, end_col = word_end - 1, replacement = word_repl }
	end

	if sym_col == earliest then
		-- In sign-aware mode a +/- directly before a digit is a number sign, so let
		-- native Ctrl-a/Ctrl-x increment the signed number instead of flipping it.
		if
			config.sign_aware
			and (sym_symbol == "+" or sym_symbol == "-")
			and line:sub(sym_end + 1, sym_end + 1):match("%d")
		then
			return number_span(config, line, sym_col, min_start)
		end

		return { start_col = sym_col, end_col = sym_end, replacement = config.symbols[sym_symbol] }
	end

	local stamp, stepped, stamp_config
	if date_col == earliest then
		stamp, stepped, stamp_config = date, stepped_date, config.dates
	elseif time_col == earliest then
		stamp, stepped, stamp_config = time, stepped_time, config.times
	end
	if stamp then
		stamp.end_col = stamp.end_col - 1
		stamp.stepped, stamp.config = stepped, stamp_config
		return stamp
	end

	if num_col == earliest or in_number_literal(line, letter_col) then
		return number_span(config, line, cursor_col, min_start)
	end

	return { kind = "letter", start_col = letter_col, end_col = letter_col }
end

local function replacement_for(target, line, cursor_col, step)
	if target.kind == "date" or target.kind == "time" then
		if not target.valid then
			local text = line:sub(target.start_col, target.end_col)
			vim.notify(("add-subtract-ex: %s is not a valid %s"):format(text, target.kind), vim.log.levels.WARN)
			return
		end
		return target.stepped(target.config, target, cursor_col, step)
	end
	if target.kind == "letter" then
		return shifted_letter(line:sub(target.start_col, target.end_col), step), target.start_col
	end
	return target.replacement, target.start_col
end

-- Returns true when native Ctrl-a/Ctrl-x ran, so normal-mode dot-repeat can rearm.
function M.act(config, direction)
	local line = vim.api.nvim_get_current_line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_col = cursor[2] + 1
	local target = find_target(config, line, cursor_col)
	if not target or target.kind == "number" then
		return native_number(direction < 0 and "<C-x>" or "<C-a>")
	end
	local replacement, part_col = replacement_for(target, line, cursor_col, direction * vim.v.count1)
	if replacement then
		vim.api.nvim_set_current_line(line:sub(1, target.start_col - 1) .. replacement .. line:sub(target.end_col + 1))
		vim.api.nvim_win_set_cursor(0, { cursor[1], part_col - 1 })
	end
end

function M.visual(config, direction, progressive)
	local mode, count = vim.fn.mode(), vim.v.count1
	local regions = vim.fn.getregionpos(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode, eol = true })
	-- Resolve partial tabs and virtual padding before leaving visual mode.
	if mode ~= "V" then
		for _, region in ipairs(regions) do
			local first, last = region[1], region[2]
			local row = first[2]
			local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
			if line:match("^%s*$") then
				region.prefix = first[3] == 1 and first[4] == 0 and ""
					or vim.fn.getregion({ 0, row, 1, 0 }, first, { type = "v", exclusive = true })[1]
				local after = last[4] > 0 and last or { 0, row, last[3] + 1, 0 }
				region.suffix = after[3] > #line and ""
					or vim.fn.getregion(after, { 0, row, #line + 1, 0 }, { type = "v", exclusive = true })[1]
			end
		end
	end
	local previous
	if regions[1] and regions[1][1][2] > 1 then
		local first, last = regions[1][1], regions[1][2]
		local row = first[2] - 1
		if mode == "V" then
			previous = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
		else
			local function above_position(pos, ending)
				local cells = vim.fn.virtcol({ pos[2], pos[3], pos[4] }, true)
				local vcol = cells[ending and 2 or 1]
				if ending and pos[4] > 0 then
					vcol = vcol - 1
				end
				local col = math.max(1, vim.fn.virtcol2col(0, row, vcol))
				local base = vim.fn.virtcol({ row, col }, true)[1]
				return { 0, row, col, math.max(0, vcol - base) }
			end
			previous = vim.fn.getregion(above_position(first, false), above_position(last, true), {
				type = "v",
				exclusive = false,
			})[1]
		end
	end
	vim.cmd.normal({ vim.keycode("<Esc>"), bang = true })
	local changed, index = false, 0
	local function join_undo()
		if changed then
			vim.cmd.undojoin()
		end
	end
	local function set_line(row, text)
		join_undo()
		vim.api.nvim_buf_set_lines(0, row - 1, row, false, { text })
		changed = true
	end

	for _, region in ipairs(regions) do
		local first, last = region[1], region[2]
		local row = first[2]
		local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
		local start_col = first[3] + (first[3] > #line and first[4] or 0)
		local end_col = last[3] + (last[3] > #line and math.max(0, last[4] - 1) or 0)
		if mode == "V" then
			start_col, end_col = 1, #line
		end
		if line:match("^%s*$") and previous and previous ~= "" then
			local prefix, suffix = region.prefix or "", region.suffix or ""
			line = prefix .. previous .. suffix
			start_col, end_col = #prefix + 1, #prefix + #previous
			set_line(row, line)
		end

		local targets, col = {}, start_col
		-- ponytail: rescans per target; index matches if long lines become slow.
		while col <= end_col do
			local target = find_target(config, line, col, end_col, col > start_col and col or nil)
			if not target or target.start_col > end_col then
				break
			end
			local part_col = math.max(start_col, target.start_col)
			-- Full timestamps use their configured default, not their leading year/hour.
			if start_col <= target.start_col then
				part_col = target.start_col - 1
			end
			local step = direction * count * (progressive and index + 1 or 1)
			if target.kind == "number" then
				target.step = step
			else
				target.replacement = replacement_for(target, line, part_col, step)
			end
			if target.kind == "number" or target.replacement then
				index = index + 1
				targets[#targets + 1] = target
			end
			col = target.end_col + 1
		end

		-- Apply right-to-left so changing token lengths or signs cannot retarget later edits.
		for i = #targets, 1, -1 do
			local target = targets[i]
			local old_length = #line
			if target.kind == "number" then
				vim.api.nvim_win_set_cursor(0, { row, target.start_col - 1 })
				local width = target.end_col - target.start_col
				local selection = "v" .. (width > 0 and width .. "l" or "")
				local key = target.step < 0 and "<C-x>" or "<C-a>"
				join_undo()
				-- The captured region already respects 'selection'; the numeric token must be complete.
				local saved_selection = vim.o.selection
				vim.o.selection = "inclusive"
				local ok, err =
					pcall(vim.cmd.normal, { selection .. math.abs(target.step) .. vim.keycode(key), bang = true })
				vim.o.selection = saved_selection
				if not ok then
					error(err)
				end
				local old_line = line
				line = vim.api.nvim_get_current_line()
				changed = changed or line ~= old_line
			else
				local text = line:sub(1, target.start_col - 1) .. target.replacement .. line:sub(target.end_col + 1)
				if text ~= line then
					set_line(row, text)
					line = text
				end
			end
			end_col = end_col + #line - old_length
		end
		previous = line:sub(start_col, end_col)
	end
	if regions[1] then
		local first = regions[1][1]
		vim.api.nvim_win_set_cursor(0, { first[2], math.max(0, first[3] - 1) })
	end
end

return M
