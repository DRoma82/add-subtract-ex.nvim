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

-- Count (last: feedkeys leaves v:count lingering in headless -l scripts) ----
check("count: 3<C-a> on number adds 3", feed_after({}, "n = 5", 4, "3<C-a>"), "n = 8")
check("count: 3<C-a> on letter shifts 3", feed_after({}, "a", 0, "3<C-a>"), "d")

print(("\n%d passed, %d failed"):format(passed, failed))
vim.cmd(failed == 0 and "cq 0" or "cq 1")
