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
    local rpcrequest_stub
    local list_uis_stub
    local ui_send_stub

    before_each(function()
      previous_neovide = vim.g.neovide
      previous_neovide_channel_id = vim.g.neovide_channel_id
      previous_clipboard = vim.g.clipboard
      previous_loaded_clipboard_provider = vim.g.loaded_clipboard_provider
      float_term_stub = stub(require("remote-nvim.ui"), "float_term")
      rpcrequest_stub = nil
      list_uis_stub = nil
      ui_send_stub = nil
    end)

    after_each(function()
      float_term_stub:revert()
      if rpcrequest_stub then
        rpcrequest_stub:revert()
      end
      if list_uis_stub then
        list_uis_stub:revert()
      end
      if ui_send_stub then
        ui_send_stub:revert()
      end
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

    it("uses Neovide clipboard RPC argument order for fallback provider", function()
      rpcrequest_stub = stub(vim, "rpcrequest")
      vim.g.neovide = true
      vim.g.neovide_channel_id = 42
      vim.g.clipboard = nil

      remote_nvim.default_opts.client_callback(1234, {})
      vim.g.clipboard.copy["+"]({ "copied text" })

      assert.stub(rpcrequest_stub).was.called_with(42, "neovide.set_clipboard", { "copied text" }, "+")
    end)

    it("falls back to attached UI channel for Neovide clipboard RPC", function()
      rpcrequest_stub = stub(vim, "rpcrequest")
      list_uis_stub = stub(vim.api, "nvim_list_uis").returns({
        { chan = 24 },
      })
      vim.g.neovide = true
      vim.g.neovide_channel_id = nil
      vim.g.clipboard = nil

      remote_nvim.default_opts.client_callback(1234, {})
      vim.g.clipboard.copy["*"]({ "primary text" })

      assert.stub(rpcrequest_stub).was.called_with(24, "neovide.set_clipboard", { "primary text" }, "*")
    end)

    it("installs a local OSC 52 clipboard bridge for terminal clients without a provider", function()
      ui_send_stub = stub(vim.api, "nvim_ui_send")
      vim.g.neovide = false
      vim.g.clipboard = nil
      vim.g.loaded_clipboard_provider = nil

      remote_nvim.default_opts.client_callback(1234, {})
      vim.g.clipboard.copy["+"]({ "copied text" })

      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
      assert.are.equal("remote-nvim local OSC 52", vim.g.clipboard.name)
      assert.stub(ui_send_stub).was.called()
    end)

    it("preserves an existing local clipboard provider for terminal clients", function()
      local existing_clipboard = {
        name = "existing",
        copy = {
          ["+"] = function() end,
          ["*"] = function() end,
        },
        paste = {
          ["+"] = function() end,
          ["*"] = function() end,
        },
      }
      vim.g.neovide = false
      vim.g.clipboard = existing_clipboard

      remote_nvim.default_opts.client_callback(1234, {})

      assert.are.equal("existing", vim.g.clipboard.name)
      assert.are.equal(existing_clipboard.copy["+"], vim.g.clipboard.copy["+"])
      assert.are.equal(existing_clipboard.paste["+"], vim.g.clipboard.paste["+"])
    end)
  end)
end)
