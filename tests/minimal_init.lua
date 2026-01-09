-- Minimal init.lua for running tests
-- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"

local plenary_path = os.getenv("PLENARY_PATH")
if not plenary_path then
	-- Try common locations
	local home = os.getenv("HOME")
	local possible_paths = {
		home .. "/.local/share/nvim/lazy/plenary.nvim",
		home .. "/.local/share/nvim/site/pack/packer/start/plenary.nvim",
		home .. "/.local/share/nvim/site/pack/*/start/plenary.nvim",
		"/tmp/plenary.nvim",
	}

	for _, path in ipairs(possible_paths) do
		if vim.fn.isdirectory(path) == 1 then
			plenary_path = path
			break
		end
	end
end

if plenary_path then
	vim.opt.runtimepath:prepend(plenary_path)
else
	print("Warning: plenary.nvim not found. Set PLENARY_PATH or install plenary.nvim")
	print("To install for tests: git clone https://github.com/nvim-lua/plenary.nvim /tmp/plenary.nvim")
end

-- Add the plugin to runtimepath
local plugin_path = vim.fn.fnamemodify(vim.fn.resolve(debug.getinfo(1).source:sub(2)), ":h:h")
vim.opt.runtimepath:prepend(plugin_path)

-- Basic settings for tests
vim.cmd([[set noswapfile]])
vim.cmd([[set nobackup]])

-- Load the plugin
require("git-link")
