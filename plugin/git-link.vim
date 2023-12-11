vim.api.nvim_set_keymap(
  "n",
  "<leader>gu",
  ':lua require("plugins.git-link.main").copy_line_url()<CR>',
  { noremap = true, silent = true }
)

vim.api.nvim_set_keymap(
  "n",
  "<leader>go",
  ':lua require("plugins.git-link.main").open_line_url()<CR>',
  { noremap = true, silent = true }
)
