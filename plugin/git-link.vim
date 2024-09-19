local function set_keymap(mode, lhs, rhs, opts)
  vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
end

set_keymap("n", "<leader>gu", ':lua require("plugins.git-link.main").copy_line_url()<CR>', { noremap = true, silent = true })
set_keymap("n", "<leader>go", ':lua require("plugins.git-link.main").open_line_url()<CR>', { noremap = true, silent = true })
