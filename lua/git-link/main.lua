local config = require("git-link.config")

-- Cache OS detection at module load time
local os_name = jit and jit.os or ""

local function copy_to_clipboard(text)
	vim.fn.setreg("+", text)
	vim.notify("Git URL copied to clipboard", vim.log.levels.INFO)
end

local function open_url_in_browser(url)
	local command
	if os_name == "Windows" then
		command = string.format('start "" "%s"', url)
	elseif os_name == "OSX" then
		command = string.format("open %s", url)
	elseif os_name == "Linux" then
		command = string.format("xdg-open %s", url)
	else
		vim.notify(
			string.format("Unsupported OS '%s': Unable to open URL in browser", os_name ~= "" and os_name or "unknown"),
			vim.log.levels.ERROR
		)
		return
	end

	local job_id = vim.fn.jobstart(command, {
		detach = true,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 then
				vim.schedule(function()
					vim.notify(
						string.format("Failed to open browser (exit code %d). URL: %s", exit_code, url),
						vim.log.levels.WARN
					)
				end)
			end
		end,
	})

	if job_id <= 0 then
		vim.notify(
			string.format("Failed to start browser command: %s", command),
			vim.log.levels.ERROR
		)
		return
	end

	vim.notify("Opening git URL in browser", vim.log.levels.INFO)
end

local function get_current_branch()
	local command
	if os_name == "Windows" then
		command = "git rev-parse --abbrev-ref @{u} 2>NUL"
	else
		command = "git rev-parse --abbrev-ref @{u} 2>/dev/null"
	end

	local output = vim.fn.system(command)
	if vim.v.shell_error ~= 0 then
		vim.notify("Could not determine upstream branch (no tracking branch set?), falling back to 'master'", vim.log.levels.WARN)
		return "master"
	end

	local branch = vim.fn.trim(output)
	local _, branch_name = branch:match("^([^/]+)/(.+)$")
	return branch_name or "master"
end

local function get_remote_url()
	local remote_url = vim.fn.trim(vim.fn.system("git config --get remote.origin.url"))
	if vim.v.shell_error ~= 0 then
		vim.notify("No remote 'origin' found. Run 'git remote -v' to check configured remotes", vim.log.levels.ERROR)
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
	-- Call to git rev-parse as a way to ensure this is a valid git repo
	vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
	if vim.v.shell_error ~= 0 then
		vim.notify("Current directory is not inside a git repository", vim.log.levels.ERROR)
		return nil
	end

	local cwd = vim.fn.getcwd()
	local filename = vim.fn.expand("%:p"):gsub("\\", "/"):gsub("^" .. cwd:gsub("\\", "/") .. "/", "")

	local relative_filename = vim.fn.trim(vim.fn.system("git ls-files --full-name " .. filename))
	if vim.v.shell_error ~= 0 or relative_filename == "" then
		vim.notify(string.format("File '%s' is not tracked by git", filename), vim.log.levels.ERROR)
		return nil
	end

	local remote_url, format_url = get_remote_url()
	if not remote_url or not format_url then
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
	end
end

local function open_line_url()
	local url = get_url()
	if url then
		open_url_in_browser(url)
	end
end

return {
	copy_line_url = copy_line_url,
	open_line_url = open_line_url,
}
