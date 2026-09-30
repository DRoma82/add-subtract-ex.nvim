-- Headless Neovim test suite for add-subtract-ex.nvim.
-- Run with:  nvim --headless --clean -u NONE -l tests/run.lua
-- or:        make test
-- Exits 0 when all tests pass, 1 otherwise.

-- Make the plugin under test importable regardless of the caller's cwd.
local this = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(this, ":p:h:h")
vim.opt.runtimepath:append(root)
package.loaded["add-subtract-ex"] = nil
package.loaded["add-subtract-ex.core"] = nil

local ase = require("add-subtract-ex")

local passed, failed = 0, 0

local function check(desc, got, want)
	if got == want then
		passed = passed + 1
		print("ok   - " .. desc)
	else
		failed = failed + 1
		print(("not ok - %s\n         got:  %q\n         want: %q"):format(desc, tostring(got), tostring(want)))
	end
end

-- Set a single-line buffer, place the (0-based) cursor, run the direction, and
-- return the resulting line. Numbers go through native <C-a>/<C-x> which is
-- synchronous here thanks to the "nx" feedkeys flag.
local function line_after(opts, text, col, dir)
	ase.setup(opts or {})
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
	vim.api.nvim_win_set_cursor(0, { 1, col })
	if dir == "dec" then
		ase.decrement()
	else
		ase.increment()
	end
	return vim.api.nvim_get_current_line()
end

-- Drive a mapped key end-to-end (so v:count is honoured) and return the line.
local function feed_after(opts, text, col, keys)
	ase.setup(opts or {})
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
	vim.api.nvim_win_set_cursor(0, { 1, col })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
	return vim.api.nvim_get_current_line()
end

-- Word pairs --------------------------------------------------------------
check("word: true -> false", line_after({}, "x = true", 4, "inc"), "x = false")
check("word: false -> true (dec)", line_after({}, "x = false", 4, "dec"), "x = true")
check("word casing: FALSE -> TRUE", line_after({}, "F = FALSE", 4, "inc"), "F = TRUE")
check("word casing: True -> False", line_after({}, "b = True", 4, "inc"), "b = False")
check("word: cursor on trailing space picks next target", line_after({}, "true false", 4, "inc"), "true true")
check("word: cursor on last char still toggles", line_after({}, "true false", 3, "inc"), "false false")

-- Symbol pairs ------------------------------------------------------------
check("symbol: && -> ||", line_after({}, "a && b", 2, "inc"), "a || b")
check("symbol: <= -> >=", line_after({}, "x <= y", 2, "inc"), "x >= y")
check("symbol: longest match wins on tie (++ not +)", line_after({ symbols = { { "+", "-" } } }, "++", 0, "inc"), "--")

-- Letters -----------------------------------------------------------------
check("letter: g -> h", line_after({}, "x g y", 2, "inc"), "x h y")
check("letter: g -> f (dec)", line_after({}, "x g y", 2, "dec"), "x f y")
check("letter: clamps at z (no wrap)", line_after({}, "z", 0, "inc"), "z")
check("letter: disabled -> native number", line_after({ letters = false }, "ab 5", 0, "inc"), "ab 6")

-- Numbers (native, synchronous) -------------------------------------------
check("number: 5 -> 6", line_after({}, "count = 5", 8, "inc"), "count = 6")
check("number: 10 -> 9 (dec)", line_after({}, "val = 10", 6, "dec"), "val = 9")
check("number: hex 0xFF -> 0x100", line_after({}, "n = 0xFF", 4, "inc"), "n = 0x100")
check("number: cursor on hex letter defers to native", line_after({}, "0xFF", 2, "inc"), "0x100")
check("number: binary 0b1010 -> 0b1011", line_after({}, "b = 0b1010", 6, "inc"), "b = 0b1011")

-- Sign handling -----------------------------------------------------------
check("sign default: -5 -> +5", line_after({}, "-5", 0, "inc"), "+5")
check("sign default: +5 -> -5", line_after({}, "+5", 0, "inc"), "-5")
check("sign aware: -5 -> native -4", line_after({ sign_aware = true }, "-5", 0, "inc"), "-4")
check("sign aware: standalone + still toggles", line_after({ sign_aware = true }, "a + b", 2, "inc"), "a - b")

