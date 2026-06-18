# What this repo is

`remote-nvim.nvim` is a Lua plugin that starts a headless Neovim process on a remote target and attaches a local Neovim UI to it. The public story is familiar from the README, but the internal structure is worth reading as three layers:

- `lua/remote-nvim/init.lua` owns plugin setup, the default config tree, clipboard bridge preparation for the local client, and the default `client_callback`.
- `lua/remote-nvim/command.lua` exposes the user command surface and translates a command invocation into session lookup, selection, or provider actions.
- `lua/remote-nvim/providers/` owns the real lifecycle: workspace bootstrap, remote install, config upload, port forwarding, reconnect, detach, cleanup, and provider-specific orchestration.

## System map

The control flow is intentionally thin at the top and stateful in the provider layer.

- `setup()` in `init.lua` merges user config into `default_opts`, creates a `SessionProvider`, registers commands, sets up highlight groups, and truncates the plugin log.
- `SessionProvider` in `providers/session_provider.lua` is the in-memory hub. It lazily instantiates provider objects and reuses them by unique host id.
- `ConfigProvider` in `config.lua` is the persistent hub. It stores workspace records in `stdpath("data")/remote-nvim/workspace.json`.
- `Provider` in `providers/provider.lua` is the shared lifecycle implementation. SSH and Devpod reuse it rather than each rebuilding setup logic.

That split matters because most user-facing behavior comes from `Provider`, even when the session was created by an SSH- or Devpod-specific class.

## Ownership boundaries that matter

Use these file boundaries as the mental model for the repo:

- `init.lua`: default configuration and local-entry wiring.
- `command.lua`: user command surface and selection logic.
- `providers/provider.lua`: shared remote lifecycle and runtime state.
- `providers/ssh/ssh_provider.lua`: SSH-specific identity and option normalization.
- `providers/ssh/ssh_executor.lua`: SSH command execution, transfer, prompt handling, port forwarding, detached launch.
- `providers/ssh/ssh_config_parser.lua`: best-effort SSH config parsing with `Include` support.
- `providers/devpod/devpod_provider.lua`: Devpod workspace lifecycle layered on top of SSH transport.
- `config.lua` and `detached_registry.lua`: persistence.
- `ui/progressview.lua`, `ui.lua`, `health.lua`: UI and diagnostics.
- `offline-mode.lua` plus `scripts/*.sh`: offline release lookup and remote install pipeline.

## How to read the implementation docs

The remaining chapters follow the same rule: explain current behavior by code boundary, not by feature marketing.

- Start with the entrypoint chapter if you want to understand what `setup()` really configures.
- Jump to provider lifecycle if your question is "what happens after I choose a host?"
- Read SSH transport if you care about rsync, tar upload, prompt handling, or detached sessions.
- Read the UI and offline chapters when you are debugging progress view output, clipboard behavior, health checks, or install failures.

This site is meant to complement the README and vimdoc, not replace them. The README stays better for installation and usage examples; these docs stay better for control flow and implementation boundaries.
