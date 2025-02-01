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
		vim.notify("Could not determine current branch", vim.log.levels.WARN)
		return "master" -- Default to "master" if the command fails
	end
	local branch = vim.fn.trim(output)
	local _, branch_name = branch:match("^([^/]+)/(.+)$")
	return branch_name or "master" -- Return branch name without remote prefix, or "master" if not found
end

local function get_remote_url()
	local remote_url = vim.fn.trim(vim.fn.system("git config --get remote.origin.url"))
	if vim.v.shell_error ~= 0 then
		vim.notify("Not a git repository or no remote 'origin' found", vim.log.levels.ERROR)
		return nil
	end

	local rules = config.get_rules()

	-- Apply URL rewrite rules
	for _, rule in ipairs(rules) do
		if remote_url:match(rule.pattern) then
			local final_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
			return final_url, rule.format_url
		end
	end

	-- If no rule matches, return nil
	vim.notify("No matching URL rule found for remote: " .. remote_url, vim.log.levels.ERROR)
	return nil
end

local function get_line_range()
	local mode = vim.fn.mode()
	if mode:match("[vV]") then
		local vstart = vim.fn.getpos("v")
		local vcurrent = vim.fn.getcurpos()
		return math.min(vstart[2], vcurrent[2]), math.max(vstart[2], vcurrent[2])
	end

	local current = vim.fn.getcurpos()
	return current[2], current[2]
end

local function get_url()
	-- Check if we're in a git repository
	local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
	if vim.v.shell_error ~= 0 then
		vim.notify("Not a git repository", vim.log.levels.ERROR)
		return nil
	end

	local filename = vim.fn.expand("%:p"):gsub("^" .. git_root .. "/", "")

	-- Check if file is tracked by git
	local relative_filename = vim.fn.trim(vim.fn.system("git ls-files --full-name " .. filename))
	if vim.v.shell_error ~= 0 or relative_filename == "" then
		vim.notify("File is not tracked by git", vim.log.levels.ERROR)
		return nil
	end

	local remote_url, format_url = get_remote_url()
	if not remote_url or not format_url then
		-- get_remote_url already showed an error
		return nil
	end

	local branch = get_current_branch()
	local start_line, end_line = get_line_range()

	local params = {
		branch = branch,
		file_path = relative_filename,
		start_line = start_line,
		end_line = end_line,
	}
	return format_url(remote_url, params)
end

local function copy_line_url()
	local url = get_url()
	if url then
		copy_to_clipboard(url)
		vim.notify("Git URL copied to clipboard", vim.log.levels.INFO)
	end
end

local function open_line_url()
	local url = get_url()
	if url then
		open_url_in_browser(url)
		vim.notify("Opening git URL in browser", vim.log.levels.INFO)
	end
end

return {
	copy_line_url = copy_line_url,
	open_line_url = open_line_url,
}
