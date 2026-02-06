if vim.g.loaded_surround then
  return
end
vim.g.loaded_surround = true

local surround = require("surround")

vim.keymap.set("n", "ds", surround.delete_surround, { silent = true, desc = "Delete surrounding pair" })
vim.keymap.set("n", "ys", surround.add_surround, { silent = true, expr = true, desc = "Add surround (motion)" })
vim.keymap.set("n", "yss", surround.add_surround_line, { silent = true, expr = true, desc = "Add surround (line)" })
vim.keymap.set("x", "gs", function()
  -- Exit visual mode first so '< and '> marks are set, then run surround
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  surround.visual_surround()
end, { silent = true, desc = "Surround selection" })
