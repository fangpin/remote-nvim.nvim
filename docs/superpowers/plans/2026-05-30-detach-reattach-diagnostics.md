# Detach/Reattach Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SSH-first detached remote Neovim session management and upgrade `:RemoteInfo` with runtime diagnostics.

**Architecture:** Add a focused detached-session registry next to the existing workspace config, then extend provider lifecycle APIs for SSH detach/reattach/kill. Runtime diagnostics remain provider-owned state and are rendered through the existing ProgressView session info pane with a new refreshable section.

**Tech Stack:** Neovim Lua plugin, middleclass-style objects, Plenary/Busted tests, SSH command execution through existing provider executors.

---

## File Structure

- Create `lua/remote-nvim/detached_registry.lua` — persistent detached runtime registry backed by `stdpath("data")/remote-nvim/detached.json`.
- Modify `lua/remote-nvim/providers/provider.lua` — add provider state for remote port/PID/detached status, lifecycle APIs, runtime diagnostics APIs, and RemoteInfo refresh integration.
- Modify `lua/remote-nvim/providers/ssh/ssh_provider.lua` only if provider-specific capability checks are cleaner there than in base provider.
- Modify `lua/remote-nvim/providers/ssh/ssh_executor.lua` — add forward-only SSH job helper if the provider needs a clean API for reattach tunnels.
- Modify `lua/remote-nvim/command.lua` — add `:RemoteDetach`, `:RemoteReattach`, `:RemoteKillDetached`; teach `:RemoteInfo` to surface detached records when no active session exists; cache clipboard diagnostics on sessions.
- Modify `lua/remote-nvim/ui/progressview.lua` — add a refreshable `Runtime diagnostics` session info section.
- Add tests under `tests/remote-nvim/detached_registry_spec.lua`, extend `tests/remote-nvim/providers/provider_spec.lua`, `tests/remote-nvim/providers/ssh/ssh_executor_spec.lua`, `tests/remote-nvim/command_spec.lua`, and `tests/remote-nvim/ui/progressview_spec.lua`.
- Modify `README.md` and `doc/remote-nvim.txt` with commands, SSH-only scope, stale behavior, and RemoteInfo diagnostics.

## Task 1: Detached registry

**Files:**
- Create: `lua/remote-nvim/detached_registry.lua`
- Create: `tests/remote-nvim/detached_registry_spec.lua`

- [ ] **Step 1: Write failing registry tests**

Create `tests/remote-nvim/detached_registry_spec.lua` with tests that use a temp data path override by stubbing `vim.fn.stdpath` before requiring the registry:

```lua
describe("DetachedRegistry", function()
  local assert = require("luassert.assert")
  local stub = require("luassert.stub")
  local registry
  local stdpath_stub
  local tmpdir

  local function load_registry()
    package.loaded["remote-nvim.detached_registry"] = nil
    registry = require("remote-nvim.detached_registry")()
  end

  before_each(function()
    tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    stdpath_stub = stub(vim.fn, "stdpath").returns(tmpdir)
    load_registry()
  end)

  after_each(function()
    stdpath_stub:revert()
    package.loaded["remote-nvim.detached_registry"] = nil
    vim.fn.delete(tmpdir, "rf")
  end)

  it("starts empty when detached registry file is missing", function()
    assert.same({}, registry:get_all())
  end)

  it("adds, updates, and removes detached records", function()
    registry:upsert("host-a", {
      provider = "ssh",
      host = "host-a",
      remote_port = "32123",
      remote_pid = "4455",
      status = "detached",
    })

    assert.equals("32123", registry:get("host-a").remote_port)

    registry:mark_stale("host-a")
    assert.equals("stale", registry:get("host-a").status)

    registry:remove("host-a")
    assert.same({}, registry:get("host-a"))
  end)

  it("loads persisted records from disk", function()
    registry:upsert("host-a", { provider = "ssh", host = "host-a", status = "detached" })
    load_registry()

    assert.equals("detached", registry:get("host-a").status)
  end)

  it("falls back to an empty registry when the file is corrupt", function()
    vim.fn.writefile({ "not json" }, tmpdir .. "/remote-nvim/detached.json")
    load_registry()

    assert.same({}, registry:get_all())
  end)
end)
```

