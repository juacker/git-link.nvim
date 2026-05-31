local git_link = require("git-link")
local main = require("git-link.main")
local config = require("git-link.config")

describe("git-link", function()
	before_each(function()
		config._reset()
	end)

	describe("module exports", function()
		it("should export setup function", function()
			assert.is_function(git_link.setup)
		end)

		it("should export copy_line_url function", function()
			assert.is_function(git_link.copy_line_url)
		end)

		it("should export open_line_url function", function()
			assert.is_function(git_link.open_line_url)
		end)

		it("should export copy_permalink function", function()
			assert.is_function(git_link.copy_permalink)
		end)

		it("should export open_permalink function", function()
			assert.is_function(git_link.open_permalink)
		end)
	end)

	describe("setup", function()
		it("should accept empty options", function()
			assert.has_no.errors(function()
				git_link.setup({})
			end)
		end)

		it("should accept url_rules option", function()
			assert.has_no.errors(function()
				git_link.setup({
					url_rules = {
						{
							pattern = "test",
							replace = "test",
							format_url = function() return "" end,
						},
					},
				})
			end)
		end)
	end)

	-- Integration tests that run in a real git repo
	describe("integration", function()
		local original_dir

		before_each(function()
			original_dir = vim.fn.getcwd()
			config._reset()
			config.setup({})
		end)

		after_each(function()
			vim.cmd("cd " .. original_dir)
		end)

		it("should work in the plugin's own git repo", function()
			-- The plugin directory itself is a git repo
			local plugin_dir = vim.fn.fnamemodify(
				vim.fn.resolve(debug.getinfo(1).source:sub(2)),
				":h:h"
			)
			vim.cmd("cd " .. plugin_dir)

			-- Open a known file
			vim.cmd("edit lua/git-link/init.lua")

			-- The function should not error (even if it warns about branch)
			assert.has_no.errors(function()
				git_link.copy_line_url()
			end)
		end)
	end)
end)

describe("remote ref selection", function()
	local original_dir
	local temp_dirs

	local function run(command, cwd)
		local previous_dir = vim.fn.getcwd()
		if cwd then
			vim.cmd("cd " .. vim.fn.fnameescape(cwd))
		end

		local output = vim.fn.system(command)
		local exit_code = vim.v.shell_error

		if cwd then
			vim.cmd("cd " .. vim.fn.fnameescape(previous_dir))
		end

		assert.equals(0, exit_code, "Command failed: " .. command .. "\n" .. output)
		return vim.fn.trim(output)
	end

	local function create_repo()
		local root = vim.fn.tempname()
		local origin = root .. "/origin.git"
		local worktree = root .. "/worktree"

		vim.fn.mkdir(root, "p")
		table.insert(temp_dirs, root)

		run("git init --bare " .. vim.fn.shellescape(origin))
		run("git init " .. vim.fn.shellescape(worktree))
		run("git config user.email test@example.com", worktree)
		run("git config user.name Tester", worktree)

		vim.fn.writefile({ "line one" }, worktree .. "/file.lua")
		run("git add file.lua", worktree)
		run("git commit -m initial", worktree)
		run("git branch -M main", worktree)
		run("git remote add origin " .. vim.fn.shellescape(origin), worktree)
		run("git push -u origin main", worktree)
		run("git remote set-head origin main", worktree)

		return {
			origin = origin,
			worktree = worktree,
		}
	end

	before_each(function()
		original_dir = vim.fn.getcwd()
		temp_dirs = {}
	end)

	after_each(function()
		vim.cmd("cd " .. vim.fn.fnameescape(original_dir))
		for _, temp_dir in ipairs(temp_dirs) do
			vim.fn.delete(temp_dir, "rf")
		end
	end)

	it("uses origin HEAD for an unpushed local branch off main", function()
		local repo = create_repo()
		run("git checkout -b feature/local", repo.worktree)
		vim.fn.writefile({ "line one", "local change" }, repo.worktree .. "/file.lua")
		run("git add file.lua", repo.worktree)
		run("git commit -m local-change", repo.worktree)

		vim.cmd("cd " .. vim.fn.fnameescape(repo.worktree))

		assert.equals("main", main._private.get_current_branch("origin"))
	end)

	it("uses the closest remote branch for an unpushed local branch", function()
		local repo = create_repo()
		run("git checkout -b v1.2.x main", repo.worktree)
		vim.fn.writefile({ "line one", "release change" }, repo.worktree .. "/file.lua")
		run("git add file.lua", repo.worktree)
		run("git commit -m release-change", repo.worktree)
		run("git push -u origin v1.2.x", repo.worktree)

		run("git checkout -b hotfix/local", repo.worktree)
		vim.fn.writefile({ "line one", "release change", "hotfix change" }, repo.worktree .. "/file.lua")
		run("git add file.lua", repo.worktree)
		run("git commit -m hotfix-change", repo.worktree)

		vim.cmd("cd " .. vim.fn.fnameescape(repo.worktree))

		assert.equals("v1.2.x", main._private.get_current_branch("origin"))
	end)

	it("prefers the current branch upstream when remote refs tie", function()
		local repo = create_repo()
		run("git checkout -b tracked main", repo.worktree)
		run("git push -u origin tracked", repo.worktree)

		vim.cmd("cd " .. vim.fn.fnameescape(repo.worktree))

		assert.equals("tracked", main._private.get_current_branch("origin"))
	end)

	it("returns HEAD sha for permalinks when HEAD is on origin", function()
		local repo = create_repo()
		local head_sha = run("git rev-parse HEAD", repo.worktree)

		vim.cmd("cd " .. vim.fn.fnameescape(repo.worktree))

		assert.equals(head_sha, main._private.get_permalink_ref("origin"))
	end)

	it("does not return a permalink ref when HEAD is not on origin", function()
		local repo = create_repo()
		run("git checkout -b feature/local", repo.worktree)
		vim.fn.writefile({ "line one", "local change" }, repo.worktree .. "/file.lua")
		run("git add file.lua", repo.worktree)
		run("git commit -m local-change", repo.worktree)

		vim.cmd("cd " .. vim.fn.fnameescape(repo.worktree))

		assert.is_nil(main._private.get_permalink_ref("origin"))
	end)
end)

