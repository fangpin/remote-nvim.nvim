describe("RemoteNeovim", function()
  local assert = require("luassert.assert")
  local match = require("luassert.match")
  local stub = require("luassert.stub")
  local remote_nvim = require("remote-nvim")

  local neovide_value

  before_each(function()
    neovide_value = vim.g.neovide
  end)

  after_each(function()
    vim.g.neovide = neovide_value
  end)

  describe("default client callback", function()
    it("launches terminal remote UI when Neovide is not active", function()
      vim.g.neovide = false
      local executable_stub = stub(vim.fn, "executable")
      local float_term_stub = stub(require("remote-nvim.ui"), "float_term")

      remote_nvim.default_opts.client_callback(1234, {})

      assert.stub(executable_stub).was.not_called()
      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
    end)

    it("launches Neovide when the entry client is Neovide", function()
      vim.g.neovide = true
      stub(vim.fn, "executable").returns(1)
      local jobstart_stub = stub(vim.fn, "jobstart").returns(42)
      local float_term_stub = stub(require("remote-nvim.ui"), "float_term")

      remote_nvim.default_opts.client_callback(4321, {})

      assert.stub(jobstart_stub).was.called_with({ "neovide", "--server=localhost:4321" }, { detach = true })
      assert.stub(float_term_stub).was.not_called()
    end)

    it("falls back to terminal remote UI when Neovide launch fails", function()
      vim.g.neovide = true
      stub(vim.fn, "executable").returns(1)
      stub(vim.fn, "jobstart").returns(-1)
      local float_term_stub = stub(require("remote-nvim.ui"), "float_term")

      remote_nvim.default_opts.client_callback(1234, {})

      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
    end)
  end)
end)
