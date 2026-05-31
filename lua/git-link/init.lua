local config = require("git-link.config")
local main = require("git-link.main")

local M = {}

function M.setup(opts)
	config.setup(opts)
end

M.copy_line_url = main.copy_line_url
M.open_line_url = main.open_line_url
M.copy_permalink = main.copy_permalink
M.open_permalink = main.open_permalink

return M