-- Tests for internal helpers that we can access via the module
describe("git-link internals", function()
	describe("os detection", function()
		it("should detect a valid OS", function()
			local os_name = jit and jit.os or ""
			-- Should be one of the supported OS types or empty
			local valid_os = os_name == "Windows"
				or os_name == "OSX"
				or os_name == "Linux"
				or os_name == ""
			assert.is_true(valid_os, "OS should be Windows, OSX, Linux, or empty")
		end)
	end)
end)

-- Tests for URL generation end-to-end using config rules
describe("URL generation", function()
	before_each(function()
		config._reset()
		config.setup({})
	end)

	describe("with HTTPS remote", function()
		it("should generate correct GitHub URL", function()
			local rules = config.get_rules()
			local remote_url = "https://github.com/user/repo"
			local params = {
				branch = "main",
				file_path = "src/index.js",
				start_line = 42,
				end_line = 42,
			}

			for _, rule in ipairs(rules) do
				if remote_url:match(rule.pattern) then
					local base_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					local url = rule.format_url(base_url, params)
					assert.equals("https://github.com/user/repo/blob/main/src/index.js#L42", url)
					return
				end
			end
			assert.fail("No rule matched HTTPS URL")
		end)

		it("should generate correct GitLab URL", function()
			local rules = config.get_rules()
			local remote_url = "https://gitlab.com/user/repo"
			local params = {
				branch = "develop",
				file_path = "lib/utils.lua",
				start_line = 10,
				end_line = 20,
			}

			for _, rule in ipairs(rules) do
				if remote_url:match(rule.pattern) then
					local base_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					local url = rule.format_url(base_url, params)
					assert.equals("https://gitlab.com/user/repo/blob/develop/lib/utils.lua#L10-L20", url)
					return
				end
			end
			assert.fail("No rule matched HTTPS URL")
		end)
	end)

	describe("with SSH remote", function()
		it("should generate correct URL from git@ format", function()
			local rules = config.get_rules()
			local remote_url = "git@github.com:user/repo.git"
			local params = {
				branch = "feature/test",
				file_path = "README.md",
				start_line = 1,
				end_line = 1,
			}

			for _, rule in ipairs(rules) do
				if remote_url:match(rule.pattern) then
					local base_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					local url = rule.format_url(base_url, params)
					assert.equals("https://github.com/user/repo/blob/feature/test/README.md#L1", url)
					return
				end
			end
			assert.fail("No rule matched SSH URL")
		end)

		it("should generate correct URL from ssh:// format", function()
			local rules = config.get_rules()
			local remote_url = "ssh://git@github.com/user/repo.git"
			local params = {
				branch = "main",
				file_path = "src/app.py",
				start_line = 100,
				end_line = 150,
			}

			for _, rule in ipairs(rules) do
				if remote_url:match(rule.pattern) then
					local base_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					local url = rule.format_url(base_url, params)
					assert.equals("https://github.com/user/repo/blob/main/src/app.py#L100-L150", url)
					return
				end
			end
			assert.fail("No rule matched SSH protocol URL")
		end)
	end)

	describe("with custom rules", function()
		it("should use custom rule when pattern matches", function()
			config.setup({
				url_rules = {
					{
						pattern = "^git@enterprise%.example%.com:(.+)$",
						replace = "https://enterprise.example.com/%1",
						format_url = function(base_url, params)
							-- Custom format for enterprise GitLab
							return string.format(
								"%s/-/blob/%s/%s#L%d",
								base_url,
								params.branch,
								params.file_path,
								params.start_line
							)
						end,
					},
				},
			})

			local rules = config.get_rules()
			local remote_url = "git@enterprise.example.com:team/project.git"
			local params = {
				branch = "main",
				file_path = "src/main.rs",
				start_line = 50,
				end_line = 50,
			}

			for _, rule in ipairs(rules) do
				if remote_url:match(rule.pattern) then
					local base_url = remote_url:gsub(rule.pattern, rule.replace):gsub("%.git$", "")
					local url = rule.format_url(base_url, params)
					assert.equals("https://enterprise.example.com/team/project/-/blob/main/src/main.rs#L50", url)
					return
				end
			end
			assert.fail("No rule matched custom enterprise URL")
		end)
	end)
end)
