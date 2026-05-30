describe("RemoteNeovim", function()
  local assert = require("luassert.assert")
  local match = require("luassert.match")
  local stub = require("luassert.stub")
  local remote_nvim = require("remote-nvim")

  describe("default client callback", function()
    it("launches terminal remote UI", function()
      local float_term_stub = stub(require("remote-nvim.ui"), "float_term")

      remote_nvim.default_opts.client_callback(1234, {})

      assert.stub(float_term_stub).was.called_with("nvim --server localhost:1234 --remote-ui", match.is_function())
    end)
  end)
end)