-- Dictionary configuration ------------------------------------------------
check("override: true -> apple", line_after({ words = { { "true", "apple" } } }, "x = true", 4, "inc"), "x = apple")
check("override: apple -> true", line_after({ words = { { "true", "apple" } } }, "x = apple", 4, "inc"), "x = true")
check("new pair: foo -> bar", line_after({ words = { { "foo", "bar" } } }, "foo", 0, "inc"), "bar")
check("new pair: uppercase key Foo -> Bar", line_after({ words = { { "Foo", "Bar" } } }, "Foo", 0, "inc"), "Bar")
check(
	"new pair: case-insensitive match FOO -> BAR",
	line_after({ words = { { "Foo", "Bar" } } }, "FOO", 0, "inc"),
	"BAR"
)
check("new pair: lowercase input keeps lowercase", line_after({ words = { { "Foo", "Bar" } } }, "foo", 0, "inc"), "bar")
check(
	"builtins off: foo -> bar",
	line_after({ builtins = false, words = { { "foo", "bar" } } }, "foo", 0, "inc"),
	"bar"
)

-- Markdown checkboxes ----------------------------------------------------
vim.bo.filetype = "markdown"
check("checkbox: [ ] -> [x]", line_after({}, "- [ ] task", 3, "inc"), "- [x] task")
check("checkbox: [X] -> [ ] (dec)", line_after({}, "- [X] task", 3, "dec"), "- [ ] task")
check("checkbox: beats bullet at col 0", line_after({}, "- [ ] task", 0, "inc"), "- [x] task")
check("checkbox: * bullet, indented", line_after({}, "  * [x] task", 0, "inc"), "  * [ ] task")
check("checkbox: ordered list", line_after({}, "1. [ ] task", 0, "inc"), "1. [x] task")
check("checkbox: cursor past box -> number", line_after({}, "- [ ] buy 5 eggs", 10, "inc"), "- [ ] buy 6 eggs")
vim.bo.filetype = "lua"
check("checkbox: ignored outside markdown", line_after({}, "- [ ] task", 0, "inc"), "+ [ ] task")
vim.bo.filetype = ""

-- Keymaps -----------------------------------------------------------------
pcall(vim.keymap.del, "n", "<C-a>")
ase.setup({})
check("keys default: <C-a> mapped", vim.fn.maparg("<C-a>", "n") ~= "", true)
pcall(vim.keymap.del, "n", "<C-a>")
ase.setup({ keys = false })
check("keys false: <C-a> not mapped", vim.fn.maparg("<C-a>", "n"), "")
check(
	"keys custom: <leader>a mapped",
	(function()
		pcall(vim.keymap.del, "n", "<C-a>")
		ase.setup({ keys = { increment = "<Plug>(ase-inc)" } })
		return vim.fn.maparg("<Plug>(ase-inc)", "n") ~= "" and vim.fn.maparg("<C-a>", "n") == ""
	end)(),
	true
)

-- Dates -------------------------------------------------------------------
check("date iso: day under cursor", line_after({}, "d = 2024-01-05", 13, "inc"), "d = 2024-01-06")
check("date iso: day rolls month", line_after({}, "2024-01-31", 9, "inc"), "2024-02-01")
check("date iso: day rolls year", line_after({}, "2024-12-31", 9, "inc"), "2025-01-01")
check("date iso: day rolls back", line_after({}, "2024-03-01", 9, "dec"), "2024-02-29")
check("date iso: month clamps day", line_after({}, "2024-01-31", 6, "inc"), "2024-02-29")
check("date iso: month rolls year", line_after({}, "2024-12-15", 6, "inc"), "2025-01-15")
check("date iso: year clamps leap day", line_after({}, "2024-02-29", 0, "inc"), "2025-02-28")
check("date iso: separator belongs to part before", line_after({}, "2024-01-05", 4, "inc"), "2025-01-05")
check("date iso: cursor before date -> day", line_after({}, "= 2024-01-05", 0, "inc"), "= 2024-01-06")
check(
	"date: default_part = month",
	line_after({ dates = { default_part = "month" } }, "= 2024-01-05", 0, "inc"),
	"= 2024-02-05"
)
check("date iso: yyyy clamps at 9999", line_after({}, "9999-12-31", 9, "inc"), "9999-12-31")
check("date dmy: 31/01/2024 -> 01/02/2024", line_after({}, "31/01/2024", 0, "inc"), "01/02/2024")
check("date dmy: month part", line_after({}, "15/12/2024", 3, "inc"), "15/01/2025")
check("date mdy: day part", line_after({ dates = { format = "mdy" } }, "01/31/2024", 3, "inc"), "02/01/2024")
check("date: unpadded kept", line_after({}, "9/1/2024", 0, "inc"), "10/1/2024")
check("date: pad = true", line_after({ dates = { pad = true } }, "1/2/2024", 0, "inc"), "02/02/2024")
check("date yy: wraps century via pivot", line_after({}, "31/12/99", 0, "inc"), "01/01/00")
check("date yy: clamps at pivot window", line_after({}, "01/01/68", 6, "inc"), "01/01/68")
check("date yy: 29/02/00 valid (2000)", line_after({}, "29/02/00", 0, "inc"), "01/03/00")
do
	local notify, warned = vim.notify, nil
	vim.notify = function(msg)
		warned = msg
	end
	check("date invalid: unchanged", line_after({}, "31/02/2024", 0, "inc"), "31/02/2024")
	check("date invalid: warns", warned, "add-subtract-ex: 31/02/2024 is not a valid date")
	check(
		"date yy: custom pivot makes 00 = 1900 (no leap day)",
		line_after({ dates = { century_pivot = 0 } }, "29/02/00", 0, "inc"),
		"29/02/00"
	)
	vim.notify = notify
