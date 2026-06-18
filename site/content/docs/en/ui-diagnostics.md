# UI and diagnostics

The repo’s UI is compact but fairly intentional. It is not just a progress log; it is the main runtime inspection surface for active sessions.

## `ui/progressview.lua`

The progress viewer is built with NUI primitives:

- `Popup` or `Split` as the outer container
- `NuiTree` for progress nodes and session-info nodes
- `NuiLine` for the header bar

The layout is configured from `remote_nvim.config.progress_view`.

- `type = "split"` uses a side split with size and position controls
- `type = "popup"` uses a popup with border, anchor, and resize handling

This means UI customization is shallow but real. The plugin does not rebuild its own layout engine; it delegates most window behavior to NUI.

## Three panes, one window

The progress viewer window can swap between:

- the progress pane
- the session-info pane
- the help pane

`switch_to_pane()` just rebinds the window buffer and optionally collapses tree nodes. The model is lightweight, which helps keep the UI code focused on data organization rather than window orchestration.

## Progress output shaping

The viewer distinguishes node kinds such as:

- run nodes
- section nodes
- command nodes
- stdout nodes

For long command output, it uses `section_deque_map` and `max_output_lines = 30` to cap how much stdout remains visible per section. That keeps the pane useful during install and copy operations instead of letting one long command dominate the tree.

## Session info refresh

`set_session_section(title, holds, entries)` is the critical API for the session pane.

The provider uses it to refresh sections rather than continuously appending duplicate rows. That makes the session pane a current-state view, not just a historical log.

The provider pushes values such as:

- local OS and Neovim version
- log path and plugin version
- host id and remote paths
- current working directory
- runtime diagnostics like local port, remote PID, and reconnect state

## Clipboard diagnostics

`command.lua` implements `:RemoteClipboardCheck` by opening an RPC connection to the remote Neovim server and executing a Lua probe.

The probe checks:

- `vim.o.clipboard`
- `vim.g.clipboard`
- copy and paste function presence
- whether OSC52 is available
- `vim.g.remote_nvim_clipboard`
- current UI count

The command then reports the result locally and, when supported, stores the result back into provider diagnostics state.

This is useful because clipboard failures in remote workflows often come from mismatches between local bridge setup and remote bridge setup, not from a single missing option.

## Health checks

`health.lua` is narrower. It verifies local binary availability and prints versions when found.

The checks cover:

- `curl`
- `tar`
- configured SSH binary
- configured rsync binary
- configured Devpod binary
- configured Docker binary

The plugin treats some of these as optional and some as hard failures. That mirrors the product surface: plain SSH should still work without Devpod, but copy or install behavior degrades fast when `curl`, `ssh`, or `rsync` are missing.

## Floating local terminal UI

`ui.lua` exports `float_term()`, which the default `client_callback` uses. It creates a full-screen floating terminal, runs the local attach command with `termopen()`, and unmounts the popup automatically on clean exit.

That is why the default local attach feels like a temporary focused surface rather than a permanent split.
