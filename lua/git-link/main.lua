local function copy_to_clipboard(text)
	vim.fn.setreg("+", text)
end

local function open_url_in_browser(url)
	local command = string.format("xdg-open %s", url) -- Linux command (using xdg-open)
	vim.fn.jobstart(command, { detach = true, cwd = vim.fn.getcwd() })
end

local function get_remote_url()
	local remote_url = vim.fn.trim(vim.fn.system("git config --get remote.origin.url"))

	if remote_url:match("^ssh://") then
		local domain = remote_url:match("ssh://([^/]+)")
		local gitconfig_url = vim.fn.trim(vim.fn.system("git config --get-urlmatch url.insteadof ssh://" .. domain))

		if gitconfig_url ~= "" then
			local repo_path = remote_url:match(domain .. "/(.+)%.git$")
			if repo_path then
				return gitconfig_url:gsub("%.git$", "") .. repo_path
			end
		end
	end

	return remote_url:gsub("git@([^:]+):", "https://%1/"):gsub("ssh://git@([^:/]+)/", "https://%1/"):gsub("%.git$", "")
end

local function get_current_line_url()
	local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
	local filename = vim.fn.expand("%:p"):gsub("^" .. git_root .. "/", "")
	local linenr = vim.api.nvim_win_get_cursor(0)[1]
	local relative_filename = vim.fn.trim(vim.fn.system("git ls-files --full-name " .. filename))
	local remote_url = get_remote_url()

	return remote_url and string.format("%s/blob/master/%s#L%d", remote_url, relative_filename, linenr) or nil
end

local function copy_line_url()
	local remote_url = get_current_line_url()
	if remote_url then copy_to_clipboard(remote_url) end
end

local function open_line_url()
	local remote_url = get_current_line_url()
	if remote_url then open_url_in_browser(remote_url) end
end

return {
	copy_line_url = copy_line_url,
	open_line_url = open_line_url,
}
