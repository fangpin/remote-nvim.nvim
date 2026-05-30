# Detach/Reattach and Runtime Diagnostics Design

## Context

`remote-nvim.nvim` currently treats the remote Neovim server and the local SSH tunnel/client as one lifecycle. If the local tunnel exits, the session is effectively gone and reconnect is best-effort. Users also need better runtime visibility in `:RemoteInfo`, especially after adding clipboard diagnostics. This design adds SSH-first detached session management and upgrades session diagnostics without changing the default `:RemoteStop` behavior.

## Goals

- Add explicit SSH detach/reattach lifecycle commands.
- Keep detached remote Neovim servers discoverable across host Neovim restarts.
- Provide a safe way to kill or clear detached sessions.
- Upgrade `:RemoteInfo` with runtime diagnostics, including detached state and clipboard check results.
- Keep non-SSH providers out of scope for the first implementation, with clear unsupported messages.

## Non-goals

- Do not add a remote supervisor daemon.
- Do not change existing `:RemoteStop` semantics.
- Do not implement detach support for Devpod, Docker images, or Docker containers in this phase.
- Do not automatically kill remote processes unless the user explicitly runs the detached kill command.

## User-facing Commands

### `:RemoteDetach [host]`

Detaches an active SSH session by stopping the local forwarding job/client while keeping the remote headless Neovim server alive. Before detaching, the provider records a detached session entry with enough metadata to reattach later.

If the provider is not SSH, the command reports that detach is not supported for that provider. If no host is supplied and multiple active SSH sessions exist, the command uses the existing picker pattern.

### `:RemoteReattach [host]`

Reattaches to a detached SSH session. The command reads the detached session registry, probes the remote PID and port, creates a fresh local port forward, and launches the local client.

If the record is stale, it marks the record as stale and tells the user to either `:RemoteStart` or clear/kill the detached record. If an active session already exists for the host, it reports that the session is already active instead of creating a duplicate.

### `:RemoteKillDetached [host]`

Kills the remote Neovim process for a detached SSH session and removes the registry entry. For stale entries, it only clears the registry entry. This command is explicit because it can terminate a remote process.

## Detached Session Registry

Add a new registry stored at:

```text
stdpath("data")/remote-nvim/detached.json
```

Do not mix detached runtime state into the existing workspace config file. The detached registry is runtime state; workspace config remains user configuration.

Each record is keyed by `host_id` and stores:

- `provider = "ssh"`
- `host`
- `connection_options`
- `workspace_id`
- `remote_neovim_home`
- `working_dir`
- `remote_port`
- `remote_pid`
- `remote_servername` or listen address
- `neovim_version`
- `created_at`
- `last_seen_at`
- `status = "detached" | "stale"`

## Provider Lifecycle

### Launch

When launching an SSH remote server, capture the remote listen port and remote PID. The current code already finds the remote free port before launch; promote that value into provider state so detach can persist it. The launch command should also expose the remote PID in a reliable way, such as wrapping the remote Neovim launch with shell logic that records `$!` when running the server as a background process for detached-capable sessions.

### Detach

Detaching should:

1. Verify the provider is SSH.
2. Verify the remote server is running.
3. Persist the detached record.
4. Stop only the local forwarding job/client path.
5. Preserve the remote Neovim process.
6. Mark the in-memory provider state as detached.

Do not use `:RemoteStop` internally if it kills the remote process or marks the session as intentionally stopped in a way that triggers cleanup semantics.

### Reattach

Reattaching should:

1. Load the detached record.
2. If an active session for the host already exists, report that no reattach is needed.
3. Probe the remote PID.
4. Probe the remote port.
5. If both are alive, allocate a new local free port and start a forward-only SSH job.
6. Update provider state with the local port, remote port, remote PID, and running job ID.
7. Launch the local client.
8. Update `last_seen_at`.

If PID or port checks fail, mark the record stale and do not create a tunnel.

### Kill detached

Killing should:

1. Load the detached record.
2. If status is stale, remove the record only.
3. If status is detached, run a remote kill command against the stored PID.
4. Remove the registry entry after the kill command succeeds or if the remote process is already gone.

## Runtime Diagnostics in `:RemoteInfo`

Upgrade the session info panel with a `Runtime diagnostics` section. This section should be refreshed rather than appended repeatedly.

Include:

- provider type
- active / detached / stale state
- local SSH/job id
- local forwarded port
- remote listen port
- remote PID
- reconnect enabled
- reconnect attempt and max attempts
- last exit code or last reconnect reason when known
- last clipboard diagnostics summary or `not checked yet`

If there is no active session but a detached record exists, `:RemoteInfo` should indicate that the session can be restored with `:RemoteReattach <host>`.

`RemoteClipboardCheck` should keep its current notify behavior and also cache the most recent result on the provider/session diagnostics state so `:RemoteInfo` can show it.

## Error Handling

- Non-SSH provider detach or reattach: warn that detach is unsupported for that provider.
- Missing detached record: warn that there is no detached session for the host.
- Active session exists during reattach: report already active.
- PID missing or dead: mark stale and warn.
- Remote port unavailable: mark stale and warn.
- SSH command failure: report the stderr/output and leave the record unchanged unless liveness checks prove stale.
- Stale records are not auto-deleted. Users can clear them with `:RemoteKillDetached`.

## Testing Strategy

Use unit-style tests with stubs; do not require real SSH.

- Detached registry tests:
  - read/write empty registry
  - add/update/remove record
  - mark stale
  - tolerate missing/corrupt file with safe fallback and warning
- Provider tests:
  - SSH detach persists metadata and stops only local forwarding state
  - non-SSH detach reports unsupported
  - reattach probes PID/port before starting tunnel
  - stale detection updates registry
  - kill detached removes registry and sends remote kill command
- Command tests:
  - command argument validation and completion
  - no sessions / no detached records
  - multiple-host picker behavior
  - unsupported provider messages
- Progress view tests:
  - runtime diagnostics section renders
  - refresh replaces previous diagnostics instead of appending duplicates
- Existing tests:
  - `make test-file FILE=tests/remote-nvim/providers/provider_spec.lua`
  - `make test-file FILE=tests/remote-nvim/command_spec.lua`
  - full `make test`

## Documentation

Update both `README.md` and `doc/remote-nvim.txt`:

- Add `:RemoteDetach`, `:RemoteReattach`, and `:RemoteKillDetached` to command lists.
- Document that detach is SSH-only in the first implementation.
- Explain detached record behavior and stale handling.
- Update `:RemoteInfo` docs to mention runtime diagnostics.
