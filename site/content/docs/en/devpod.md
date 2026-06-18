# Devpod and container workflows

The repo presents Docker image, Docker container, and devcontainer support as first-class features, but the implementation route is narrower than that marketing surface suggests.

## Why Devpod matters

`lua/remote-nvim/providers/devpod/devpod_provider.lua` subclasses `SSHProvider`, not the other way around. That tells you the model:

- Devpod handles workspace creation and SSH config generation.
- Once the workspace exists, remote-nvim mostly treats it like an SSH target.

So Devpod is not a parallel transport stack. It is a workspace-orchestration layer that eventually feeds an SSH-style runtime.

## What DevpodProvider adds

On top of the shared provider lifecycle, `DevpodProvider` adds:

- validation that the configured `devpod` binary exists
- workspace source metadata such as repo, image, container, or existing workspace id
- generated SSH config usage through `-F <ssh_config_path>`
- local `devpod up`, `stop`, `delete`, and provider-management commands

The constructor prepares `_up_default_opts` like `--open-ide=false`, `--configure-ssh=true`, and `--ide=none`. For non-existing sources it also writes the generated SSH config path into launch arguments.

## Workspace bring-up path

The key Devpod-specific method is `_launch_devpod_workspace()`.

It:

- ensures provider setup has happened
- assembles `devpod up` arguments from the chosen source and source id
- strips raw SSH config flags back out of the Devpod command line when they only belong to the downstream SSH layer
- runs `devpod up` locally before calling the shared `_launch_neovim(false)` path

After that, the shared provider launch logic takes over using the generated SSH connectivity.

## Provider setup and cleanup

DevpodProvider also owns provider-level side effects that SSHProvider does not have:

- `_handle_provider_setup()` can call `devpod provider list --output json` and `devpod provider add`
- `stop_neovim()` can stop the backing Devpod workspace
- `clean_up_remote_host()` can optionally delete the Devpod workspace after remote cleanup

These methods make Devpod sessions broader than plain SSH sessions. Stopping the remote Neovim process may not be the whole lifecycle; the workspace itself can be created, stopped, or deleted locally as part of session management.

## Why this layering is useful

This architecture keeps transport reuse high:

- the SSH executor still handles upload, command execution, and tunnels
- the shared provider still handles install, config copy, progress view, diagnostics, and local attach
- Devpod-specific logic stays focused on workspace provisioning and lifecycle

If you need to understand why a devcontainer flow fails, first ask whether the failure is:

- before workspace creation: likely DevpodProvider or local Devpod CLI state
- after workspace creation and before attach: likely shared provider setup
- during copy or tunnel creation: likely SSH executor behavior
