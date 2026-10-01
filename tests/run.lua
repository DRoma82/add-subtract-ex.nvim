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

-- Ordered cycles ---------------------------------------------------------
local cycle_opts = { words = { { "foo", "bar", "baz" } }, symbols = { { "@", "#", "$" } } }
check("cycle: word forward", line_after(cycle_opts, "foo", 0, "inc"), "bar")
check("cycle: word backward", line_after(cycle_opts, "bar", 1, "dec"), "foo")
check("cycle: word forward wrap", line_after(cycle_opts, "baz", 2, "inc"), "foo")
check("cycle: word backward wrap", line_after(cycle_opts, "foo", 0, "dec"), "baz")
check("cycle: uppercase", line_after(cycle_opts, "BAZ", 0, "inc"), "FOO")
check("cycle: title case", line_after(cycle_opts, "Foo", 0, "dec"), "Baz")
check("cycle: symbol forward", line_after(cycle_opts, "@", 0, "inc"), "#")
check("cycle: symbol forward wrap", line_after(cycle_opts, "$", 0, "inc"), "@")
check("cycle: symbol backward wrap", line_after(cycle_opts, "@", 0, "dec"), "$")
check(
	"cycle: preserves word boundaries",
	line_after({ letters = false, words = cycle_opts.words }, "foobar foo_ foo1", 0, "inc"),
	"foobar foo_ foo2"
)
check("cycle: default full month", line_after({}, "May", 0, "inc"), "June")
check("cycle: default month backward", line_after({}, "May", 2, "dec"), "April")
check("cycle: month forward wrap", line_after({}, "December", 0, "inc"), "January")
check("cycle: month backward wrap", line_after({}, "January", 0, "dec"), "December")
check("cycle: month uppercase", line_after({}, "JANUARY", 0, "inc"), "FEBRUARY")
check("cycle: short month", line_after({ months = "short" }, "May", 0, "inc"), "Jun")
check("cycle: short month backward", line_after({ months = "short" }, "May", 0, "dec"), "Apr")
check(
	"cycle: short month excludes full names",
	line_after({ months = "short", letters = false }, "January", 0, "inc"),
	"January"
)
check("cycle: full month excludes short names", line_after({ letters = false }, "Jan", 0, "inc"), "Jan")
check("cycle: months none", line_after({ months = "none", letters = false }, "May", 0, "inc"), "May")
check("cycle: default full weekday", line_after({}, "Monday", 0, "inc"), "Tuesday")
check("cycle: default short weekday", line_after({}, "Mon", 0, "inc"), "Tue")
check("cycle: weekday forward wrap", line_after({}, "Sun", 0, "inc"), "Mon")
check("cycle: weekday backward wrap", line_after({}, "Monday", 0, "dec"), "Sunday")
check(
	"cycle: full weekdays only",
	line_after({ weekdays = "full", letters = false }, "Mon Monday", 0, "inc"),
	"Mon Tuesday"
)
check(
	"cycle: short weekdays only",
	line_after({ weekdays = "short", letters = false }, "Monday Mon", 0, "inc"),
	"Monday Tue"
)
check("cycle: weekdays none", line_after({ weekdays = "none", letters = false }, "Mon Monday", 0, "inc"), "Mon Monday")
check(
	"cycle: builtins false",
	line_after({ builtins = false, letters = false }, "May Mon true &&", 0, "inc"),
	"May Mon true &&"
)
check(
	"cycle: calendar options leave pairs enabled",
	line_after({ months = "none", weekdays = "none" }, "true", 0, "inc"),
	"false"
)
check(
	"cycle: custom month with builtins false",
	line_after({ builtins = false, words = { { "May", "June", "July" } } }, "May", 0, "dec"),
	"July"
)
check(
	"cycle: custom month with months none",
	line_after({ months = "none", words = { { "May", "June", "July" } } }, "May", 0, "inc"),
	"June"
)
check(
	"cycle: custom weekday with weekdays none",
	line_after({ weekdays = "none", words = { { "Mon", "Tue", "Wed" } } }, "Wed", 0, "inc"),
	"Mon"
)
check(
	"cycle: overrides built-in via any member",
	line_after({ words = { { "maybe", "false", "unknown" } } }, "false", 0, "inc"),
	"unknown"
)
check(
	"cycle: overridden pair has no stale member",
	line_after({ letters = false, words = { { "maybe", "false", "unknown" } } }, "true", 0, "inc"),
	"true"
)
local override_opts = { letters = false, words = { { "foo", "bar", "baz" }, { "bar", "qux", "zap" } } }
check("cycle: later list replaces whole cycle", line_after(override_opts, "foo baz bar", 0, "inc"), "foo baz qux")
check(
	"cycle: custom month removes old cycle",
	line_after({ letters = false, words = { { "May", "June", "July" } } }, "January May", 0, "inc"),
	"January June"
)
check(
	"cycle: override both weekdays",
	line_after({ letters = false, words = { { "Mon", "Monday", "holiday" } } }, "Tue Tuesday Mon", 0, "inc"),
	"Tue Tuesday Monday"
)
check(
	"cycle: symbol override drops stale member",
	line_after({ symbols = { { "&&", "||", "??" }, { "||", "!" } } }, "?? ||", 0, "inc"),
	"?? !"
)
local mixed_case_opts = { words = { { "Foo", "BAR", "Baz" } } }
check("cycle: normalizes every item", line_after(mixed_case_opts, "bar", 0, "inc"), "baz")
check("cycle: setup does not mutate words", mixed_case_opts.words[1][2], "BAR")
for _, case in ipairs({
	{ "invalid months", { months = "both" } },
	{ "invalid weekdays", { weekdays = false } },
	{ "one item", { words = { { "foo" } } } },
	{ "empty list", { words = { {} } } },
	{ "non-string item", { symbols = { { "@", 1 } } } },
	{ "empty item", { symbols = { { "@", "" } } } },
	{ "duplicate word ignoring case", { words = { { "Foo", "bar", "foo" } } } },
	{ "duplicate symbol", { symbols = { { "@", "#", "@" } } } },
	{ "sparse cycle", { words = { { [1] = "foo", [3] = "bar" } } } },
	{ "non-list cycles", { words = { foo = "bar" } } },
}) do
	check("cycle rejects: " .. case[1], pcall(ase.setup, case[2]), false)
