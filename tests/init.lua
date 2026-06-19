local test_root = vim.fn.fnamemodify(".tests", ":p"):gsub("[/\\]+$", "")
local lazy_root = test_root .. "/data/nvim/lazy"
local lazypath = lazy_root .. "/lazy.nvim"

vim.env.LAZY_STDPATH = test_root

if vim.fn.isdirectory(lazypath) == 0 then
  vim.fn.mkdir(lazy_root, "p")

  local clone_result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    error(("Failed to clone lazy.nvim: %s"):format(vim.trim(clone_result)))
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy.minit").repro({
  spec = {
    { dir = (vim.uv or vim.loop).cwd(), config = true },
  },
})
