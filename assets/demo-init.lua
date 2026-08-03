-- Curated demo config for recording the README GIF.
-- A hard copy of the visually-relevant parts of my real Neovim setup: options
-- (relative numbers, cursorline, ...), Catppuccin Mocha, a statuscol gutter, a
-- lualine statusline (mocked with static text — no real data sources), and my
-- highlight tweaks — plus the LOCAL add-subtract-ex under development. Isolated
-- from real Neovim data (see assets/demo-open.sh).

--------------------------------------------------------------------------------
-- Options (visually relevant subset of core/options.lua)
--------------------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.have_nerd_font = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false
vim.opt.wrap = false

vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.scrolloff = 4
vim.opt.showmode = false -- lualine shows the mode instead

vim.opt.swapfile = false -- keep the recording free of swap prompts
vim.opt.hlsearch = false -- avoid search highlight noise in the demo

--------------------------------------------------------------------------------
-- Bootstrap lazy.nvim
--------------------------------------------------------------------------------
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local root = vim.fn.fnamemodify(here, ":h") -- repo root (parent of assets/)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

--------------------------------------------------------------------------------
-- Highlight tweaks (hard copy of core/colors.lua palette overrides)
--------------------------------------------------------------------------------
local function apply_highlights()
	local ok, palettes = pcall(require, "catppuccin.palettes")
	if not ok then
		return
	end
	local palette = palettes.get_palette("mocha")
	vim.api.nvim_set_hl(0, "LineNr", { fg = palette.overlay0 })
	vim.api.nvim_set_hl(0, "FoldColumn", { fg = palette.sapphire })
	vim.api.nvim_set_hl(0, "CursorLine", { bg = palette.surface0 })
	vim.api.nvim_set_hl(0, "CursorLineNr", { fg = palette.peach })
end

-- Static mock component for lualine (no real data sources needed for a demo).
local function mock(text)
	return function()
		return text
	end
end

--------------------------------------------------------------------------------
-- Plugins
--------------------------------------------------------------------------------
require("lazy").setup({
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = false,
		priority = 1000,
		config = function()
			require("catppuccin").setup({ flavour = "mocha" })
			vim.cmd.colorscheme("catppuccin")
			apply_highlights()
		end,
	},
	{
		"luukvbaal/statuscol.nvim",
		lazy = false,
		config = function()
			local builtin = require("statuscol.builtin")
			vim.opt.foldcolumn = "1"
			vim.opt.fillchars:append({
				foldopen = vim.fn.nr2char(0xF0140), -- nf-md-chevron_down
				foldclose = vim.fn.nr2char(0xF0142), -- nf-md-chevron_right
				foldsep = " ",
			})
			require("statuscol").setup({
				relculright = true, -- right-align relative numbers
				segments = {
					{ text = { builtin.foldfunc }, click = "v:lua.ScFa" },
					{
						sign = { namespace = { "diagnostic.signs" }, maxwidth = 1, colwidth = 1, auto = false },
						click = "v:lua.ScSa",
					},
					{ text = { builtin.lnumfunc, " " }, condition = { true, builtin.not_empty }, click = "v:lua.ScLa" },
				},
			})
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		lazy = false,
		config = function()
			require("lualine").setup({
				options = {
					section_separators = "",
					component_separators = "",
					always_divide_middle = false,
					globalstatus = false,
				},
				sections = {
					lualine_a = { "mode" },
					lualine_b = { mock("\u{e0a0} main") },
					lualine_c = { mock("lua/config/options.lua") },
					lualine_x = { mock("\u{e620} lua") },
					lualine_y = {},
					lualine_z = { "location" },
				},
			})
		end,
	},
	{
		-- Floating keycast overlay so the recording shows which keys are pressed.
		"nvzone/showkeys",
		dependencies = { "nvzone/volt" },
		lazy = false,
		config = function()
			require("showkeys").setup({ position = "bottom-right", maxkeys = 5, timeout = 3 })
			-- showkeys starts disabled; turn it on for the demo.
			vim.schedule(function()
				pcall(vim.cmd, "ShowkeysToggle")
			end)
		end,
	},
	{
		-- The plugin under test, straight from this working tree.
		"add-subtract-ex.nvim",
		dir = root,
		opts = {},
	},
})

--------------------------------------------------------------------------------
-- Highlighting for the demo buffer (legacy syntax; no Treesitter churn)
--------------------------------------------------------------------------------
vim.cmd("syntax enable")

-- Re-apply palette tweaks if the colorscheme is reloaded.
vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_highlights })

-- The demo buffer is named demo.txt; force Lua so it gets highlighted.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter" }, {
	pattern = "*/demo.txt",
	callback = function()
		vim.bo.filetype = "lua"
	end,
})
