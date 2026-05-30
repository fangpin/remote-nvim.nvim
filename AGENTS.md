# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

`remote-nvim.nvim` is a Neovim plugin written in Lua. It supports launching and managing remote Neovim sessions over SSH, Devpod, Docker images, and Docker containers.

Primary code areas:

- `lua/remote-nvim/`: plugin runtime code.
- `lua/remote-nvim/providers/`: provider and executor implementations.
- `lua/remote-nvim/providers/ssh/`: SSH provider, config parsing, and transfer logic.
- `tests/`: Plenary/Busted test suite.
- `scripts/`: shell scripts copied to or executed for remote setup.
- `doc/remote-nvim.txt`: generated-style help documentation that should stay aligned with `README.md`.

## Development Workflow

- Keep changes scoped to the requested behavior.
- Follow the existing Lua style and class patterns.
- Prefer updating tests next to the changed behavior.
- Do not rewrite generated-looking documentation broadly; make targeted edits.
- After every code change, especially functional changes, re-review `README.md` and `AGENTS.md` to decide whether they need updates.
- If user-facing configuration or requirements change, update both `README.md` and `doc/remote-nvim.txt`.
- Historical release entries in `CHANGELOG.md` should generally not be edited.

## Commands

Run all tests:

```sh
make test
```

Run one test file:

```sh
make test-file FILE=tests/remote-nvim/providers/ssh/ssh_executor_spec.lua
```

Run pre-commit checks:

```sh
make check
```

Install pre-commit hooks:

```sh
make install-hooks
```

## Dependencies And Transfer Notes

SSH transfers use `rsync` via `ssh_config.rsync_binary`, defaulting to `rsync`. Keep local and remote dependency documentation aligned when transfer behavior changes.

Compressed upload paths still use `tar` and SSH command streaming, so changes to uncompressed rsync transfers should not accidentally alter the compression path unless explicitly requested.

## Documentation Notes

`CONTRIBUTING.md` says the help file is generated from the README. In practice, when editing docs manually, update matching sections in both:

- `README.md`
- `doc/remote-nvim.txt`

For configuration examples, prefer documenting default values from `lua/remote-nvim/init.lua`.