end
check(
	"date: disabled -> native (-01 read as negative)",
	line_after({ dates = false }, "2024-01-05", 6, "inc"),
	"202400-05"
)
check("date: 3-digit year is not a date", line_after({}, "1/2/345", 4, "inc"), "1/2/346")

-- Times -------------------------------------------------------------------
check("time: minute carries hour", line_after({}, "at 10:59", 6, "inc"), "at 11:00")
check("time: wraps midnight", line_after({}, "23:59:59", 6, "inc"), "00:00:00")
check("time: hour wraps back", line_after({}, "00:30", 0, "dec"), "23:30")
check("time: separator belongs to part before", line_after({}, "10:30", 2, "inc"), "11:30")
check("time: cursor before -> hour", line_after({}, "= 10:30", 0, "inc"), "= 11:30")
check(
	"time: default_part = minute",
	line_after({ times = { default_part = "minute" } }, "= 10:30", 0, "inc"),
	"= 10:31"
)
check("time: unpadded 24h is not a time", line_after({}, "3:16", 2, "inc"), "3:17")
check("time 12h: carry flips meridiem", line_after({}, "11:59 PM", 3, "inc"), "12:00 AM")
check("time 12h: 11 am -> 12 pm", line_after({}, "11:00am", 0, "inc"), "12:00pm")
check("time 12h: unpadded hour kept", line_after({}, "9:30 PM", 0, "inc"), "10:30 PM")
check("time 12h: toggle meridiem", line_after({}, "9:30 PM", 5, "inc"), "9:30 AM")
check("time 12h: cursor on meridiem", line_after({}, "9:30 Pm", 6, "dec"), "9:30 Am")
check("time ms: minute wraps at 60", line_after({ times = { two_part = "ms" } }, "59:59", 3, "inc"), "00:00")
check(
	"time ms: default part falls to first",
	line_after({ times = { two_part = "ms" } }, "= 45:30", 0, "inc"),
	"= 46:30"
)
check("time ms: seconds still means hms", line_after({ times = { two_part = "ms" } }, "23:59:59", 0, "inc"), "00:59:59")
check("time: disabled -> native", line_after({ times = false }, "10:30", 3, "inc"), "10:31")
do
	local notify, warned = vim.notify, nil
	vim.notify = function(msg)
		warned = msg
	end
	check("time invalid: unchanged", line_after({}, "25:00", 0, "inc"), "25:00")
	check("time invalid: warns", warned, "add-subtract-ex: 25:00 is not a valid time")
	check("time invalid: 13:00 PM", line_after({}, "13:00 PM", 0, "inc"), "13:00 PM")
	vim.notify = notify
end
check("datetime: time does not carry into date", line_after({}, "2024-01-31 23:59", 14, "inc"), "2024-01-31 00:00")

-- Count (last: feedkeys leaves v:count lingering in headless -l scripts) ----
check("count: 40<C-a> on date day", feed_after({}, "2024-01-01", 9, "40<C-a>"), "2024-02-10")
check("count: 90<C-a> on minute", feed_after({}, "10:00", 3, "90<C-a>"), "11:30")
check("count: 3<C-a> on number adds 3", feed_after({}, "n = 5", 4, "3<C-a>"), "n = 8")
check("count: 3<C-a> on letter shifts 3", feed_after({}, "a", 0, "3<C-a>"), "d")

-- Dot-repeat ---------------------------------------------------------------
local function lines_after(text, keys)
	ase.setup({})
	vim.api.nvim_buf_set_lines(0, 0, -1, false, text)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), ", ")
end
check("dot: repeats toggle after a number", lines_after({ "true", "1", "true" }, "<C-a>j.j."), "false, 2, false")
check("dot: repeats decrement", lines_after({ "1", "true", "5" }, "<C-x>j.j."), "0, false, 4")
check("dot: keeps the count", lines_after({ "7" }, "3<C-a>."), "13")
check("dot: new count replaces it", lines_after({ "7" }, "3<C-a>2.."), "14")
vim.fn.setreg("q", vim.keycode("<C-a>w<C-a>j0"))
check("macro: native step runs in order", lines_after({ "1 true", "2 true" }, "2@q"), "2 false, 3 false")

print(("\n%d passed, %d failed"):format(passed, failed))
vim.cmd(failed == 0 and "cq 0" or "cq 1")
