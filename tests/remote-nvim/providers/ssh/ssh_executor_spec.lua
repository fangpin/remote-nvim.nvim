local assert = require("luassert.assert")
local match = require("luassert.match")
local stub = require("luassert.stub")

describe("SSH Executor", function()
  local SSHExecutor = require("remote-nvim.providers.ssh.ssh_executor")
  local host = "remote-host"
  local conn_opts = ""
  local other_conn_opts = "-p 2310"
  local remote_nvim = require("remote-nvim")
  local remote_nvim_config_copy
  local prompts = {
    {
      match = "password:",
      type = "secret",
      input_prompt = "Enter password: ",
      value_type = "static",
      value = "",
    },
    {
      match = "continue connecting (yes/no/[fingerprint])?",
      type = "plain",
      input_prompt = "Do you want to continue connection (yes/no)? ",
      value_type = "dynamic",
      value = "",
    },
  }

  local executor, other_executor, executor_run_job_stub, other_executor_run_job_stub
  before_each(function()
    remote_nvim_config_copy = vim.deepcopy(remote_nvim.config)
    remote_nvim.config = vim.deepcopy(remote_nvim.default_opts)

    executor = SSHExecutor(host, conn_opts)
    executor._ssh_prompts = prompts
    executor_run_job_stub = stub(executor, "run_executor_job")

    other_executor = SSHExecutor(host, other_conn_opts)
    other_executor_run_job_stub = stub(other_executor, "run_executor_job")
  end)

  after_each(function()
    remote_nvim.config = remote_nvim_config_copy
  end)

  describe("should correctly generate rsync connection options", function()
    it("and append recursive flag mandatorily", function()
      assert.equals("-r", executor.rsync_conn_opts)
    end)

    it("by wrapping ssh connection options if passed", function()
      assert.equals("-r -e 'ssh -p 2310'", other_executor.rsync_conn_opts)
    end)
  end)

  describe("should run upload job with correct arguments", function()
    it("for default port rsync", function()
      executor:upload("local-path", "remote-path")
      local rsync_command = "rsync -r --exclude .git local-path remote-host:remote-path"
      assert.stub(executor_run_job_stub).was.called_with(executor, rsync_command, { compression = {} })
    end)

    it("for specified port rsync", function()
      other_executor:upload("local-path", "remote-path")
      local other_rsync_command = "rsync -r -e 'ssh -p 2310' --exclude .git local-path remote-host:remote-path"
      assert
        .stub(other_executor_run_job_stub).was
        .called_with(other_executor, other_rsync_command, { compression = {} })
    end)

    describe("when compression is turned on", function()
      it("in default scenario on macOS", function()
        stub(require("remote-nvim.utils"), "os_name").returns("macOS")
        executor:upload(
          "local-dir/first-path local-dir/second-path local-dir/third-path",
          "remote-path",
          { compression = { enabled = true } }
        )
        local upload_command =
          "tar czf - --no-xattrs --exclude .git --disable-copyfile  --numeric-owner --no-acls --no-same-owner --no-same-permissions -C local-dir first-path second-path third-path | ssh remote-host 'tar xvzf - -C remote-path && chown -R $(whoami) remote-path'"
        assert
          .stub(executor_run_job_stub).was
          .called_with(executor, upload_command, { compression = { enabled = true } })
      end)

      it("in default scenario on Linux", function()
        stub(require("remote-nvim.utils"), "os_name").returns("Linux")
        executor:upload(
          "local-dir/first-path local-dir/second-path local-dir/third-path",
          "remote-path",
          { compression = { enabled = true } }
        )
        local upload_command =
          "tar czf - --no-xattrs --exclude .git   --numeric-owner --no-acls --no-same-owner --no-same-permissions -C local-dir first-path second-path third-path | ssh remote-host 'tar xvzf - -C remote-path && chown -R $(whoami) remote-path'"
        assert
          .stub(executor_run_job_stub).was
          .called_with(executor, upload_command, { compression = { enabled = true } })
      end)

      it("and parent directory cannot be determined", function()
        assert.error_matches(
          function()
            executor:upload(
              "local-dir1/first-path local-dir2/second-path",
              "remote-path",
              { compression = { enabled = true } }
            )
          end,
          "All directories to be uploaded from local should share a common ancestor. Passed paths: local-dir1/first-path local-dir2/second-path",
          nil,
          true
        )
      end)

      it("when additional compression arguments are passed", function()
        stub(require("remote-nvim.utils"), "os_name").returns("macOS")
        executor:upload(
          "local-dir/first-path local-dir/second-path local-dir/third-path",
          "remote-path",
          { compression = { enabled = true, additional_opts = { "--exclude-vcs" } } }
        )
        local upload_command =
          "tar czf - --no-xattrs --exclude .git --disable-copyfile --exclude-vcs --numeric-owner --no-acls --no-same-owner --no-same-permissions -C local-dir first-path second-path third-path | ssh remote-host 'tar xvzf - -C remote-path && chown -R $(whoami) remote-path'"
        assert
          .stub(executor_run_job_stub).was
          .called_with(executor, upload_command, { compression = { enabled = true, additional_opts = { "--exclude-vcs" } } })
      end)
    end)
  end)

  describe("should run download job with correct arguments", function()
    it("for default port rsync", function()
      executor:download("remote-path", "local-path")
      local rsync_command = "rsync -r remote-host:remote-path local-path"
      assert.stub(executor_run_job_stub).was.called_with(executor, rsync_command, {})
    end)

    it("for specified port rsync", function()
      other_executor:download("remote-path", "local-path")
      local other_rsync_command = "rsync -r -e 'ssh -p 2310' remote-host:remote-path local-path"
      assert.stub(other_executor_run_job_stub).was.called_with(other_executor, other_rsync_command, {})
    end)
  end)

  it("starts a forward-only SSH job", function()
    executor:start_port_forward("12345", "32123")

    assert
      .stub(executor_run_job_stub).was
      .called_with(match.is_ref(executor), "ssh -N -L 12345:localhost:32123 remote-host", { detach = true })
  end)

  it("runs a remote command detached and records its pidfile", function()
    executor:run_detached_server_command("nvim --listen 0.0.0.0:32123 --headless", "~/.remote-nvim/workspace/nvim.pid")

    assert.stub(executor_run_job_stub).was.called_with(
      match.is_ref(executor),
      match.matches(
        "ssh remote%-host 'sh %-c '.*rm %-f ~/.remote%-nvim/workspace/nvim%.pid; nohup sh %-c .*exec nvim %-%-listen 0%.0%.0%.0:32123 %-%-headless.*tee ~/.remote%-nvim/workspace/nvim%.pid.*'"
      ),
      match.is_table()
    )
  end)

  it(
    "runs a detached remote command with environment assignments by exec-ing the command, not the assignment",
    function()
      executor:run_detached_server_command(
        "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/test/.config nvim --listen 0.0.0.0:32123 --headless",
        "~/.remote-nvim/workspace/nvim.pid"
      )

      local command = executor_run_job_stub.calls[1].refs[2]
      assert.is_nil(command:find("exec XDG_CONFIG_HOME", 1, true))
      assert.is_not_nil(command:find("XDG_CONFIG_HOME=~/.remote-nvim/workspaces/test/.config exec nvim", 1, true))
    end
  )

  it("runs a detached remote command in a working directory before exec-ing the server", function()
    executor:run_detached_server_command(
      "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/test/.config nvim --listen 0.0.0.0:32123 --headless",
      "~/.remote-nvim/workspace/nvim.pid",
      { cwd = "/home/test user/project" }
    )

    local command = executor_run_job_stub.calls[1].refs[2]
    assert.is_nil(command:find("exec cd", 1, true))
    assert.is_not_nil(command:find("/home/test user/project", 1, true))
    assert.is_not_nil(command:find("XDG_CONFIG_HOME=~/.remote-nvim/workspaces/test/.config exec nvim", 1, true))
  end)

  it("keeps tilde working directories expandable for detached commands", function()
    local exec_command = executor:_build_detached_exec_command(
      "nvim --listen 0.0.0.0:32123 --headless",
      "~/gpu/lab 7"
    )

    assert.equals("cd ~/'gpu/lab 7' && exec nvim --listen 0.0.0.0:32123 --headless", exec_command)
  end)

  describe("should correctly run command job with correct arguments", function()
    it("for simple commands", function()
      executor:run_command("uname")
      local ssh_command = "ssh remote-host 'uname'"
      assert.stub(executor_run_job_stub).was.called_with(executor, ssh_command, { exit_cb = nil })
    end)

    it("for commands that require shell escaping", function()
      executor:run_command("echo '12'")
      local ssh_command = [[ssh remote-host 'echo '\''12'\''']]
      assert.stub(executor_run_job_stub).was.called_with(executor, ssh_command, { exit_cb = nil })
    end)
  end)

  describe("should parse job output correctly to handle prompts", function()
    local pp

    before_each(function()
      pp = stub(executor, "_process_prompt")
      executor:reset()
    end)

    it("when prompt match is passed in a single call", function()
      executor:process_stdout({ "pass", "word:" })
      assert.stub(pp).was.called_with(executor, prompts[1])
    end)

    it("when prompt match is passed over multiple calls", function()
      executor:process_stdout({ "p" })
      assert.stub(pp).was_not.called_with(executor, prompts[1])
      executor:process_stdout({ "assword:" })
      assert.stub(pp).was.called_with(executor, prompts[1])
    end)

    it("when prompt match contains special characters", function()
      executor:process_stdout({ "continue connecting (yes/no/[fingerprint])?" })
      assert.stub(pp).was.called_with(executor, prompts[2])
    end)
  end)

  describe("should correctly handle prompt", function()
    local pi = stub(require("remote-nvim.providers.utils"), "get_input")
    pi.returns("test")
    local chan_send = stub(vim.api, "nvim_chan_send")

    before_each(function()
      executor:reset()
      pi:clear()
      chan_send:clear()
    end)

    it("of static type", function()
      executor:_process_prompt(prompts[1])
      assert.stub(pi).was.called_with(prompts[1].input_prompt, prompts[1].type)
      assert.equals("test", executor._job_prompt_responses[prompts[1].match])
      assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
    end)

    it("of type dynamic", function()
      executor:_process_prompt(prompts[2])
      assert.stub(pi).was.called_with(prompts[2].input_prompt, prompts[2].type)
      assert.not_equals("test", executor._job_prompt_responses[prompts[2].match])
      assert.stub(chan_send).was.called_with(executor._job_id, "test\n")
    end)
  end)

  describe("should correctly handle cached values", function()
    local pi = stub(require("remote-nvim.providers.utils"), "get_input")
    pi.returns("test")
    stub(vim.api, "nvim_chan_send")

    before_each(function()
      executor = SSHExecutor(host, conn_opts)
      pi:clear()
    end)

    it("on job success", function()
      executor:process_stdout({ prompts[1].match })
      executor:process_job_completion(0)
      assert.equals("test", executor._job_prompt_responses[prompts[1].match])
      assert.equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
    end)

    it("on job failure", function()
      executor:process_stdout({ prompts[1].match })
      executor:process_job_completion(127)
      assert.equals("test", executor._job_prompt_responses[prompts[1].match])
      assert.not_equals(executor._ssh_prompts[1].value, executor._job_prompt_responses[prompts[1].match])
    end)
  end)
end)
