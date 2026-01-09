local config = require("git-link.config")

describe("git-link.config", function()
	before_each(function()
		config._reset()
	end)

	describe("setup", function()
		it("should initialize with empty user rules", function()
			config.setup({})
			local rules = config.get_rules()
			-- Should only have default rules (3)
			assert.equals(3, #rules)
		end)

		it("should accept custom url_rules", function()
			config.setup({
				url_rules = {
					{
						pattern = "^custom://(.+)$",
						replace = "https://custom.com/%1",
						format_url = function(base_url, params)
							return base_url .. "/" .. params.file_path
						end,
					},
				},
			})
			local rules = config.get_rules()
			-- 1 custom + 3 default
			assert.equals(4, #rules)
		end)

		it("should place user rules before default rules", function()
			local custom_pattern = "^custom://(.+)$"
			config.setup({
				url_rules = {
					{
						pattern = custom_pattern,
						replace = "https://custom.com/%1",
						format_url = function() return "" end,
					},
				},
			})
			local rules = config.get_rules()
			assert.equals(custom_pattern, rules[1].pattern)
		end)

		it("should reset user rules when setup is called again", function()
			config.setup({
				url_rules = {
					{ pattern = "test1", replace = "r1", format_url = function() return "" end },
					{ pattern = "test2", replace = "r2", format_url = function() return "" end },
				},
			})
			assert.equals(5, #config.get_rules())

			config.setup({
				url_rules = {
					{ pattern = "test3", replace = "r3", format_url = function() return "" end },
				},
			})
			assert.equals(4, #config.get_rules())
		end)
	end)

	describe("get_rules", function()
		it("should return default rules when no custom rules set", function()
			config.setup({})
			local rules = config.get_rules()
			assert.equals(3, #rules)
		end)

		it("should return combined rules with user rules first", function()
			config.setup({
				url_rules = {
					{ pattern = "user1", replace = "r1", format_url = function() return "" end },
					{ pattern = "user2", replace = "r2", format_url = function() return "" end },
				},
			})
			local rules = config.get_rules()
			assert.equals(5, #rules)
			assert.equals("user1", rules[1].pattern)
			assert.equals("user2", rules[2].pattern)
		end)
	end)

	describe("get_default_rule", function()
		it("should return the first default rule (HTTPS)", function()
			local rule = config.get_default_rule()
			assert.is_not_nil(rule)
			assert.is_not_nil(rule.pattern)
			assert.is_not_nil(rule.replace)
			assert.is_not_nil(rule.format_url)
		end)
	end)

	describe("default rules format_url", function()
		local test_params = {
			branch = "main",
			file_path = "lua/git-link/init.lua",
			start_line = 10,
			end_line = 10,
		}

		it("should format single line URL correctly", function()
			local rule = config.get_default_rule()
			local url = rule.format_url("https://github.com/user/repo", test_params)
			assert.equals("https://github.com/user/repo/blob/main/lua/git-link/init.lua#L10", url)
		end)

		it("should format line range URL correctly", function()
			local rule = config.get_default_rule()
			local params = vim.tbl_extend("force", test_params, { end_line = 20 })
			local url = rule.format_url("https://github.com/user/repo", params)
			assert.equals("https://github.com/user/repo/blob/main/lua/git-link/init.lua#L10-L20", url)
		end)
	end)

	describe("URL pattern matching", function()
		before_each(function()
			config.setup({})
		end)

		it("should match HTTPS URLs", function()
			local rules = config.get_rules()
			local https_url = "https://github.com/user/repo"
			local matched = false
			for _, rule in ipairs(rules) do
				if https_url:match(rule.pattern) then
					matched = true
					break
				end
			end
			assert.is_true(matched)
		end)

		it("should match SSH git@ URLs", function()
			local rules = config.get_rules()
			local ssh_url = "git@github.com:user/repo.git"
			local matched = false
			for _, rule in ipairs(rules) do
				if ssh_url:match(rule.pattern) then
					matched = true
					break
				end
			end
			assert.is_true(matched)
		end)

		it("should match SSH protocol URLs", function()
			local rules = config.get_rules()
			local ssh_url = "ssh://git@github.com/user/repo.git"
			local matched = false
			for _, rule in ipairs(rules) do
				if ssh_url:match(rule.pattern) then
					matched = true
					break
				end
			end
			assert.is_true(matched)
		end)
	end)

	describe("URL transformation", function()
		before_each(function()
			config.setup({})
		end)

		it("should transform HTTPS URL correctly", function()
			local rules = config.get_rules()
			local input_url = "https://github.com/user/repo"
			for _, rule in ipairs(rules) do
				if input_url:match(rule.pattern) then
					local result = input_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					assert.equals("https://github.com/user/repo", result)
					break
				end
			end
		end)

		it("should transform SSH git@ URL correctly", function()
			local rules = config.get_rules()
			local input_url = "git@github.com:user/repo.git"
			for _, rule in ipairs(rules) do
				if input_url:match(rule.pattern) then
					local result = input_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					assert.equals("https://github.com/user/repo", result)
					break
				end
			end
		end)

		it("should transform SSH protocol URL correctly", function()
			local rules = config.get_rules()
			local input_url = "ssh://git@github.com/user/repo.git"
			for _, rule in ipairs(rules) do
				if input_url:match(rule.pattern) then
					local result = input_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					assert.equals("https://github.com/user/repo", result)
					break
				end
			end
		end)
	end)
end)
