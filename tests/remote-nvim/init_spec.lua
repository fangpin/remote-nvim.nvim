describe("RemoteNeovim", function()
  local assert = require("luassert.assert")
  local match = require("luassert.match")
  local stub = require("luassert.stub")
  local remote_nvim = require("remote-nvim")

  describe("default client callback", function()
    local float_term_stub
    local previous_neovide
    local previous_neovide_channel_id
    local previous_clipboard
    local previous_loaded_clipboard_provider

    before_each(function()
      previous_neovide = vim.g.neovide
      previous_neovide_channel_id = vim.g.neovide_channel_id
      previous_clipboard = vim.g.clipboard
      previous_loaded_clipboard_provider = vim.g.loaded_clipboard_provider
      float_term_stub = stub(require("remote-nvim.ui"), "float_term")
    end)

    after_each(function()
      float_term_stub:revert()
      vim.g.neovide = previous_neovide
      vim.g.neovide_channel_id = previous_neovide_channel_id
      vim.g.clipboard = previous_clipboard
      vim.g.loaded_clipboard_provider = previous_loaded_clipboard_provider
    end)

    it("launches terminal remote UI", function()
      remote_nvim.default_opts.client_callback(1234, {})

      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
    end)

    it("reloads Neovide clipboard before launching nested remote UI", function()
      vim.g.neovide = true
      vim.g.neovide_channel_id = 42
      vim.g.clipboard = nil

      remote_nvim.default_opts.client_callback(1234, {})

      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
      assert.are.equal("neovide", vim.g.clipboard.name)
      assert.is_function(vim.g.clipboard.copy["+"])
    end)
  end)
end)
