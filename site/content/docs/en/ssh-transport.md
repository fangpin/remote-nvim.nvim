# SSH transport and config parsing

SSH behavior lives in three main files:

- `providers/ssh/ssh_provider.lua`
- `providers/ssh/ssh_executor.lua`
- `providers/ssh/ssh_config_parser.lua`

## SSHProvider is intentionally small

`SSHProvider` mainly does three things:

- normalizes connection options
- replaces the generic executor with `SSHExecutor`
- derives a unique host id from host and optional `-p` port

The class is deliberately narrow because almost all lifecycle behavior is already shared in `Provider`.

## `SSHExecutor` owns the real transport mechanics

`SSHExecutor` extends the generic executor with SSH-specific concerns:

- building remote commands using the configured SSH binary
- building rsync invocations using the configured rsync binary
- handling interactive SSH prompts
- starting port-forward-only SSH jobs
- launching detached remote commands with a pidfile

That split matters when debugging. If something is wrong with copy, prompt processing, or tunnel creation, the bug usually belongs in `SSHExecutor`, not in `SSHProvider`.

## Upload has two distinct paths

`SSHExecutor:upload()` has a hard branch:

- uncompressed uploads use `rsync`
- compressed uploads build a `tar czf - ... | ssh ... "tar xvzf -"` pipeline

The repository guidance in `AGENTS.md` calls this out for a reason: rsync changes should not silently alter the compressed path, because the compressed path depends on tar streaming instead of rsync semantics.

For uncompressed uploads, the generated command looks conceptually like:

```sh
rsync -r -e 'ssh <opts>' --exclude .git <local> <host>:<remote>
```

For compressed uploads, `SSHExecutor` finds a common local parent, archives the selected paths, and expands them on the remote side before `chown -R $(whoami)`.

## Prompt handling is config-driven

Interactive SSH input is not hard-coded into the executor. `ssh_prompts` from plugin config drives it.

Each prompt entry defines:

- a plain string to match in stdout
- whether the input is secret
- whether the value is static or dynamic
- an optional prefilled value or custom prompt label

`process_stdout()` scans new SSH output and calls `_process_prompt()` whenever a configured match string appears. Static prompt responses can be cached for the current session after a successful job.

## Port forwarding and detached launch

Two transport helpers are central to runtime behavior:

- `start_port_forward(local_port, remote_port)` launches an SSH job with `-N -L ...`
- `run_detached_server_command(command, pidfile)` starts a remote background process via `nohup sh -c ...` and writes its shell PID to a pidfile

Detached launch is only used when `remote.detach.enabled = true` and the provider type is SSH. In that mode, the plugin separates:

- the remote server process, which keeps running remotely
- the local port-forwarding tunnel, which can be stopped and recreated later

That split is what makes `:RemoteDetach` and `:RemoteReattach` possible.

## `ssh_config` parsing is best effort

`ssh_config_parser.lua` is explicit that it is not a full spec-complete SSH parser.

It does enough for the plugin’s needs:

- handles `Host` blocks
- handles `Include`
- tracks global options
- ignores `Match` blocks for normal host inheritance
- performs post-processing so wildcard host entries can contribute defaults to concrete hosts

The parser also resolves relative include paths relative to the parent config file and logs failures when include expansion cannot be resolved.

The practical takeaway is simple: the parser is meant to produce useful host choices and approximate config, not to fully emulate OpenSSH parsing edge cases.
