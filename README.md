# Git-Link for NeoVim

**Git-Link for NeoVim** allows you to quickly navigate from a line of code in Neovim to the corresponding line in a browser, assuming your repository's remote is hosted on platforms like GitHub, GitLab, etc. This plugin is especially useful when you need to share a link to a specific line of code with your colleagues.

## Features

- **Get a sharable URL**: Easily generate a link to the line of code under your cursor, ready to share.
- **Open in Browser**: Instantly open the browser and navigate to the specific line of code under your cursor.
- **Configurable URL Rules**: Support for custom Git hosting platforms through configurable URL rewriting rules.

### Key Mappings

- `<leader>gu`: Copies the URL of the line of code under your cursor to your clipboard.
- `<leader>go`: Opens the browser and navigates directly to the line of code under your cursor.

## Installation and Configuration

To use Git-Link with [LazyVim](https://github.com/LazyVim/LazyVim), add the following configuration to your Neovim setup:

```lua
{
  "juacker/git-link.nvim",
  keys = {
    {
      "<leader>gu",
      function() require("git-link.main").copy_line_url() end,
      desc = "Copy code line URL to clipboard",
    },
    {
      "<leader>go",
      function() require("git-link.main").open_line_url() end,
      desc = "Open code line in browser",
    },
  },
}
```

### Default URL Rules

The plugin comes with built-in support for the following Git remote URL formats:

- HTTPS URLs (e.g., `https://github.com/user/repo`)
- Git SSH URLs (e.g., `git@github.com:user/repo`)
- SSH protocol URLs (e.g., `ssh://git@github.com/user/repo`)

These URLs are automatically converted to browser-friendly formats for GitHub, GitLab, and similar platforms.

### Custom URL Rules

You can add custom URL rules to support different Git hosting platforms. Each rule consists of:

- `pattern`: A Lua pattern to match your Git remote URL format
- `replace`: A template to convert the URL to HTTPS format
- `format_url`: A function that generates the final browser URL using:
  - `base_url`: The resulting URL after replacing the pattern
  - `params`: A table containing:
    - `branch`: Current git branch
    - `file_path`: Path to the file
    - `line_number`: Current line number

Custom rules are processed before default rules, allowing you to override the default behavior for specific repositories.

You can configure as many rules as you need. Here is an example of a configuration adding one rule:

```lua
{
  "juacker/git-link.nvim",
  opts = {
    -- Optional: Add custom URL rules for your Git hosting platform
    url_rules = {
      -- Example rule for Gerrit (might need adjustment for your Gerrit instance)
      {
        pattern = "^ssh://([^:]+):29418/(.+)$",
        replace = "https://%1/plugins/gitiles/%2",
        format_url = function(base_url, params)
          -- Generates Gerrit Gitiles URLs: https://host/plugins/gitiles/project/+/refs/heads/branch/path#number
          return string.format("%s/+/refs/heads/%s/%s#%d",
            base_url,
            params.branch,
            params.file_path,
            params.line_number
          )
        end,
      },
    },
  },
  keys = {
    {
      "<leader>gu",
      function() require("git-link.main").copy_line_url() end,
      desc = "Copy code line URL to clipboard",
    },
    {
      "<leader>go",
      function() require("git-link.main").open_line_url() end,
      desc = "Open code line in browser",
    },
  },
}
```

## Usage

1. Place the cursor on the desired line of code.
2. Use `<leader>gu` to copy the URL of that line to your clipboard.
3. Alternatively, use `<leader>go` to open the link directly in your browser.

## Demo

[Git-Link Demo](https://github.com/juacker/git-link.nvim/assets/2930882/caadb465-e240-4fcc-ae59-9445b8184fbb)
