# Git-Link for NeoVim

**Git-Link for NeoVim** allows you to quickly navigate from a line of code in Neovim to the corresponding line in a browser, assuming your repository's remote is hosted on platforms like GitHub, GitLab, etc. This plugin is especially useful when you need to share a link to a specific line of code with your colleagues.

## Features

- **Get a sharable URL**: Easily generate a link to the line of code under your cursor, ready to share.
- **Open in Browser**: Instantly open the browser and navigate to the specific line of code under your cursor.

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

## Usage

1. Place the cursor on the desired line of code.
2. Use `<leader>gu` to copy the URL of that line to your clipboard.
3. Alternatively, use `<leader>go` to open the link directly in your browser.

## Demo

[Git-Link Demo](https://github.com/juacker/git-link.nvim/assets/2930882/caadb465-e240-4fcc-ae59-9445b8184fbb)
