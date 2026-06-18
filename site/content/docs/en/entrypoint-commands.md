# Entrypoint and commands

The entrypoint layer is mostly `lua/remote-nvim/init.lua` and `lua/remote-nvim/command.lua`. It is thin on purpose: it collects user intent, normalizes config, and hands the heavy work to provider sessions.

## `setup()` in `init.lua`

`setup()` does four concrete things:

- checks the minimum Neovim version against `remote-nvim.constants.MIN_NEOVIM_VERSION`
- deep-merges user config into `M.default_opts`
- creates `M.session_provider = require("remote-nvim.providers.session_provider")()`
- loads command registration and highlight setup

This means the plugin has a single shared `session_provider` for the entire local Neovim process. Commands do not construct a fresh world on each invocation; they route into that shared provider registry.

## What `default_opts` really defines

The default config tree in `init.lua` is the best schema reference because it covers more than the README summary.

- `devpod`: binary names, SSH config path, search strategy, dotfiles, GPG forwarding, container listing mode
- `ssh_config`: SSH binary, rsync binary, config file list, and prompt patterns used to detect interactive SSH input
- `remote`: `app_name`, reconnect policy, detach toggle, and copy rules for `config`, `data`, `state`, and `cache`
- `progress_view`: whether the progress UI is a popup or split
- `offline_mode`: offline cache behavior
- `log`: log file path, level, and truncation threshold
- `client_callback`: how the local UI gets attached

The default `client_callback` calls `launch_terminal_client()`, which opens a floating terminal and runs:

```sh
nvim --server localhost:<port> --remote-ui
```

If you override `client_callback`, you are not replacing remote setup. You are only replacing the local attach step after the remote server and local tunnel are already ready.

## Local clipboard bridge

`init.lua` does more than config merging. Before the default local client launches, it calls `prepare_local_clipboard_bridge()`.

- In Neovide, it prefers a custom clipboard adapter built around `neovide.set_clipboard` and `neovide.get_clipboard`.
- Otherwise it tries to keep a local clipboard provider. If none exists, it falls back to an OSC52-backed provider.

That local bridge is the counterpart to the remote clipboard setup injected later by `Provider:_get_clipboard_setup_cmd()`. The repo treats remote clipboard support as a two-sided contract, not just a remote-only toggle.

## Command registration in `command.lua`

`command.lua` exposes the public command surface:

- `:RemoteStart`
- `:RemoteStop`
- `:RemoteInfo`
- `:RemoteCleanup`
- `:RemoteConfigDel`
- `:RemoteLog`
- `:RemoteClipboardCheck`
- `:RemoteDetach`
- `:RemoteReattach`
- `:RemoteKillDetached`

Each command stays narrow:

- It resolves the host id or prompts the user with `vim.ui.select` or Telescope.
- It validates current session state.
- It asks `session_provider` for a session or looks up a saved workspace record.
- It delegates to a method on the provider instance.

## `:RemoteStart` is mostly a router

`RemoteStart` behaves in two modes.

- With no argument, it opens the Telescope extension and lets the user choose a remote path.
- With a host identifier, it loads the saved workspace config from `ConfigProvider`, reconstructs provider options, and then calls `launch_neovim()` on the resolved session.

This is important for reconnect behavior. The command layer does not replay setup from scratch by itself. It reconstructs enough provider identity for `SessionProvider` to either reuse an existing session object or initialize the right provider class.

## Command completion uses persisted state

Several commands complete against persisted or active state:

- `RemoteStart` and `RemoteCleanup` complete from saved workspace ids.
- `RemoteInfo`, `RemoteStop`, and clipboard checks complete from currently active sessions.
- detach-related commands complete from the detached registry.

That design keeps the command layer simple, but it also means the quality of command UX depends on `workspace.json`, active session state, and `detached.json` remaining coherent.
