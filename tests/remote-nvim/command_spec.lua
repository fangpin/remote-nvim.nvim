describe("Remote Neovim commands", function()
  local assert = require("luassert.assert")
  local match = require("luassert.match")
  local stub = require("luassert.stub")
  local remote_nvim = require("remote-nvim")

  local command
  local sessions
  local previous_session_provider
  local notify_stub
  local sockconnect_stub
  local rpcrequest_stub
  local chanclose_stub
  local select_stub
  local clipboard_diagnostics_result

  local function make_session(opts)
    opts = opts or {}
    return {
      provider_type = opts.provider_type or "ssh",
      is_remote_server_running = function()
        return opts.running ~= false
      end,
      get_local_neovim_server_port = function()
        return opts.port
      end,
      set_clipboard_diagnostics = opts.set_clipboard_diagnostics,
    }
  end

  local function load_command()
    package.loaded["remote-nvim.command"] = nil
    command = require("remote-nvim.command")
  end

  local function run(args)
    command.RemoteClipboardCheck({ args = args or "" })
  end

  before_each(function()
    sessions = {}
    previous_session_provider = remote_nvim.session_provider
    remote_nvim.session_provider = {
      get_all_sessions = function()
        return sessions
      end,
      get_config_provider = function()
        return {
          get_workspace_config = function()
            return {}
          end,
        }
      end,
    }

    notify_stub = stub(vim, "notify")
    sockconnect_stub = stub(vim.fn, "sockconnect").returns(11)
    clipboard_diagnostics_result = {
      clipboard_option = "unnamedplus",
      clipboard_type = "table",
      clipboard_name = "remote-nvim OSC 52",
      copy_plus = "function",
      copy_star = "function",
      paste_plus = "function",
      paste_star = "function",
      osc52_available = true,
      loaded_clipboard_provider = vim.NIL,
      remote_nvim_clipboard = {
        installed = true,
        provider = "osc52",
        name = "remote-nvim OSC 52",
        install_count = 1,
      },
      ui_count = 1,
    }
    rpcrequest_stub = stub(vim, "rpcrequest").returns(clipboard_diagnostics_result)
    chanclose_stub = stub(vim.fn, "chanclose")
    select_stub = stub(vim.ui, "select")
    load_command()
  end)

  after_each(function()
    notify_stub:revert()
    sockconnect_stub:revert()
    rpcrequest_stub:revert()
    chanclose_stub:revert()
    select_stub:revert()
    remote_nvim.session_provider = previous_session_provider
    package.loaded["remote-nvim.command"] = nil
  end)

  it("detaches one running SSH session", function()
    sessions.host1 = make_session({ port = 1234 })
    sessions.host1.detach_neovim = stub()

    command.RemoteDetach({ args = "host1" })

    assert.stub(sessions.host1.detach_neovim).was.called()
  end)

  it("chooses only running SSH sessions when detaching without a host", function()
    sessions.ssh1 = make_session({ provider_type = "ssh" })
    sessions.devpod1 = make_session({ provider_type = "devpod" })
    sessions.ssh2 = make_session({ provider_type = "ssh" })
    sessions.ssh1.detach_neovim = stub()
    sessions.devpod1.detach_neovim = stub()
    sessions.ssh2.detach_neovim = stub()
    select_stub:revert()
    select_stub = stub(vim.ui, "select").invokes(function(choices, opts, callback)
      assert.same({ "ssh1", "ssh2" }, choices)
      assert.are.equal("Choose active session that needs to be detached", opts.prompt)
      callback("ssh2")
    end)

    command.RemoteDetach({ args = "" })

    assert.stub(sessions.ssh2.detach_neovim).was.called()
    assert.stub(sessions.devpod1.detach_neovim).was_not.called()
  end)

  it("warns when explicit detach target is not an SSH session", function()
    sessions.devpod1 = make_session({ provider_type = "devpod" })
    sessions.devpod1.detach_neovim = stub()

    command.RemoteDetach({ args = "devpod1" })

    assert.stub(sessions.devpod1.detach_neovim).was_not.called()
    assert.stub(notify_stub).was.called_with("Detach is only supported for SSH sessions", vim.log.levels.WARN)
  end)

  it("completes RemoteDetach with only running SSH sessions", function()
    sessions.ssh1 = make_session({ provider_type = "ssh" })
    sessions.devpod1 = make_session({ provider_type = "devpod" })
    sessions.stopped_ssh = make_session({ provider_type = "ssh", running = false })

    local completion = vim.fn.getcompletion("RemoteDetach ", "cmdline")

    assert.same({ "ssh1" }, completion)
  end)

  it("reattaches a detached session from the registry", function()
    local registry = require("remote-nvim.detached_registry")()
    local get_stub = stub(registry, "get").returns({ provider = "ssh", host = "host1", status = "detached" })
    local detached_registry_stub = stub(command, "_detached_registry").returns(registry)
    local session = { reattach_neovim = stub() }
    remote_nvim.session_provider.get_or_initialize_session = stub().returns(session)

    command.RemoteReattach({ args = "host1" })

    assert.stub(remote_nvim.session_provider.get_or_initialize_session).was.called()
    assert.stub(session.reattach_neovim).was.called()

    get_stub:revert()
    detached_registry_stub:revert()
  end)

  it("hides stale detached records when choosing a session to reattach", function()
    local registry = require("remote-nvim.detached_registry")()
    local get_all_stub = stub(registry, "get_all").returns({
      host1 = { provider = "ssh", host = "host1", status = "detached" },
      stale1 = { provider = "ssh", host = "stale1", status = "stale" },
    })
    local detached_registry_stub = stub(command, "_detached_registry").returns(registry)
    local session = { reattach_neovim = stub() }
    remote_nvim.session_provider.get_or_initialize_session = stub().returns(session)
    select_stub:revert()
    select_stub = stub(vim.ui, "select").invokes(function(choices, opts, callback)
      assert.same({ "host1" }, choices)
      assert.are.equal("Choose detached session to reattach", opts.prompt)
      callback("host1")
    end)

    command.RemoteReattach({ args = "" })

    assert.stub(session.reattach_neovim).was.called()

    get_all_stub:revert()
    detached_registry_stub:revert()
  end)

  it("tells explicit stale reattach users to use RemoteKillDetached", function()
    local registry = require("remote-nvim.detached_registry")()
    local get_stub = stub(registry, "get").returns({ provider = "ssh", host = "stale1", status = "stale" })
    local detached_registry_stub = stub(command, "_detached_registry").returns(registry)
    remote_nvim.session_provider.get_or_initialize_session = stub()

    command.RemoteReattach({ args = "stale1" })

    assert.stub(remote_nvim.session_provider.get_or_initialize_session).was_not.called()
    assert.stub(notify_stub).was.called_with(
      "Detached session 'stale1' is stale. Use :RemoteKillDetached stale1 to clear it",
      vim.log.levels.WARN
    )

    get_stub:revert()
    detached_registry_stub:revert()
  end)

  it("completes RemoteReattach with only non-stale detached records", function()
    local registry = require("remote-nvim.detached_registry")()
    local get_all_stub = stub(registry, "get_all").returns({
      host1 = { provider = "ssh", host = "host1", status = "detached" },
      stale1 = { provider = "ssh", host = "stale1", status = "stale" },
    })
    local detached_registry_stub = stub(command, "_detached_registry").returns(registry)

    local completion = vim.fn.getcompletion("RemoteReattach ", "cmdline")

    assert.same({ "host1" }, completion)

    get_all_stub:revert()
    detached_registry_stub:revert()
  end)

  it("kills a detached session", function()
    local registry = require("remote-nvim.detached_registry")()
    local get_stub = stub(registry, "get").returns({ provider = "ssh", host = "host1", status = "detached", remote_pid = "4567" })
    local detached_registry_stub = stub(command, "_detached_registry").returns(registry)
    local session = { kill_detached_neovim = stub() }
    remote_nvim.session_provider.get_or_initialize_session = stub().returns(session)

    command.RemoteKillDetached({ args = "host1" })

    assert.stub(session.kill_detached_neovim).was.called()

    get_stub:revert()
    detached_registry_stub:revert()
  end)

  it("warns when no running sessions exist", function()
    run("")

    assert.stub(notify_stub).was.called_with(match.matches("No active sessions"), vim.log.levels.WARN)
    assert.stub(sockconnect_stub).was_not.called()
  end)

  it("warns when too many host args are provided", function()
    sessions.host1 = make_session({ port = 1234 })

    run("host1 host2")

    assert.stub(notify_stub).was.called_with("Please pass only one host at a time", vim.log.levels.WARN)
    assert.stub(sockconnect_stub).was_not.called()
  end)

  it("warns when the requested host is unknown", function()
    sessions.host1 = make_session({ port = 1234 })

    run("missing")

    assert.stub(notify_stub).was.called_with("No active remote session to 'missing' found", vim.log.levels.WARN)
    assert.stub(sockconnect_stub).was_not.called()
  end)

  it("queries one running session, caches the clipboard diagnostics, and notifies", function()
    local set_clipboard_diagnostics = stub()
    sessions.host1 = make_session({
      port = 1234,
      set_clipboard_diagnostics = function(_, result)
        set_clipboard_diagnostics(result)
      end,
    })

    run("")

    assert.stub(sockconnect_stub).was.called_with("tcp", "localhost:1234", { rpc = true })
    assert.stub(rpcrequest_stub).was.called_with(11, "nvim_exec_lua", match.matches("remote_nvim_clipboard"), {})
    assert.stub(chanclose_stub).was.called_with(11)
    assert.stub(set_clipboard_diagnostics).was.called_with(clipboard_diagnostics_result)
    assert.stub(notify_stub).was.called_with(match.matches("Remote clipboard diagnostics for host1"), vim.log.levels.INFO)
  end)

  it("accepts clipboard options that include unnamedplus", function()
    sessions.host1 = make_session({ port = 1234 })
    rpcrequest_stub:revert()
    rpcrequest_stub = stub(vim, "rpcrequest").returns({
      clipboard_option = "unnamed,unnamedplus",
      clipboard_type = "table",
      clipboard_name = "remote-nvim OSC 52",
      copy_plus = "function",
      copy_star = "function",
      paste_plus = "function",
      paste_star = "function",
      osc52_available = true,
      loaded_clipboard_provider = vim.NIL,
      remote_nvim_clipboard = {
        installed = true,
      },
      ui_count = 1,
    })

    run("host1")

    assert.stub(notify_stub).was.called_with(match.matches("clipboard option: unnamed,unnamedplus"), vim.log.levels.INFO)
  end)

  it("warns when remote clipboard diagnostics are incomplete", function()
    sessions.host1 = make_session({ port = 1234 })
    rpcrequest_stub:revert()
    rpcrequest_stub = stub(vim, "rpcrequest").returns({
      clipboard_option = "unnamedplus",
      clipboard_type = "table",
      clipboard_name = vim.NIL,
      copy_plus = "function",
      copy_star = "function",
      paste_plus = "function",
      paste_star = "function",
      osc52_available = true,
      loaded_clipboard_provider = vim.NIL,
      remote_nvim_clipboard = {
        installed = true,
      },
      ui_count = 1,
    })

    run("host1")

    assert.stub(notify_stub).was.called_with(match.matches("clipboard provider: nil"), vim.log.levels.WARN)
  end)

  it("reports an error when connecting to the local forwarded port fails", function()
    sessions.host1 = make_session({ port = 1234 })
    sockconnect_stub:revert()
    sockconnect_stub = stub(vim.fn, "sockconnect").returns(0)

    run("host1")

    assert.stub(notify_stub).was.called_with(match.matches("Failed to connect"), vim.log.levels.ERROR)
    assert.stub(rpcrequest_stub).was_not.called()
  end)

  it("reports an error when the local forwarded port is missing", function()
    sessions.host1 = make_session({ port = nil })

    run("host1")

    assert.stub(notify_stub).was.called_with(match.matches("No local Neovim server port"), vim.log.levels.ERROR)
    assert.stub(sockconnect_stub).was_not.called()
  end)

  it("reports RPC failure and closes the channel", function()
    sessions.host1 = make_session({ port = 1234 })
    rpcrequest_stub:revert()
    rpcrequest_stub = stub(vim, "rpcrequest").invokes(function()
      error("rpc boom")
    end)

    run("host1")

    assert.stub(notify_stub).was.called_with(match.matches("Failed to query remote clipboard diagnostics"), vim.log.levels.ERROR)
    assert.stub(chanclose_stub).was.called_with(11)
  end)

  it("asks the user to choose when multiple running sessions exist and no host is provided", function()
    sessions.host1 = make_session({ port = 1234 })
    sessions.host2 = make_session({ port = 5678 })
    select_stub:revert()
    select_stub = stub(vim.ui, "select").invokes(function(choices, opts, callback)
      assert.same({ "host1", "host2" }, choices)
      assert.are.equal("Choose remote neovim session for clipboard diagnostics", opts.prompt)
      callback("host2")
    end)

    run("")

    assert.stub(sockconnect_stub).was.called_with("tcp", "localhost:5678", { rpc = true })
  end)

  it("notifies when multiple session selection is cancelled", function()
    sessions.host1 = make_session({ port = 1234 })
    sessions.host2 = make_session({ port = 5678 })
    select_stub:revert()
    select_stub = stub(vim.ui, "select").invokes(function(_, _, callback)
      callback(nil)
    end)

    run("")

    assert.stub(notify_stub).was.called_with("No session selected")
    assert.stub(sockconnect_stub).was_not.called()
  end)
end)