- [ ] **Step 2: Run registry tests and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/detached_registry_spec.lua
```

Expected: FAIL because `remote-nvim.detached_registry` does not exist.

- [ ] **Step 3: Implement the registry**

Create `lua/remote-nvim/detached_registry.lua`:

```lua
local Path = require("plenary.path")

---@class remote-nvim.DetachedRegistry: remote-nvim.Object
---@field private _path table
---@field private _data table<string, table>
local DetachedRegistry = require("remote-nvim.middleclass")("DetachedRegistry")

function DetachedRegistry:init()
  self._path = Path:new({ vim.fn.stdpath("data"), require("remote-nvim.constants").PLUGIN_NAME, "detached.json" })
  self._path:touch({ mode = 493, parents = true })

  local raw = self._path:read()
  if raw == "" then
    self._data = {}
    return
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  self._data = ok and type(decoded) == "table" and decoded or {}
end

function DetachedRegistry:_write()
  self._path:write(vim.json.encode(self._data), "w")
end

function DetachedRegistry:get_all()
  return self._data
end

function DetachedRegistry:get(host_id)
  return self._data[host_id] or {}
end

function DetachedRegistry:upsert(host_id, record)
  self._data[host_id] = vim.tbl_extend("force", self:get(host_id), record)
  self:_write()
  return self._data[host_id]
end

function DetachedRegistry:mark_stale(host_id)
  return self:upsert(host_id, { status = "stale", last_seen_at = os.time() })
end

function DetachedRegistry:remove(host_id)
  self._data[host_id] = nil
  self:_write()
end

return DetachedRegistry
```

- [ ] **Step 4: Run registry tests and verify GREEN**

Run:

```sh
make test-file FILE=tests/remote-nvim/detached_registry_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Commit registry**

```sh
git add lua/remote-nvim/detached_registry.lua tests/remote-nvim/detached_registry_spec.lua
git commit -m "feat: add detached session registry"
```

## Task 2: Provider runtime state and diagnostics section

**Files:**
- Modify: `lua/remote-nvim/providers/provider.lua`
- Modify: `lua/remote-nvim/ui/progressview.lua`
- Test: `tests/remote-nvim/providers/provider_spec.lua`
- Test: `tests/remote-nvim/ui/progressview_spec.lua`

- [ ] **Step 1: Write failing ProgressView refresh test**

In `tests/remote-nvim/ui/progressview_spec.lua`, add a test that calls a new `set_session_section` API twice and verifies the section does not duplicate:

```lua
it("refreshes session section nodes without duplicating the section", function()
  progress_view:set_session_section("Runtime diagnostics", "runtime_node", {
    { key = "State", value = "active" },
  })
  progress_view:set_session_section("Runtime diagnostics", "runtime_node", {
    { key = "State", value = "detached" },
    { key = "Remote PID", value = "1234" },
  })

  local runtime_roots = vim.tbl_filter(function(node)
    return node.value == "Runtime diagnostics"
  end, progress_view.session_info_pane_tree.nodes.by_id)

  assert.are.equal(1, #runtime_roots)
end)
```

If `nodes.by_id` is not directly available in the current tree object, inspect existing progress view tests and assert through the rendered buffer lines instead.

- [ ] **Step 2: Run ProgressView test and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/ui/progressview_spec.lua
```

Expected: FAIL because `set_session_section` does not exist.

- [ ] **Step 3: Implement `set_session_section`**

In `lua/remote-nvim/ui/progressview.lua`, add a public method:

```lua
function ProgressView:set_session_section(title, holds, entries)
  local existing_root
  for _, node in pairs(self.session_info_pane_tree.nodes.by_id) do
    if node.type == "root_node" and node.value == title then
      existing_root = node
      break
    end
  end

  if existing_root then
    for _, child_id in ipairs(vim.deepcopy(existing_root.children_ids or {})) do
      self.session_info_pane_tree:remove_node(child_id)
    end
  else
    self:add_session_node({ value = title, holds = holds, type = "root_node" })
    for _, node in pairs(self.session_info_pane_tree.nodes.by_id) do
      if node.type == "root_node" and node.value == title then
        existing_root = node
        break
      end
    end
  end

  for _, entry in ipairs(entries) do
    self:add_session_node({ type = holds, key = entry.key, value = entry.value })
  end

  self.session_info_pane_tree:render(self.session_info_tree_render_linenr)
