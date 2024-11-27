local function create_config()
	-- Private state
	local default_rules = {
		-- Handles HTTPS URLs (input: https://host/org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^https?://([^/]+)/(.+)$",
			replace = "https://%1/%2",
			format_url = function(base_url, params)
				if params.start_line == params.end_line then
					return string.format(
						"%s/blob/%s/%s#L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line
					)
				else
					return string.format(
						"%s/blob/%s/%s#L%d-L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line,
						params.end_line
					)
				end
			end,
		},
		-- Handles SSH URLs with git@ format (input: git@host:org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^git@([^:]+):",
			replace = "https://%1/",
			format_url = function(base_url, params)
				if params.start_line == params.end_line then
					return string.format(
						"%s/blob/%s/%s#L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line
					)
				else
					return string.format(
						"%s/blob/%s/%s#L%d-L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line,
						params.end_line
					)
				end
			end,
		},
		-- Handles SSH protocol URLs (input: ssh://git@host/org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^ssh://git@([^:/]+)/",
			replace = "https://%1/",
			format_url = function(base_url, params)
				if params.start_line == params.end_line then
					return string.format(
						"%s/blob/%s/%s#L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line
					)
				else
					return string.format(
						"%s/blob/%s/%s#L%d-L%d",
						base_url,
						params.branch,
						params.file_path,
						params.start_line,
						params.end_line
					)
				end
			end,
		},
	}

	local user_rules = {}

	local config = {}

	function config.setup(opts)
		if opts and opts.url_rules then
			user_rules = opts.url_rules
		end
	end

	function config.get_rules()
		local combined = {}
		for _, rule in ipairs(user_rules) do
			table.insert(combined, rule)
		end
		for _, rule in ipairs(default_rules) do
			table.insert(combined, rule)
		end
		return combined
	end

	function config.get_default_rule()
		return default_rules[1]
	end

	return config
end

return create_config()
