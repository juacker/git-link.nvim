local function create_config()
	-- Private state
	local default_rules = {
		-- Handles HTTPS URLs (input: https://host/org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^https?://([^/]+)/(.+)$",
			replace = "https://%1/%2",
			format_url = function(base_url, params)
				local single_line_url =
					string.format("%s/blob/%s/%s#L%d", base_url, params.branch, params.file_path, params.start_line)

				if params.start_line == params.end_line then
					return single_line_url
				end

				return string.format("%s-L%d", single_line_url, params.end_line)
			end,
		},
		-- Handles SSH URLs with git@ format (input: git@host:org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^git@([^:]+):",
			replace = "https://%1/",
			format_url = function(base_url, params)
				local single_line_url =
					string.format("%s/blob/%s/%s#L%d", base_url, params.branch, params.file_path, params.start_line)

				if params.start_line == params.end_line then
					return single_line_url
				end

				return string.format("%s-L%d", single_line_url, params.end_line)
			end,
		},
		-- Handles SSH protocol URLs (input: ssh://git@host/org/repo)
		-- Generates GitHub/GitLab/Bitbucket style URLs: https://host/org/repo/blob/branch/path#Lnumber
		{
			pattern = "^ssh://git@([^:/]+)/",
			replace = "https://%1/",
			format_url = function(base_url, params)
				local single_line_url =
					string.format("%s/blob/%s/%s#L%d", base_url, params.branch, params.file_path, params.start_line)

				if params.start_line == params.end_line then
					return single_line_url
				end

				return string.format("%s-L%d", single_line_url, params.end_line)
			end,
		},
	}

	local user_rules = {}

	local config = {}

	function config.setup(opts)
		user_rules = {}

		if opts and opts.url_rules then
			for _, rule in ipairs(opts.url_rules) do
				table.insert(user_rules, rule)
			end
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

	-- Add reset function for tests
	function config._reset()
		user_rules = {}
	end

	return config
end

return create_config()
