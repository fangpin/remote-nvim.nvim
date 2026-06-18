# Provider lifecycle

The real engine of the plugin lives in `lua/remote-nvim/providers/provider.lua`. SSH and Devpod are thin wrappers around this shared lifecycle.

## Session objects and reuse

`SessionProvider:get_or_initialize_session()` creates a provider object only once per unique host id, then reuses it from `self.sessions`.

- SSH sessions usually key by host, or by `host:port` if `-p` was part of the SSH options.
- Devpod sessions key by the Devpod workspace id passed into the provider options.

The result is that a provider object accumulates runtime state over the life of the local Neovim process: current ports, progress viewer instance, remote PID, reconnect counters, and cached workspace configuration.

## Workspace bootstrap

The common bootstrap entrypoint is `_setup_workspace_variables()`.

It is responsible for:

- creating an initial workspace record when none exists
- reading or migrating saved `working_dir` and `working_dirs`
- probing remote OS and architecture with `uname -s -m`
- selecting or reusing the remote Neovim version and install method
- discovering the remote base home, usually `$HOME/.remote-nvim`
- deriving workspace-specific XDG paths under the remote workspace id
- caching local copy paths for `config`, `data`, `state`, and `cache`
- refreshing session info in the progress view

This is why provider state feels rich: by the time launch happens, the provider has already assembled a normalized remote model and a persistent workspace record.

## Working directory handling

`_setup_remote_working_dir()` is SSH-specific and intentionally stateful.

- If the provider type is SSH and no working directory is set yet, it offers previously used working directories.
- The selected directory becomes both the current `working_dir` and part of the `working_dirs` history list.
- The values are written back into `workspace.json`.

That history is not cosmetic. On later runs, the provider can offer prior working directories instead of forcing free-form input every time.

## Shared launch pipeline

Once `launch_neovim()` reaches `Provider:_launch_neovim()`, the common pipeline is:

1. reset provider-stopped state and reconnect counter when this is a fresh run
2. create a new progress-view run if needed
3. call `_setup_workspace_variables()`
4. call `_setup_remote_working_dir()`
5. call `_setup_remote()`
6. call `_launch_remote_neovim_server()`
7. call `_launch_local_neovim_client()`

The provider is therefore responsible for both remote bootstrap and the final local attach.

## `_setup_remote()` is the heavy-lift step

`_setup_remote()` creates remote directories, syncs helper scripts, decides whether remote Neovim is already installed, installs it if needed, and uploads selected local directories.

Important details:

- It writes each workspace into isolated XDG trees under the remote workspace path.
- It computes a checksum across helper scripts and only reuploads them when contents change.
- It supports three install methods: `binary`, `source`, and `system`.
- It optionally downloads releases locally first when offline mode is enabled.
- It asks whether local config should be copied, then separately handles additional `data`, `state`, and `cache` copy rules.

This is the chapter where most operational cost lives. Command dispatch is cheap; `_setup_remote()` is not.

## Reconnect behavior

Unexpected remote exits funnel through `_handle_remote_server_exit()`.

- If the session was intentionally detached, the exit is treated as success.
- Otherwise `_schedule_reconnect()` can retry when `remote.reconnect.enabled` is true and the attempt budget is not exhausted.
- Reconnect delay is linear based on `backoff_ms * attempt_number`.
- If reconnect is not scheduled, the provider refreshes diagnostics, may show the progress view, stops the session, and resets most runtime state.

Because reconnect is implemented in the provider object, it can reuse existing workspace metadata and relaunch through the same `_launch_neovim(false)` path.