end
```

If `remove_node` is not available on the Nui tree, implement the same behavior by rebuilding the session info tree roots and re-adding existing Config/Local/Remote sections plus the requested section. Keep the method small and covered by the test.

- [ ] **Step 4: Write failing provider diagnostics tests**

In `tests/remote-nvim/providers/provider_spec.lua`, add tests that expect provider runtime fields to be reported. Use the existing `progress_viewer` mock and assert `set_session_section` is called:

```lua
it("adds runtime diagnostics to session info", function()
  provider._local_free_port = 12345
  provider._remote_free_port = "32123"
  provider._remote_server_pid = "4567"
  provider._remote_server_process_id = 99
  provider._last_exit_code = 1
  provider._last_reconnect_reason = "unexpected exit"

  provider:_add_session_info()

  assert.stub(progress_viewer.set_session_section).was.called_with(match.is_ref(progress_viewer), "Runtime diagnostics", "runtime_node", match.is_table())
end)
```

- [ ] **Step 5: Run provider tests and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: FAIL because provider does not call `set_session_section`.

- [ ] **Step 6: Implement provider diagnostics state**

In `lua/remote-nvim/providers/provider.lua`:

- Initialize new fields in `Provider:init` or `_reset`:

```lua
self._remote_free_port = nil
self._remote_server_pid = nil
self._detached_state = nil
self._last_exit_code = nil
self._last_reconnect_reason = nil
self._last_clipboard_diagnostics = nil
```

- Store remote free port in `_launch_remote_neovim_server()`:

```lua
self._remote_free_port = remote_free_port
```

- Add:

```lua
function Provider:set_clipboard_diagnostics(result)
  self._last_clipboard_diagnostics = result
end

function Provider:_runtime_diagnostics_entries()
  local reconnect = remote_nvim.config.remote.reconnect or {}
  return {
    { key = "State", value = self._detached_state or (self:is_remote_server_running() and "active" or "stopped") },
    { key = "Local job ID", value = self._remote_server_process_id },
    { key = "Local port", value = self._local_free_port },
    { key = "Remote port", value = self._remote_free_port },
    { key = "Remote PID", value = self._remote_server_pid },
    { key = "Reconnect", value = reconnect.enabled and "enabled" or "disabled" },
    { key = "Reconnect attempt", value = ("%s/%s"):format(self._reconnect_attempt or 0, reconnect.max_attempts or 0) },
    { key = "Last exit code", value = self._last_exit_code },
    { key = "Last reconnect reason", value = self._last_reconnect_reason },
    { key = "Clipboard", value = self._last_clipboard_diagnostics and "checked" or "not checked yet" },
  }
end
```

- Call this from `_add_session_info()`:

```lua
if self.progress_viewer.set_session_section then
  self.progress_viewer:set_session_section("Runtime diagnostics", "runtime_node", self:_runtime_diagnostics_entries())
end
```

- In `_handle_remote_server_exit(exit_code, node)`, store `self._last_exit_code = exit_code` and set `_last_reconnect_reason` when reconnect is scheduled or skipped.

- [ ] **Step 7: Run provider and ProgressView tests**

Run:

```sh
make test-file FILE=tests/remote-nvim/ui/progressview_spec.lua
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: PASS.

- [ ] **Step 8: Commit diagnostics panel support**

```sh
git add lua/remote-nvim/providers/provider.lua lua/remote-nvim/ui/progressview.lua tests/remote-nvim/providers/provider_spec.lua tests/remote-nvim/ui/progressview_spec.lua
git commit -m "feat: add runtime diagnostics to remote info"
```

