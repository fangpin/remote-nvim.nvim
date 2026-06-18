# Persistence and detached sessions

Persistent state is intentionally small and split into two files:

- `workspace.json` managed by `ConfigProvider`
- `detached.json` managed by `DetachedRegistry`

## Workspace persistence in `config.lua`

`ConfigProvider` stores records at:

```text
stdpath("data")/remote-nvim/workspace.json
```

Each record is keyed by host id and merged through `update_workspace_config()`. The stored fields can include:

- provider type
- host and connection options
- workspace id
- remote home
- OS and architecture
- selected Neovim version and install method
- config copy preference
- local client auto-start preference
- working directory and working-directory history
- Devpod source metadata

This store is the backbone for `:RemoteStart <host-id>`, command completion, and resuming prior workspace choices.

## Session cache versus persistent config

It helps to keep two layers separate:

- `SessionProvider.sessions` is runtime-only and holds instantiated provider objects.
- `ConfigProvider._config_data` is durable and survives across Neovim restarts.

The command layer routinely uses both. A command may read persisted workspace data to reconstruct provider options, then ask the session cache to reuse or initialize the provider object.

## Detached session persistence

Detached SSH state lives in:

```text
stdpath("data")/remote-nvim/detached.json
```

`DetachedRegistry` is intentionally minimal:

- `get_all()`
- `get(host_id)`
- `upsert(host_id, record)`
- `mark_stale(host_id)`
- `remove(host_id)`

The detached record stored by `Provider:_detached_record()` includes:

- provider
- host
- connection options
- workspace id
- remote Neovim home
- working directory
- remote port
- remote PID
- remote servername
- Neovim version
- creation and last-seen timestamps
- detached status

## How detach and reattach actually work

Detach does not persist a whole session object. It persists enough metadata to rebuild the local side later.

`detach_neovim()`:

- validates that the provider is SSH and detach mode is enabled
- writes a detached record
- marks provider state as detached
- stops the local tunnel job
- clears local port state

`reattach_neovim(record)`:

- validates that the remote PID is still alive with `kill -0`
- validates that the remote port still accepts connections
- finds a new local free port
- recreates the port-forward tunnel
- launches the local client again
- removes the detached record after successful reattach

If the remote PID or port check fails, the record is marked stale instead of silently reused.

## Why stale state exists

The stale status is a pragmatic guard. A detached record can outlive the actual remote process. Rather than pretending the session still exists, the plugin makes that state explicit and routes cleanup through `:RemoteKillDetached`.

That makes detach support safer than a blind "reconnect anything we once started" approach.
