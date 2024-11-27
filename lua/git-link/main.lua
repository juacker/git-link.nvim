local config = require("git-link.config")

local function copy_to_clipboard(text)
	vim.fn.setreg("+", text)
end

local function open_url_in_browser(url)
	local command = string.format("xdg-open %s", url) -- Linux command (using xdg-open)
	vim.fn.jobstart(command, { detach = true, cwd = vim.fn.getcwd() })
end

local function get_current_branch()
	local output = vim.fn.system("git rev-parse --abbrev-ref @{u} 2>/dev/null")
	if vim.v.shell_error ~= 0 then
		return "master" -- Default to "master" if the command fails
	end
	local branch = vim.fn.trim(output):gsub("^origin/", "")
	return branch ~= "" and branch or "master"
end

local function get_remote_url()
	local remote_url = vim.fn.trim(vim.fn.system("git config --get remote.origin.url"))

	local rules = config.get_rules()

	-- Apply URL rewrite rules
	for _, rule in ipairs(rules) do
		if remote_url:match(rule.pattern) then
			local final_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
			return final_url, rule.format_url
		end
	end

	local default_rule = config.default_rules[1]
	return remote_url:gsub("%.git$", ""), default_rule.format_url
end

local function get_current_line_url()
	local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
	local filename = vim.fn.expand("%:p"):gsub("^" .. git_root .. "/", "")
	local linenr = vim.api.nvim_win_get_cursor(0)[1]
	local relative_filename = vim.fn.trim(vim.fn.system("git ls-files --full-name " .. filename))
	local remote_url, format_url = get_remote_url()
	local branch = get_current_branch()

	if remote_url then
		local params = {
			branch = branch,
			file_path = relative_filename,
			line_number = linenr,
		}
		return format_url(remote_url, params)
	end

	return nil
end

local function copy_line_url()
	local remote_url = get_current_line_url()
	if remote_url then
		copy_to_clipboard(remote_url)
	end
end

local function open_line_url()
	local remote_url = get_current_line_url()
	if remote_url then
		open_url_in_browser(remote_url)
	end
end

return {
	copy_line_url = copy_line_url,
	open_line_url = open_line_url,
}