## Task 3: SSH detach provider lifecycle

**Files:**
- Modify: `lua/remote-nvim/providers/provider.lua`
- Modify: `lua/remote-nvim/providers/ssh/ssh_executor.lua`
- Test: `tests/remote-nvim/providers/provider_spec.lua`
- Test: `tests/remote-nvim/providers/ssh/ssh_executor_spec.lua`

- [ ] **Step 1: Write failing SSH executor forward-only test**

In `tests/remote-nvim/providers/ssh/ssh_executor_spec.lua`, add:

```lua
it("starts a forward-only SSH job", function()
  executor:start_port_forward("12345", "32123")

  assert.stub(run_executor_job_stub).was.called_with(
    match.is_ref(executor),
    "ssh -N -L 12345:localhost:32123 test-host",
    match.is_table()
  )
end)
```

Adjust the exact expected string to match existing test setup host/connection options.

- [ ] **Step 2: Run SSH executor spec and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/providers/ssh/ssh_executor_spec.lua
```

Expected: FAIL because `start_port_forward` does not exist.

- [ ] **Step 3: Implement forward-only SSH helper**

In `lua/remote-nvim/providers/ssh/ssh_executor.lua`, add:

```lua
function SSHExecutor:start_port_forward(local_port, remote_port, job_opts)
  job_opts = job_opts or {}
  local forward_opts = ("-N -L %s:localhost:%s"):format(local_port, remote_port)
  local conn_opts = self.ssh_conn_opts == "" and forward_opts or (self.ssh_conn_opts .. " " .. forward_opts)
  local host_conn_opts = conn_opts == "" and self.host or conn_opts .. " " .. self.host
  return self:run_executor_job(("%s %s"):format(self.ssh_binary, host_conn_opts), job_opts)
end
```

- [ ] **Step 4: Write failing provider detach tests**

In `tests/remote-nvim/providers/provider_spec.lua`, add tests for:

```lua
it("detaches an SSH remote server by persisting runtime metadata", function()
  local registry = mock(require("remote-nvim.detached_registry"), true)
  provider.provider_type = "ssh"
  provider._local_free_port = 12345
  provider._remote_free_port = "32123"
  provider._remote_server_pid = "4567"
  provider._remote_server_process_id = 99
  stub(provider, "is_remote_server_running").returns(true)
  stub(vim.fn, "jobstop")

  provider:detach_neovim()

  assert.stub(registry.upsert).was.called()
  assert.are.equal("detached", provider._detached_state)
end)

it("rejects detach for non-SSH providers", function()
  provider.provider_type = "devpod"
  provider:detach_neovim()
  assert.stub(vim.notify).was.called_with(match.matches("Detach is only supported for SSH"), vim.log.levels.WARN)
end)
```

Use existing test mocking patterns. Revert stubs in `after_each`.

- [ ] **Step 5: Run provider spec and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: FAIL because `detach_neovim` does not exist.

- [ ] **Step 6: Implement provider detach**

In `lua/remote-nvim/providers/provider.lua`, add:

```lua
function Provider:_detached_registry()
  return require("remote-nvim.detached_registry")()
end

function Provider:_detached_record(status)
  return {
    provider = self.provider_type,
    host = self.host,
    connection_options = self.conn_opts,
    workspace_id = self._workspace_id,
    remote_neovim_home = self._remote_neovim_home,
    working_dir = self._remote_working_dir,
    remote_port = self._remote_free_port,
    remote_pid = self._remote_server_pid,
    remote_servername = self._remote_free_port and ("localhost:%s"):format(self._remote_free_port) or nil,
    neovim_version = self._remote_neovim_version,
    created_at = os.time(),
    last_seen_at = os.time(),
    status = status,
  }
end

