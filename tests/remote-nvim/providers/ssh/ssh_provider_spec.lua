describe("SSH Provider", function()
  local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
  local assert = require("luassert.assert")
  local mock = require("luassert.mock")
  local remote_nvim = require("remote-nvim")
  local stub = require("luassert.stub")
  local progress_viewer
  local provider
  local remote_nvim_config_copy

  local function seed_workspace_config(ssh_provider)
    ssh_provider._config_provider:add_workspace_config(ssh_provider.unique_host_id, {
      provider = ssh_provider.provider_type,
      host = ssh_provider.host,
      connection_options = ssh_provider.conn_opts,
      remote_neovim_home = "~/.remote-nvim",
      config_copy = true,
      client_auto_start = nil,
      workspace_id = "ajfdalfj",
      neovim_version = "stable",
      os = "Linux",
      arch = "x86_64",
      neovim_install_method = "binary",
      working_dirs = {},
    })
    ssh_provider:_setup_workspace_variables()
  end

  before_each(function()
    progress_viewer = mock(require("remote-nvim.ui.progressview"), true)
    remote_nvim_config_copy = vim.deepcopy(remote_nvim.config)
  end)

  after_each(function()
    remote_nvim.config = remote_nvim_config_copy
    if provider ~= nil then
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end
  end)

  it("should remove 'ssh' prefix from connection options (if present)", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "ssh localhost -p 3011" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    -- Even if there are additional whitespaces
    ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { " ssh localhost -p 3011" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)
  end)

  it("should correctly set unique host ID when passed manually as an option", function()
    local unique_host_id = "custom-host-id"
    local provider = SSHProvider({
      host = "localhost",
      unique_host_id = unique_host_id,
      progress_view = progress_viewer,
    })
    assert.equals(unique_host_id, provider.unique_host_id)
  end)

  describe("should correctly set provider type", function()
    it("when it is provided manually", function()
      local provider = SSHProvider({
        host = "localhost",
        provider_type = "devpod",
        progress_view = progress_viewer,
      })
      assert.equals("devpod", provider.provider_type)
    end)

    it("when not provided to 'ssh'", function()
      local provider = SSHProvider({
        host = "localhost",
        progress_view = progress_viewer,
      })
      assert.equals("ssh", provider.provider_type)
    end)
  end)

  it("should remove host name from connection options (if present)", function()
    local ssh_provider = SSHProvider({
      host = "localhost",
      conn_opts = { "localhost -p 3011" },
      progress_view = progress_viewer,
    })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { " localhost" }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "localhost " }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({
      host = "user@localhost",
      conn_opts = { "user@localhost" },
      progress_view = progress_viewer,
    })
    assert.equals("", ssh_provider.conn_opts)
  end)

  it("should remove '-N' ssh option from connection options (if present)", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "-p 3011 -N" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-N" }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)
  end)

  it("should consolidate multiple whitespaces into one in connection options", function()
    local ssh_provider = SSHProvider({
      host = "localhost",
      conn_opts = { "  -p 3011      -L 2011:localhost:3011    " },
      progress_view = progress_viewer,
    })
    assert.equals("-p 3011 -L 2011:localhost:3011", ssh_provider.conn_opts)
  end)

  it("should generate unique host ID correctly", function()
    local ssh_provider = SSHProvider({ host = "localhost", progress_view = progress_viewer })
    assert.equals("localhost", ssh_provider.unique_host_id)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p 3011" }, progress_view = progress_viewer })
    assert.equals("localhost:3011", ssh_provider.unique_host_id)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p" }, progress_view = progress_viewer })
    assert.equals("localhost", ssh_provider.unique_host_id)
  end)

  it("creates a dedicated executor for long-lived SSH jobs", function()
    provider = SSHProvider({ host = "localhost", conn_opts = { "-p 2222" }, progress_view = progress_viewer })

    assert.is_not_nil(provider.server_executor)
    assert.is_true(provider.server_executor ~= provider.executor)
    assert.equals(provider.executor.host, provider.server_executor.host)
    assert.equals(provider.executor.conn_opts, provider.server_executor.conn_opts)
  end)

  it("keeps detached launch server state on the dedicated executor", function()
    local local_free_port_stub
    local executor_status_calls = 0
    local server_status_calls = 0
    local stdout_call_count = 0

    provider = SSHProvider({ host = "remote-host", progress_view = progress_viewer })
    seed_workspace_config(provider)

    remote_nvim.config.remote.detach.enabled = true
    stub(provider, "is_remote_server_running").returns(false)
    stub(provider.executor, "run_command")
    stub(provider.executor, "last_job_status", function()
      executor_status_calls = executor_status_calls + 1
      return 0
    end)
    stub(provider.executor, "job_stdout", function()
      stdout_call_count = stdout_call_count + 1
      if stdout_call_count == 1 then
        return { "32123" }
      end
      return { "4567" }
    end)
    stub(provider.server_executor, "run_detached_server_command")
    stub(provider.server_executor, "start_port_forward")
    stub(provider.server_executor, "last_job_status", function()
      server_status_calls = server_status_calls + 1
      return 0
    end)
    stub(provider.server_executor, "last_job_id").returns(99)
    stub(provider.server_executor, "job_stdout").returns({ "4567" })
    local_free_port_stub = stub(require("remote-nvim.providers.utils"), "find_free_port").returns(52232)

    provider:_launch_remote_neovim_server()

    assert.equals(1, executor_status_calls)
    assert.equals(1, server_status_calls)
    assert.equals(99, provider._remote_server_process_id)
    assert.equals("4567", provider._remote_server_pid)

    local_free_port_stub:revert()
  end)

  it("uses the dedicated executor when reattaching a detached SSH session", function()
    local local_free_port_stub
    local start_port_forward_stub
    local detached_registry_stub
    local launch_local_client_stub
    local registry = require("remote-nvim.detached_registry")()

    provider = SSHProvider({ host = "remote-host", progress_view = progress_viewer })

    stub(provider, "_remote_pid_alive").returns(true)
    stub(provider, "_remote_port_alive").returns(true)
    launch_local_client_stub = stub(provider, "_launch_local_neovim_client")
    detached_registry_stub = stub(provider, "_detached_registry").returns(registry)
    start_port_forward_stub = stub(provider.server_executor, "start_port_forward")
    stub(provider.server_executor, "last_job_id").returns(99)
    stub(provider.executor, "last_job_id").returns(12)
    local_free_port_stub = stub(require("remote-nvim.providers.utils"), "find_free_port").returns(12345)

    provider:reattach_neovim({ remote_pid = "4567", remote_port = "32123", status = "detached" })

    assert.stub(start_port_forward_stub).was.called()
    assert.equals(99, provider._remote_server_process_id)
    assert.equals(12345, provider._local_free_port)
    assert.equals("32123", provider._remote_free_port)
    assert.equals("4567", provider._remote_server_pid)
    assert.stub(launch_local_client_stub).was.called()

    detached_registry_stub:revert()
    local_free_port_stub:revert()
  end)
end)
