# Offline mode and install scripts

Offline support in this repo is practical rather than abstract. The plugin has to answer a concrete question: how do we get a working remote Neovim when the remote target cannot reach GitHub?

## Offline cache lookup

`lua/remote-nvim/offline-mode.lua` scans the configured cache directory:

```text
stdpath("cache")/remote-nvim/version_cache
```

It groups files by release version and filters by:

- operating system
- install method (`binary` or `source`)
- checksum presence for binary artifacts

The result is a map of version tags to local release files. This is what the provider uses when offline mode is enabled and `no_github = true`.

## How `_setup_remote()` uses offline mode

When the selected remote Neovim is not already installed and offline mode is enabled:

- if `no_github` is false, the plugin first downloads the requested release locally with `scripts/neovim_download.sh`
- it resolves the expected local release path and optional checksum file
- it uploads those artifacts to the remote binary directory
- it appends `-o` when running the remote install script so the remote side skips network download

This means offline mode is not a second install system. It is an alternate artifact-sourcing path that still feeds into the same remote install script.

## `scripts/neovim_download.sh`

The download script is a local helper. It:

- validates version, download type, and architecture
- builds the GitHub release URL
- reuses an existing artifact when checksum matches
- downloads either a binary release or source archive

The script is intentionally separate from install because the local machine may have network access even when the remote machine does not.

## `scripts/neovim_install.sh`

The install script runs on the remote side and handles three install methods:

- `binary`
- `source`
- `system`

For binary installs:

- on Linux it expects an AppImage, extracts it, and symlinks the embedded `nvim`
- on macOS it expects a tarball and expands it into the version directory

For source installs:

- it expects the source tarball to already exist in the version directory
- it extracts and builds Neovim with `make` or `gmake`

For system installs:

- it checks whether `nvim` already exists on the remote path
- it symlinks that executable into the managed version directory

In all cases the target layout ends up under:

```text
<remote_neovim_home>/nvim-downloads/<version>/bin/nvim
```

## Script sync and checksuming

The provider does not reupload helper scripts blindly on every launch.

- `_get_local_plugin_scripts_checksum()` walks the local `scripts/` tree and hashes file contents.
- `_sync_plugin_scripts()` compares that hash to the remote checksum marker.
- only when the checksum differs does it upload the scripts directory again.

That optimization matters because remote setup is already expensive. Script sync should not add needless transfer overhead on every reconnect.

## The practical debugging model

When install fails, separate the failure into one of these buckets:

- release selection was wrong: likely provider version or install-method choice
- local artifact is missing: likely offline cache or download step
- remote extraction or build failed: likely `neovim_install.sh`
- binaries are missing on the local machine: likely `health.lua` and environment setup

The repo’s install path is broad, but the boundaries are readable once you keep local download, remote install, and provider orchestration separate.