function Provider:detach_neovim()
  if self.provider_type ~= "ssh" then
    vim.notify("Detach is only supported for SSH sessions", vim.log.levels.WARN)
    return
  end
  if not self:is_remote_server_running() then
    vim.notify("No running remote Neovim server to detach", vim.log.levels.WARN)
    return
  end

  self:_detached_registry():upsert(self.unique_host_id, self:_detached_record("detached"))
  if self._remote_server_process_id then
    vim.fn.jobstop(self._remote_server_process_id)
  end
  self._remote_server_process_id = nil
  self._local_free_port = nil
  self._detached_state = "detached"
  vim.notify(("Detached remote Neovim session '%s'"):format(self.unique_host_id), vim.log.levels.INFO)
end
```

If existing `jobstop` handling triggers `_handle_remote_server_exit`, ensure `_provider_stopped_neovim` is not set so this does not mean “user killed remote server”. Store a specific detached flag to avoid reconnect scheduling.

- [ ] **Step 7: Capture remote PID during launch**

In `_launch_remote_neovim_server()`, set `self._remote_free_port = remote_free_port`. For the first implementation, capture PID with an extra remote command after launch:

```lua
self:run_command(("pgrep -f %s.*--listen.*%s | tail -n 1"):format(vim.fn.shellescape(self:_remote_neovim_binary_path()), remote_free_port), "Finding remote Neovim server PID")
self._remote_server_pid = self.executor:job_stdout()[#self.executor:job_stdout()]
```

If this is too brittle during implementation, wrap the launch command in shell that writes `$!` to a known pidfile under the workspace and read that pidfile. Prefer the pidfile approach if tests can cover the generated command.

- [ ] **Step 8: Run provider spec**

Run:

```sh
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: PASS.

- [ ] **Step 9: Commit detach provider lifecycle**

```sh
git add lua/remote-nvim/providers/provider.lua lua/remote-nvim/providers/ssh/ssh_executor.lua tests/remote-nvim/providers/provider_spec.lua tests/remote-nvim/providers/ssh/ssh_executor_spec.lua
git commit -m "feat: detach ssh remote sessions"
```

## Task 4: Reattach and kill detached commands

**Files:**
- Modify: `lua/remote-nvim/command.lua`
- Modify: `lua/remote-nvim/providers/provider.lua`
- Test: `tests/remote-nvim/command_spec.lua`
- Test: `tests/remote-nvim/providers/provider_spec.lua`

- [ ] **Step 1: Write failing command tests**

In `tests/remote-nvim/command_spec.lua`, add cases:

```lua
it("detaches one running SSH session", function()
  sessions.host1 = make_session({ port = 1234 })
  sessions.host1.detach_neovim = stub()

  command.RemoteDetach({ args = "host1" })

  assert.stub(sessions.host1.detach_neovim).was.called()
end)

it("reattaches a detached session from the registry", function()
  local registry = mock(require("remote-nvim.detached_registry"), true)
  registry.get.returns({ provider = "ssh", host = "host1", status = "detached" })
  remote_nvim.session_provider.get_or_initialize_session = stub().returns({ reattach_neovim = stub() })

  command.RemoteReattach({ args = "host1" })

  assert.stub(remote_nvim.session_provider.get_or_initialize_session).was.called()
end)

it("kills a detached session", function()
  local registry = mock(require("remote-nvim.detached_registry"), true)
  registry.get.returns({ provider = "ssh", host = "host1", status = "detached", remote_pid = "4567" })
  local session = { kill_detached_neovim = stub() }
  remote_nvim.session_provider.get_or_initialize_session = stub().returns(session)

  command.RemoteKillDetached({ args = "host1" })

  assert.stub(session.kill_detached_neovim).was.called()
end)
```

Adapt to the actual test doubles used in the command spec.

- [ ] **Step 2: Run command spec and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/command_spec.lua
```

Expected: FAIL because commands are missing.

- [ ] **Step 3: Implement command functions**

In `lua/remote-nvim/command.lua`, add:

- `M.RemoteDetach(opts)` using active running SSH sessions and picker pattern.
- `M.RemoteReattach(opts)` using detached registry records and `session_provider:get_or_initialize_session`.
- `M.RemoteKillDetached(opts)` using detached registry records and provider kill API.
- Command registrations with host completion:
  - `RemoteDetach` completes running sessions.
  - `RemoteReattach` and `RemoteKillDetached` complete detached registry keys.

- [ ] **Step 4: Write failing provider reattach/kill tests**

In `tests/remote-nvim/providers/provider_spec.lua`, add tests for:

- `reattach_neovim(record)` probes PID and port before forwarding.
- dead PID marks registry stale.
- `kill_detached_neovim(record)` kills PID and removes registry.
- stale record removes registry only.

- [ ] **Step 5: Implement provider reattach/kill**

In `lua/remote-nvim/providers/provider.lua`, add:

```lua
function Provider:_remote_pid_alive(pid)
  self:run_command(("kill -0 %s && echo alive || echo dead"):format(vim.fn.shellescape(tostring(pid))), "Checking detached Neovim process")
  return self.executor:job_stdout()[#self.executor:job_stdout()] == "alive"
end

function Provider:_remote_port_alive(port)
  self:run_command(("(command -v nc >/dev/null && nc -z localhost %s && echo alive) || echo unknown"):format(vim.fn.shellescape(tostring(port))), "Checking detached Neovim port")
  local result = self.executor:job_stdout()[#self.executor:job_stdout()]
  return result == "alive" or result == "unknown"
end

function Provider:reattach_neovim(record)
  if self.provider_type ~= "ssh" then
    vim.notify("Reattach is only supported for SSH sessions", vim.log.levels.WARN)
    return
  end
  if not self:_remote_pid_alive(record.remote_pid) or not self:_remote_port_alive(record.remote_port) then
    self:_detached_registry():mark_stale(self.unique_host_id)
    vim.notify(("Detached session '%s' is stale"):format(self.unique_host_id), vim.log.levels.WARN)
    return
  end

  self._remote_free_port = record.remote_port
  self._remote_server_pid = record.remote_pid
  self._local_free_port = require("remote-nvim.providers.utils").find_free_port()
  self.executor:start_port_forward(self._local_free_port, self._remote_free_port)
  self._remote_server_process_id = self.executor:get_job_id()
  self._detached_state = nil
  self:_launch_local_client()
  self:_detached_registry():upsert(self.unique_host_id, { last_seen_at = os.time(), status = "detached" })
end

function Provider:kill_detached_neovim(record)
  if record.status == "stale" then
    self:_detached_registry():remove(self.unique_host_id)
    return
  end
  self:run_command(("kill %s"):format(vim.fn.shellescape(tostring(record.remote_pid))), "Killing detached Neovim server")
  self:_detached_registry():remove(self.unique_host_id)
end
```

If `Executor:get_job_id()` does not exist, add it to `lua/remote-nvim/providers/executor.lua` with a small test or use the existing `_job_id` carefully through a public method.

- [ ] **Step 6: Run command and provider specs**

Run:

```sh
make test-file FILE=tests/remote-nvim/command_spec.lua
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: PASS.

- [ ] **Step 7: Commit commands**

```sh
git add lua/remote-nvim/command.lua lua/remote-nvim/providers/provider.lua tests/remote-nvim/command_spec.lua tests/remote-nvim/providers/provider_spec.lua
git commit -m "feat: add remote detach commands"
```

## Task 5: Clipboard diagnostics cache in RemoteInfo

**Files:**
- Modify: `lua/remote-nvim/command.lua`
- Modify: `lua/remote-nvim/providers/provider.lua`
- Test: `tests/remote-nvim/command_spec.lua`
- Test: `tests/remote-nvim/providers/provider_spec.lua`

- [ ] **Step 1: Write failing tests**

In `tests/remote-nvim/command_spec.lua`, update the healthy `RemoteClipboardCheck` test to expect:

```lua
sessions.host1.set_clipboard_diagnostics = stub()
assert.stub(sessions.host1.set_clipboard_diagnostics).was.called()
```

In `tests/remote-nvim/providers/provider_spec.lua`, add:

```lua
it("stores clipboard diagnostics for RemoteInfo", function()
  provider:set_clipboard_diagnostics({ clipboard_name = "remote-nvim OSC 52" })
  local entries = provider:_runtime_diagnostics_entries()

  assert.is_true(vim.tbl_contains(vim.tbl_map(function(entry) return entry.value end, entries), "remote-nvim OSC 52"))
end)
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```sh
make test-file FILE=tests/remote-nvim/command_spec.lua
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: FAIL because clipboard diagnostics are not cached yet.

- [ ] **Step 3: Implement clipboard diagnostics caching**

In `lua/remote-nvim/command.lua`, after successful RPC:

```lua
if session.set_clipboard_diagnostics then
  session:set_clipboard_diagnostics(result)
end
```

In `Provider:_runtime_diagnostics_entries()`, format clipboard as:

```lua
local clipboard_summary = "not checked yet"
if self._last_clipboard_diagnostics then
  clipboard_summary = self._last_clipboard_diagnostics.clipboard_name or "checked with warnings"
end
```

- [ ] **Step 4: Run tests and commit**

Run:

```sh
make test-file FILE=tests/remote-nvim/command_spec.lua
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
```

Expected: PASS.

Commit:

```sh
git add lua/remote-nvim/command.lua lua/remote-nvim/providers/provider.lua tests/remote-nvim/command_spec.lua tests/remote-nvim/providers/provider_spec.lua
git commit -m "feat: show clipboard diagnostics in remote info"
```

## Task 6: Documentation

**Files:**
- Modify: `README.md`
- Modify: `doc/remote-nvim.txt`

- [ ] **Step 1: Update README**

Add command table rows for:

```markdown
| `:RemoteDetach` | Detach an active SSH session while leaving the remote Neovim server running. |
| `:RemoteReattach` | Reconnect to a detached SSH session after validating the remote server. |
| `:RemoteKillDetached` | Kill or clear a detached SSH session record. |
```

Add a section after “Automatic reconnect”:

```markdown
### Detached SSH sessions

SSH sessions can be detached explicitly with `:RemoteDetach`. Detach stops the local forwarding job and client, but keeps the remote headless Neovim server running. Use `:RemoteReattach` to validate the saved PID and remote port, recreate the local tunnel, and launch the local client again.

Detached sessions are stored under `stdpath("data")/remote-nvim/detached.json`. If validation fails, the record is marked stale. Use `:RemoteKillDetached` to kill a detached server or clear a stale record.

Detach is SSH-only in this release. Devpod, Docker image, and Docker container sessions report a clear unsupported-provider warning.
```

Update `:RemoteInfo` docs to mention `Runtime diagnostics`.

- [ ] **Step 2: Update help doc**

Mirror the README changes in `doc/remote-nvim.txt` with Vim help formatting.

- [ ] **Step 3: Commit docs**

```sh
git add README.md doc/remote-nvim.txt
git commit -m "docs: document detached ssh sessions"
```

## Task 7: Full verification

**Files:**
- No source edits expected.

- [ ] **Step 1: Run targeted specs**

Run:

```sh
make test-file FILE=tests/remote-nvim/detached_registry_spec.lua
make test-file FILE=tests/remote-nvim/providers/ssh/ssh_executor_spec.lua
make test-file FILE=tests/remote-nvim/providers/provider_spec.lua
make test-file FILE=tests/remote-nvim/command_spec.lua
make test-file FILE=tests/remote-nvim/ui/progressview_spec.lua
```

Expected: all pass.

- [ ] **Step 2: Run full test suite**

Run:

```sh
make test
```

Expected: all pass.

- [ ] **Step 3: Run checks if available**

Run:

```sh
make check
```

Expected: pass if `pre-commit` is installed. If it fails with `pre-commit: No such file or directory`, report that as an environment blocker for this check only.

- [ ] **Step 4: Runtime smoke test**

Perform a local SSH-free smoke for diagnostics and registry behavior where possible:

- Instantiate registry, upsert a fake record, reload registry, verify the record persists.
- Start a local headless Neovim server and remote-ui as in the clipboard verification flow to ensure existing clipboard behavior still emits OSC52.

- [ ] **Step 5: Final status**

Run:

```sh
git status --short --branch
```

Expected: only intended committed changes, plus any pre-existing unrelated user files.
