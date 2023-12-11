# Git-Link for NeoVim

Share easily the link to a specific line of code in a repository you are working on, while browsing it in Neovim.

`<leader>gu` -> get the link to the URL of the original repository of the code line under your cursor
`<leader>go` -> open in the browser the URL directly to the code line under your cursor.

## Configuration with LazyVim

```javascript
  {
    "juacker/git-link.nvim",
    keys = {
      {
        "<leader>gu",
        function() require("git-link.main").copy_line_url() end,
        desc = "copy code line url",
      },
      {
        "<leader>go",
        function() require("git-link.main").open_line_url() end,
        desc = "open code line in browser",
      },
    },
  }
```


https://github.com/juacker/git-link.nvim/assets/2930882/caadb465-e240-4fcc-ae59-9445b8184fbb

