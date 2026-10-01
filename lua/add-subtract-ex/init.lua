-- add-subtract-ex.nvim: an extended Ctrl-a / Ctrl-x that also cycles words
-- and symbols and shifts letters, while keeping
-- native number handling (including hex/bin literals).

local core = require("add-subtract-ex.core")

local M = {}

-- Shipped word pairs. Keys are lowercase; casing of the match is preserved.
local default_words = {
	{ "true", "false" },
	{ "yes", "no" },
	{ "on", "off" },
	{ "enable", "disable" },
	{ "enabled", "disabled" },
	{ "show", "hide" },
	{ "left", "right" },
	{ "up", "down" },
	{ "min", "max" },
	{ "and", "or" },
}

-- Shipped operator/symbol pairs. Matched literally.
local default_symbols = {
	{ "&&", "||" },
	{ "==", "!=" },
	{ "<=", ">=" },
	{ "++", "--" },
	{ "+", "-" },
}

local month_cycles = {
	full = {
		"january",
		"february",
		"march",
		"april",
		"may",
		"june",
		"july",
		"august",
		"september",
		"october",
		"november",
		"december",
	},
	short = { "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec" },
}
local weekday_cycles = {
	full = { "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday" },
	short = { "mon", "tue", "wed", "thu", "fri", "sat", "sun" },
}

-- Removing the whole old cycle prevents stale transitions after an override.
local function build_lookup(cycle_lists, lowercase)
	local lookup = {}
	for _, cycles in ipairs(cycle_lists) do
		assert(type(cycles) == "table" and vim.islist(cycles), "add-subtract-ex: cycles must be a list")
		for _, values in ipairs(cycles) do
			assert(
				type(values) == "table" and vim.islist(values) and #values >= 2,
				"add-subtract-ex: each cycle needs at least two items"
			)
			local cycle, seen = {}, {}
			for i, value in ipairs(values) do
				assert(type(value) == "string" and value ~= "", "add-subtract-ex: cycle items must be nonempty strings")
				value = lowercase and value:lower() or value
				assert(not seen[value], "add-subtract-ex: cycle items must be distinct")
				cycle[i], seen[value] = value, true
			end
			for _, value in ipairs(cycle) do
				local old = lookup[value]
				if old then
					for _, member in ipairs(old.cycle) do
						lookup[member] = nil
					end
				end
			end
			for i, value in ipairs(cycle) do
				lookup[value] = { cycle = cycle, index = i }
			end
		end
	end
	return lookup
end

local default_dates = { format = "dmy", pad = false, default_part = "day", century_pivot = 69 }
local default_times = { default_part = "hour", two_part = "hm" }

-- `false` disables a feature; a table overrides some of its defaults.
local function feature(value, defaults)
	return value ~= false and vim.tbl_extend("force", defaults, type(value) == "table" and value or {})
end

-- Resolve user options into the config consumed by core.act.
local function resolve(opts)
	opts = opts or {}
	local use_builtins = opts.builtins ~= false
	local months = opts.months == nil and "full" or opts.months
	local weekdays = opts.weekdays == nil and "both" or opts.weekdays
	assert(months == "none" or month_cycles[months], 'add-subtract-ex: months must be "full", "short", or "none"')
	assert(
		weekdays == "none" or weekdays == "both" or weekday_cycles[weekdays],
		'add-subtract-ex: weekdays must be "full", "short", "both", or "none"'
	)
	local word_cycles = {}
	if use_builtins then
		vim.list_extend(word_cycles, default_words)
		if months ~= "none" then
			word_cycles[#word_cycles + 1] = month_cycles[months]
		end
		if weekdays == "both" then
			word_cycles[#word_cycles + 1] = weekday_cycles.full
			word_cycles[#word_cycles + 1] = weekday_cycles.short
		elseif weekdays ~= "none" then
			word_cycles[#word_cycles + 1] = weekday_cycles[weekdays]
		end
	end
	return {
		words = build_lookup({ word_cycles, opts.words or {} }, true),
		symbols = build_lookup({ use_builtins and default_symbols or {}, opts.symbols or {} }),
		letters = opts.letters ~= false,
		sign_aware = opts.sign_aware == true,
		dates = feature(opts.dates, default_dates),
		times = feature(opts.times, default_times),
	}
end

-- Usable without setup(); setup() only re-resolves config and wires keymaps.
M.config = resolve({})

function M.increment()
	core.act(M.config, 1)
end

function M.decrement()
	core.act(M.config, -1)
end

function M.increment_visual(progressive)
	core.visual(M.config, 1, progressive)
end

function M.decrement_visual(progressive)
	core.visual(M.config, -1, progressive)
end

local direction, rearming = 1, false

-- 'operatorfunc' for the mappings, so "." repeats the plugin rather than a raw edit.
function M._operator()
	if rearming then
		return
	end
	if core.act(M.config, direction) then
		-- The nested native <C-a> took over "."; a no-op g@l hands it back to us.
		rearming = true
		vim.cmd.normal({ vim.v.count1 .. "g@l", bang = true })
		rearming = false
	end
end

local function operator_mapping(dir)
	return function()
		direction = dir
		vim.o.operatorfunc = "v:lua.require'add-subtract-ex'._operator"
		return "g@l"
	end
end

-- opts.keys:
--   nil   -> map <C-a>/<C-x> and visual g variants (default)
--   false -> map nothing (leave native keys unchanged)
--   table -> map the given keys and visual g variants; omitted directions stay native
function M.setup(opts)
	opts = opts or {}
	M.config = resolve(opts)

	local keys
	if opts.keys == nil then
		keys = { increment = "<C-a>", decrement = "<C-x>" }
	elseif opts.keys == false then
		keys = {}
	else
		keys = opts.keys
	end

	if keys.increment then
		vim.keymap.set("n", keys.increment, operator_mapping(1), { expr = true, desc = "Add / toggle at cursor" })
		vim.keymap.set("x", keys.increment, function()
			M.increment_visual()
		end, { desc = "Add / toggle selected targets" })
		vim.keymap.set("x", "g" .. keys.increment, function()
			M.increment_visual(true)
		end, { desc = "Add progressively to selected targets" })
	end
	if keys.decrement then
		vim.keymap.set("n", keys.decrement, operator_mapping(-1), { expr = true, desc = "Subtract / toggle at cursor" })
		vim.keymap.set("x", keys.decrement, function()
			M.decrement_visual()
		end, { desc = "Subtract / toggle selected targets" })
		vim.keymap.set("x", "g" .. keys.decrement, function()
			M.decrement_visual(true)
		end, { desc = "Subtract progressively from selected targets" })
	end
end

return M