end

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

check("count: cycle forward modulo length", feed_after(cycle_opts, "foo", 0, "5<C-a>"), "baz")
check("count: cycle backward modulo length", feed_after(cycle_opts, "foo", 0, "5<C-x>"), "bar")
check("count: full cycle leaves word unchanged", feed_after(cycle_opts, "foo", 0, "3<C-a>"), "foo")
check("count: symbol cycle", feed_after(cycle_opts, "@", 0, "2<C-x>"), "#")
check("count: month wraps", feed_after({}, "December", 0, "14<C-a>"), "February")
check("count: weekday", feed_after({}, "Mon", 0, "2<C-a>"), "Wed")
check("count: pairs still toggle once", feed_after({}, "true", 0, "2<C-a>"), "false")
check("count: symbol pairs still toggle once", feed_after({}, "&&", 0, "2<C-x>"), "||")

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
check("dot: repeats cycle count", lines_after({ "Mon", "Monday" }, "2<C-a>j."), "Wed, Wednesday")
check("dot: repeats backward cycle", lines_after({ "January", "May" }, "<C-x>j."), "December, April")
check("dot: keeps the count", lines_after({ "7" }, "3<C-a>."), "13")
check("dot: new count replaces it", lines_after({ "7" }, "3<C-a>2.."), "14")
vim.fn.setreg("q", vim.keycode("<C-a>w<C-a>j0"))
check("macro: native step runs in order", lines_after({ "1 true", "2 true" }, "2@q"), "2 false, 3 false")

-- Visual selections -------------------------------------------------------
local function visual_after(opts, text, keys)
	ase.setup(opts or {})
	vim.api.nvim_buf_set_lines(0, 0, -1, false, text)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd("let &undolevels = &undolevels")
	vim.api.nvim_feedkeys(vim.keycode(keys), "x", false)
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), ", ")
end

