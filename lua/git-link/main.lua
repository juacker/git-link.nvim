local config = require("git-link.config")

-- Cache OS detection at module load time
local os_name = jit and jit.os or ""

local function redirect_stderr_to_null(command)
	if os_name == "Windows" then
		return command .. " 2>NUL"
	end
	return command .. " 2>/dev/null"
end

local function shellescape(value)
	return vim.fn.shellescape(value)
end

local function git_output(command)
	local output = vim.fn.system(redirect_stderr_to_null("git " .. command))
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return vim.fn.trim(output)
end

local function git_output_lines(command)
	local output = vim.fn.systemlist(redirect_stderr_to_null("git " .. command))
	if vim.v.shell_error ~= 0 then
		return nil
	end
	return output
end

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
		vim.notify(string.format("Failed to start browser command: %s", command), vim.log.levels.ERROR)
		return
	end

	vim.notify("Opening git URL in browser", vim.log.levels.INFO)
end

local function remote_ref_prefix(remote_name)
	return "refs/remotes/" .. remote_name .. "/"
end

local function is_remote_ref(remote_ref, remote_name)
	local prefix = remote_ref_prefix(remote_name)
	return remote_ref:sub(1, #prefix) == prefix
end

local function get_upstream_ref(remote_name)
	local upstream_ref = git_output("rev-parse --symbolic-full-name @{u}")
	if not upstream_ref or upstream_ref == "" or not is_remote_ref(upstream_ref, remote_name) then
		return nil
	end
	return upstream_ref
end

local function get_remote_head_target(remote_name)
	return git_output("symbolic-ref --quiet " .. shellescape(remote_ref_prefix(remote_name) .. "HEAD"))
end

local function remote_refs_containing_commit(remote_name, commit)
	local refs = git_output_lines(
		string.format(
			'for-each-ref --contains=%s --format="%%(refname)" %s',
			shellescape(commit),
			shellescape("refs/remotes/" .. remote_name)
		)
	)
	if not refs then
		return {}
	end

	local unique_refs = {}
	local seen = {}
	for _, remote_ref in ipairs(refs) do
		remote_ref = vim.fn.trim(remote_ref)
		if remote_ref ~= "" and not seen[remote_ref] then
			seen[remote_ref] = true
			table.insert(unique_refs, remote_ref)
		end
	end
	return unique_refs
end

local function remote_ref_priority(remote_ref, upstream_ref, remote_head_ref, remote_head_target)
	if upstream_ref and remote_ref == upstream_ref then
		return 1
	end
	if remote_ref == remote_head_ref or (remote_head_target and remote_ref == remote_head_target) then
		return 2
	end
	return 3
end

local function best_remote_candidate_from_refs(refs, remote_name, upstream_ref, remote_head_ref, remote_head_target, distance)
	local best

	for _, remote_ref in ipairs(refs) do
		remote_ref = vim.fn.trim(remote_ref)
		if is_remote_ref(remote_ref, remote_name) then
			local candidate = {
				ref = remote_ref,
				distance = distance,
				priority = remote_ref_priority(remote_ref, upstream_ref, remote_head_ref, remote_head_target),
			}
			if
				not best
				or candidate.priority < best.priority
				or (candidate.priority == best.priority and candidate.ref < best.ref)
			then
				best = candidate
			end
		end
	end

	return best
end

local function is_better_remote_ref(candidate, current)
	if not current then
		return true
	end
	if candidate.distance ~= current.distance then
		return candidate.distance < current.distance
	end
	if candidate.priority ~= current.priority then
		return candidate.priority < current.priority
	end
	return candidate.ref < current.ref
end

local function get_best_remote_ref_containing_commit(remote_name, commit, distance, upstream_ref, remote_head_ref, remote_head_target)
	local refs = remote_refs_containing_commit(remote_name, commit)
	return best_remote_candidate_from_refs(refs, remote_name, upstream_ref, remote_head_ref, remote_head_target, distance)
end

local function get_remote_boundary_ref(remote_name, upstream_ref, remote_head_ref, remote_head_target)
	local commits = git_output_lines("rev-list --boundary HEAD --not " .. shellescape("--remotes=" .. remote_name))
	if not commits then
		return nil
	end

	local best
	for _, commit in ipairs(commits) do
		if commit:sub(1, 1) == "-" then
			local boundary_commit = commit:sub(2)
			local distance = tonumber(git_output("rev-list --count " .. shellescape(boundary_commit .. "..HEAD")))
			if distance then
				local candidate = get_best_remote_ref_containing_commit(
					remote_name,
					boundary_commit,
					distance,
					upstream_ref,
					remote_head_ref,
					remote_head_target
				)
				if candidate and is_better_remote_ref(candidate, best) then
					best = candidate
				end
			end
		end
	end

	return best and best.ref or nil
end

local function get_closest_remote_ref(remote_name)
	local upstream_ref = get_upstream_ref(remote_name)
	local remote_head_ref = remote_ref_prefix(remote_name) .. "HEAD"
	local remote_head_target = get_remote_head_target(remote_name)

	local containing_head =
		get_best_remote_ref_containing_commit(remote_name, "HEAD", 0, upstream_ref, remote_head_ref, remote_head_target)
	if containing_head then
		return containing_head.ref
	end

	return get_remote_boundary_ref(remote_name, upstream_ref, remote_head_ref, remote_head_target)
end

local function remote_ref_to_branch(remote_ref, remote_name)
	local prefix = remote_ref_prefix(remote_name)
	if remote_ref == prefix .. "HEAD" then
		remote_ref = get_remote_head_target(remote_name) or remote_ref
	end
	if not is_remote_ref(remote_ref, remote_name) then
		return nil
	end
	return remote_ref:sub(#prefix + 1)
end

local function get_current_branch(remote_name)
	local remote_ref = get_closest_remote_ref(remote_name)
	if not remote_ref then
		vim.notify(
			string.format("Could not determine a branch on remote '%s' that shares history with HEAD", remote_name),
			vim.log.levels.ERROR
		)
		return nil
	end

	local branch = remote_ref_to_branch(remote_ref, remote_name)
	if not branch or branch == "" or branch == "HEAD" then
		vim.notify(string.format("Could not resolve remote '%s' HEAD to a branch", remote_name), vim.log.levels.ERROR)
		return nil
	end

	return branch
end

local function get_permalink_ref(remote_name)
	local refs = git_output_lines(
		string.format(
			'for-each-ref --contains HEAD --format="%%(refname)" %s',
			shellescape("refs/remotes/" .. remote_name)
		)
	)
	if refs then
		for _, remote_ref in ipairs(refs) do
			if vim.fn.trim(remote_ref) ~= "" then
				return git_output("rev-parse HEAD")
			end
		end
	end

	vim.notify(
		string.format("HEAD is not present on remote '%s'. Push or fetch before creating a permalink", remote_name),
		vim.log.levels.ERROR
	)
	return nil
end

local function get_remote_url(remote_name)
	remote_name = remote_name or "origin"
	local remote_url = git_output("config --get " .. shellescape("remote." .. remote_name .. ".url"))
	if not remote_url or remote_url == "" then
		vim.notify(
			string.format("No remote '%s' found. Run 'git remote -v' to check configured remotes", remote_name),
			vim.log.levels.ERROR
		)
		return nil
	end

	local rules = config.get_rules()

	-- Apply URL rewrite rules
	for _, rule in ipairs(rules) do
		if remote_url:match(rule.pattern) then
			local final_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
			return final_url, rule.format_url, remote_name
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

local function get_url(opts)
	opts = opts or {}

	-- Call to git rev-parse as a way to ensure this is a valid git repo
	if not git_output("rev-parse --show-toplevel") then
		vim.notify("Current directory is not inside a git repository", vim.log.levels.ERROR)
		return nil
	end

	local cwd = vim.fn.getcwd()
	local filename = vim.fn.expand("%:p"):gsub("\\", "/"):gsub("^" .. cwd:gsub("\\", "/") .. "/", "")

	local relative_filename = git_output("ls-files --full-name " .. shellescape(filename))
	if not relative_filename or relative_filename == "" then
		vim.notify(string.format("File '%s' is not tracked by git", filename), vim.log.levels.ERROR)
		return nil
	end

	local remote_url, format_url, remote_name = get_remote_url()
	if not remote_url or not format_url or not remote_name then
		return nil
	end

	local ref
	if opts.permalink then
		ref = get_permalink_ref(remote_name)
	else
		ref = get_current_branch(remote_name)
	end
	if not ref then
		return nil
	end

	local start_line, end_line = get_line_range()

	local params = {
		branch = ref,
		ref = ref,
		permalink = opts.permalink == true,
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

local function copy_permalink()
	local url = get_url({ permalink = true })
	if url then
		copy_to_clipboard(url)
	end
end

local function open_permalink()
	local url = get_url({ permalink = true })
	if url then
		open_url_in_browser(url)
	end
end

return {
	copy_line_url = copy_line_url,
	open_line_url = open_line_url,
	copy_permalink = copy_permalink,
	open_permalink = open_permalink,
	_private = {
		get_closest_remote_ref = get_closest_remote_ref,
		get_current_branch = get_current_branch,
		get_permalink_ref = get_permalink_ref,
		remote_ref_to_branch = remote_ref_to_branch,
	},
}
