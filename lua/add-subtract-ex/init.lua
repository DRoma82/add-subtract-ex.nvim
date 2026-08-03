-- add-subtract-ex.nvim: an extended Ctrl-a / Ctrl-x that also toggles word
-- pairs (true/false), symbol pairs (&&/||) and shifts letters, while keeping
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

-- Build a bidirectional lookup from an ordered list of { a, b } pairs. Later
-- pairs override earlier ones and drop any now-stale reverse mapping, so a user
-- pair like { "true", "apple" } cleanly replaces the shipped { "true", "false" }.
local function build_lookup(pair_lists)
	local lookup = {}
	for _, pairs_list in ipairs(pair_lists) do
		for _, pair in ipairs(pairs_list or {}) do
			local a, b = pair[1], pair[2]
			local old_a = lookup[a]
			if old_a and old_a ~= b then
				lookup[old_a] = nil
			end
			local old_b = lookup[b]
			if old_b and old_b ~= a then
				lookup[old_b] = nil
			end
			lookup[a] = b
			lookup[b] = a
		end
	end
	return lookup
end

-- Word lookups are case-insensitive (core lowercases the match) and casing is
-- re-applied at runtime, so word pairs are normalized to lowercase here. This
-- lets custom pairs like { "Foo", "Bar" } match and case correctly.
local function lower_pairs(pairs_list)
	local out = {}
	for i, pair in ipairs(pairs_list or {}) do
		out[i] = { pair[1]:lower(), pair[2]:lower() }
	end
	return out
end

-- Resolve user options into the config consumed by core.act.
local function resolve(opts)
	opts = opts or {}
	local use_builtins = opts.builtins ~= false
	return {
		words = build_lookup({ lower_pairs(use_builtins and default_words or {}), lower_pairs(opts.words) }),
		symbols = build_lookup({ use_builtins and default_symbols or {}, opts.symbols }),
		letters = opts.letters ~= false,
		sign_aware = opts.sign_aware == true,
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

-- opts.keys:
--   nil   -> map <C-a>/<C-x> (default)
--   false -> map nothing (leave <C-a>/<C-x> native)
--   table -> map exactly the given keys; omitted directions stay native
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
		vim.keymap.set("n", keys.increment, M.increment, { desc = "Add / toggle at cursor" })
	end
	if keys.decrement then
		vim.keymap.set("n", keys.decrement, M.decrement, { desc = "Subtract / toggle at cursor" })
	end
end

return M