check("visual: all numbers on a line", visual_after({}, { "10 10" }, "V<C-a>"), "11 11")
check("visual: decrement all numbers", visual_after({}, { "10 10" }, "V<C-x>"), "9 9")
check("visual: progressive targets across lines", visual_after({}, { "10 10", "10 10" }, "Vjg<C-a>"), "11 12, 13 14")
check("visual: progressive decrement", visual_after({}, { "10 10", "10 10" }, "Vjg<C-x>"), "9 8, 7 6")
check("visual: count", visual_after({}, { "10 10" }, "V3<C-a>"), "13 13")
check("visual: progressive count", visual_after({}, { "10 10" }, "V3g<C-a>"), "13 16")
check("visual: mixed targets", visual_after({}, { "true && 9 a" }, "V<C-a>"), "false || 10 b")
check("visual: cycles with count", visual_after(cycle_opts, { "foo bar @" }, "V2<C-a>"), "baz foo $")
check("visual: progressive cycles", visual_after(cycle_opts, { "foo foo", "foo" }, "Vjg<C-a>"), "bar baz, foo")
check(
	"visual: progressive decrement cycles",
	visual_after(cycle_opts, { "foo foo", "foo" }, "Vjg<C-x>"),
	"baz bar, foo"
)
check("visual: progressive count cycles", visual_after(cycle_opts, { "foo foo @" }, "V2g<C-a>"), "baz bar @")
check(
	"visual: cycles and pairs",
	visual_after({}, { "true Mon Monday && January" }, "V2g<C-a>"),
	"false Fri Sunday || November"
)
check("visual: touched cycle word", visual_after({}, { "Monday Friday" }, "lv<C-x>"), "Sunday Friday")
check("visual: length-changing cycles", visual_after({}, { "May June July" }, "V<C-a>"), "June July August")
check("visual: cycles fill blanks", visual_after({}, { "Sunday", "", "" }, "V2j<C-a>"), "Monday, Tuesday, Wednesday")
check("visual: cycles fill blanks progressively", visual_after({}, { "Mon", "", "" }, "V2jg<C-a>"), "Tue, Thu, Sun")
check("visual: undo cycles", visual_after({}, { "May June July" }, "V<C-a>u"), "May June July")
check("visual: toggles ignore count", visual_after({}, { "true false ++" }, "V3g<C-x>"), "false true --")
check("visual: each letter is a target", visual_after({}, { "abc" }, "Vg<C-a>"), "bdf")
check("visual: clamped letter does not stop scanning", visual_after({}, { "z a" }, "Vg<C-a>"), "z c")
check("visual: length-changing words", visual_after({}, { "yes true no" }, "V<C-a>"), "no false yes")
check(
	"visual: overlapping custom symbol is not applied twice",
	visual_after({ symbols = { { "true &&", "false ||" } } }, { "true &&" }, "V<C-a>"),
	"false ||"
)
check(
	"visual: overlapping symbols keep later targets",
	visual_after({ symbols = { { "&|", "|&" } } }, { "&&| 10" }, "V<C-a>"),
	"||| 11"
)
check("visual: single-character selection", visual_after({}, { "1 2" }, "v<C-a>"), "2 2")
check("visual: touched word", visual_after({}, { "true false" }, "lv<C-a>"), "false false")
check("visual: touched decimal", visual_after({}, { "199 5" }, "lv<C-a>"), "200 5")
check("visual: selected range excludes later targets", visual_after({}, { "true false" }, "v3l<C-a>"), "false false")
check("visual: reversed selection", visual_after({}, { "1 2 3" }, "$v0g<C-a>"), "2 4 6")
check("visual: multiline characterwise", visual_after({}, { "1 2", "3 4" }, "2lvj0<C-a>"), "1 3, 4 4")
check("visual: blockwise", visual_after({}, { "1 2 3", "4 5 6" }, "2l<C-v>j<C-a>"), "1 3 3, 4 6 6")
check("visual: reversed blockwise", visual_after({}, { "1 2 3", "4 5 6" }, "j2l<C-v>kg<C-a>"), "1 3 3, 4 7 6")
check(
	"visual: complete dates use default part",
	visual_after({}, { "2024-01-31 2024-02-28" }, "V<C-a>"),
	"2024-02-01 2024-02-29"
)
check("visual: date part under selection start", visual_after({}, { "2024-01-31" }, "6lv<C-a>"), "2024-02-29")
check("visual: complete times use default part", visual_after({}, { "23:59 10:30" }, "V<C-a>"), "00:59 11:30")
check("visual: time part under selection start", visual_after({}, { "23:59" }, "3lv<C-a>"), "00:00")
check("visual: hex and binary", visual_after({}, { "0xFF 0b1111" }, "V<C-a>"), "0x100 0b10000")
check("visual: touched hex", visual_after({}, { "0xFF 5" }, "2lv<C-a>"), "0x100 5")
check("visual: sign pairs remain separate targets", visual_after({}, { "-5 +5" }, "V<C-a>"), "+6 -6")
check("visual: sign-aware numbers", visual_after({ sign_aware = true }, { "-5 +5 -0xFF" }, "V<C-a>"), "-4 +6 -0x100")
check("visual: disabled letters", visual_after({ letters = false }, { "abc 10" }, "V<C-a>"), "abc 11")
check("visual: fill blank lines", visual_after({}, { "10", "", "" }, "V2j<C-a>"), "11, 12, 13")
check("visual: cumulative progressive filling", visual_after({}, { "10", "", "" }, "V2jg<C-a>"), "11, 13, 16")
check(
	"visual: fill dates across month boundary",
	visual_after({}, { "2000-10-30", "", "" }, "V2j<C-a>"),
	"2000-10-31, 2000-11-01, 2000-11-02"
)
check("visual: fill whitespace-only lines", visual_after({}, { "10", "  " }, "Vj<C-a>"), "11, 12")
vim.o.virtualedit = "block"
check(
	"visual: block filling copies selected span",
	visual_after({}, { "x 10 y", "" }, "2l<C-v>lj<C-a>"),
	"x 11 y,   12"
)
check("visual: fill from line above selection", visual_after({}, { "10", "", "" }, "jVj<C-a>"), "10, 11, 12")
check("visual: fill a partial tab", visual_after({}, { "x 10 y", "\t" }, "2l<C-v>lj<C-a>"), "x 11 y,   12    ")
vim.o.virtualedit = "all"
check(
	"visual: block seed above selection",
	visual_after({}, { "x 10 y", "", "" }, "j2l<C-v>lj<C-a>"),
	"x 10 y,   11,   12"
)
vim.o.virtualedit = "block"
check("visual: undo entire action", visual_after({}, { "true 9", "false 99" }, "Vj<C-a>u"), "true 9, false 99")
check("visual: undo blank filling", visual_after({}, { "10", "", "" }, "V2jg<C-a>u"), "10, , ")
check("visual: one redo restores entire action", visual_after({}, { "10", "", "" }, "V2jg<C-a>u<C-r>"), "11, 13, 16")

vim.o.selection = "exclusive"
check("visual: exclusive boundary", visual_after({}, { "1 2" }, "v2l<C-a>"), "2 2")
check("visual: exclusive full number", visual_after({}, { "199 5" }, "v3l<C-a>"), "200 5")
check("visual: selection option restored", vim.o.selection, "exclusive")
vim.o.selection = "inclusive"
check("visual: UTF-8 prefix", visual_after({}, { "é 10 20" }, "2lvg<C-a>"), "é 11 20")
check("visual: tabs in block boundaries", visual_after({}, { "  1 2", "\t1 2" }, "2l<C-v>j<C-a>"), "  2 2, \t1 2")
vim.o.virtualedit = ""

check("visual: no targets", visual_after({}, { "...", "" }, "Vj<C-x>"), "..., ...")
check("visual: no seed", visual_after({}, { "", "" }, "Vj<C-a>"), ", ")
check("visual: decrement blank sequence", visual_after({}, { "10", "", "" }, "V2j2g<C-x>"), "8, 4, -2")
check(
	"visual: custom date part",
	visual_after({ dates = { default_part = "month" } }, { "2024-01-31" }, "V<C-a>"),
	"2024-02-29"
)
check("visual: custom time part", visual_after({ times = { default_part = "minute" } }, { "23:59" }, "V<C-a>"), "00:00")

vim.bo.filetype = "markdown"
check(
	"visual: checkboxes",
	visual_after({ letters = false }, { "- [ ] task", "1. [X] task" }, "Vj<C-a>"),
	"- [x] task, 1. [ ] task"
)
check("visual: checkbox outside selection", visual_after({ letters = false }, { "- [ ] task" }, "v<C-a>"), "+ [ ] task")
vim.bo.filetype = ""
do
	local notify, warnings = vim.notify, 0
	vim.notify = function()
		warnings = warnings + 1
	end
	check(
		"visual: invalid stamps stay intact",
		visual_after({}, { "31/02/2024 25:00 10" }, "Vg<C-a>"),
		"31/02/2024 25:00 11"
	)
	check("visual: each invalid stamp warns once", warnings, 2)
	vim.notify = notify
end
vim.bo.nrformats = "octal,hex,bin"
check("visual: native octal padding", visual_after({}, { "0077 0x0f 0b0011" }, "V<C-a>"), "0100 0x10 0b0100")
vim.bo.nrformats = "bin,hex"
check("visual: custom keys", visual_after({ keys = { increment = "<F5>" } }, { "1 2" }, "Vg<F5>"), "2 4")
for _, key in ipairs({ "<C-a>", "<C-x>", "g<C-a>", "g<C-x>" }) do
	vim.keymap.del("x", key)
end
ase.setup({ keys = false })
check("visual: keys false leaves keys native", vim.fn.maparg("<C-a>", "x"), "")
ase.setup({})
check("visual: default progressive mapping", vim.fn.maparg("g<C-x>", "x") ~= "", true)

print(("\n%d passed, %d failed"):format(passed, failed))
vim.cmd(failed == 0 and "cq 0" or "cq 1")
