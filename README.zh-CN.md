# 🚀 Remote Nvim

中文 | [English](README.md)

项目主页：<https://fangpin.github.io/remote-nvim.nvim/>
详细文档：<https://fangpin.github.io/remote-nvim.nvim/docs/>

`remote-nvim.nvim` 为 Neovim 增加类似 VSCode Remote Development 的远程开发体验。它可以在远程 SSH 主机、Devpod 工作区、Docker 镜像或 Docker 容器里启动 Neovim server，并在本地 Neovim 中连接远端 UI。

和直接 `ssh` 到远端再运行 `nvim` 相比，它会帮你自动安装远端 Neovim、隔离远端配置目录、复制本地配置、记录会话并提供清理命令。

## 功能

| 远程模式 | 当前支持 |
| --- | --- |
| SSH 密码登录 | 完全支持 |
| SSH Key 登录 | 完全支持 |
| SSH config | 完全支持 |
| Docker 镜像 | 完全支持 |
| Docker 容器 | 完全支持 |
| Devcontainer | 完全支持 |

已实现能力：

- 自动安装并启动远端 Neovim。
- 不污染远端全局环境，默认写入独立的 `~/.remote-nvim` 目录。
- 可复制和同步本地 Neovim 配置到远端。
- 自动保存历史工作区，便于重新连接。
- 支持离线模式：远端无法访问 GitHub 时，可以先在本地下载 Neovim release 再传到远端。
- 支持替代安装方式：远端没有匹配的 Neovim 二进制时，可以源码构建或使用远端已有的全局 Neovim。
- 提供远端资源清理、日志查看、运行状态诊断、剪贴板诊断、SSH 会话 detach/reattach 等命令。

## 环境要求

### 操作系统

| 支持级别 | 系统 |
| --- | --- |
| 支持 | Linux、macOS、FreeBSD |
| 暂不支持 | Windows、WSL |

### 本地机器

- OpenSSH client。
- Neovim >= 0.9.0，并且命令名为 `nvim`。
- 必要命令：
  - `curl`
  - `rsync`
  - `tar`，仅在使用压缩上传时需要
  - `devpod` >= 0.5.0，仅在使用 devcontainer 相关功能时需要
- 默认需要能访问 GitHub 上的 `neovim/neovim` 仓库。使用本地和远端完全离线模式时可以不访问 GitHub，但需要提前准备 release 文件。

### 远端机器

- 兼容 OpenSSH 的 SSH server。
- 可用的 `bash` shell。
- 必要命令：
  - `bash`
  - `curl` 或 `wget`
  - `rsync`
- 默认需要能访问 GitHub 上的 `neovim/neovim` 仓库。使用离线模式时可以不访问 GitHub。

## 安装

使用 [lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "fangpin/remote-nvim.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = true,
}
```

如果使用其他插件管理器，请确保调用：

```lua
require("remote-nvim").setup()
```

安装后建议运行：

```vim
:checkhealth remote-nvim
```

如果 health check 发现缺少必要命令，部分功能可能无法正常工作。

## 基础使用

### 启动远程会话

```vim
:RemoteStart
```

插件会引导你选择 SSH、Devpod、Docker 镜像或 Docker 容器等连接方式。首次连接时，它会在远端准备 Neovim、配置隔离目录并启动远端 headless server。

### 查看当前会话

```vim
:RemoteInfo
```

该命令会打开进度和诊断窗口，展示当前 Neovim 运行期间创建的远程会话信息。

### 停止会话

```vim
:RemoteStop
```

停止远端 Neovim server 并关闭对应会话。

### 清理远端资源

```vim
:RemoteCleanup
```

可清理单个 workspace 或整个 remote-nvim 远端目录，并同步删除本地保存的工作区记录。

## 常用命令

| 命令 | 说明 |
| --- | --- |
| `:RemoteStart` | 连接远端实例；如果远端 Neovim server 已运行，可选择是否启动本地 client。 |
| `:RemoteStop` | 停止远端 Neovim server 并关闭会话。 |
| `:RemoteInfo` | 查看当前 Neovim 运行期间创建的会话和运行时诊断信息。 |
| `:RemoteCleanup` | 删除远端 workspace 或整个远端 Neovim 目录，并清理对应配置。 |
| `:RemoteConfigDel` | 删除已经失效的远端配置记录；如果仍可连接远端，优先使用 `:RemoteCleanup`。 |
| `:RemoteLog` | 打开插件日志文件，主要用于调试。 |
| `:RemoteClipboardCheck` | 诊断当前远端会话的剪贴板设置，包括 OSC 52、provider 状态和 UI 连接数量。 |
| `:RemoteDetach` | detach 当前 SSH 会话，保留远端 Neovim server 继续运行。 |
| `:RemoteReattach` | 校验并重新连接已 detach 的 SSH 会话。 |
| `:RemoteKillDetached` | 杀掉或清理已 detach 的 SSH 会话记录。 |

## 配置

最简单的配置：

```lua
require("remote-nvim").setup()
```

只需要覆盖你关心的选项。以下是常见配置片段：

```lua
require("remote-nvim").setup({
  ssh_config = {
    ssh_binary = "ssh",
    rsync_binary = "rsync",
    ssh_config_file_paths = { "$HOME/.ssh/config" },
  },
  devpod = {
    binary = "devpod",
    docker_binary = "docker",
    search_style = "current_dir_only",
  },
  progress_view = {
    type = "popup",
  },
  remote = {
    app_name = "nvim",
    reconnect = {
      enabled = false,
      max_attempts = 5,
      backoff_ms = 2000,
    },
  },
})
```

完整默认配置请参考 [英文 README](README.md)，或直接查看 [lua/remote-nvim/init.lua](lua/remote-nvim/init.lua)。

## 自定义本地 client

默认情况下，插件会在本地 Neovim 的浮动 terminal 中启动：

```sh
nvim --server localhost:<port> --remote-ui
```

如果你希望在独立 terminal tab/window 或 GUI client 中打开远端 UI，可以覆盖 `client_callback`：

```lua
require("remote-nvim").setup({
  client_callback = function(port, _)
    require("remote-nvim.ui").float_term(("nvim --server localhost:%s --remote-ui"):format(port), function(exit_code)
      if exit_code ~= 0 then
        vim.notify(("Local client failed with exit code %s"):format(exit_code), vim.log.levels.ERROR)
      end
    end)
  end,
})
```

更多示例可以参考英文 README 链接的配置 recipe。

## SSH 工作目录

创建 SSH workspace 时，插件会询问可选的远端工作目录。填写后，该目录会被保存到 workspace 记录中，并在后续 `:RemoteStart` 时复用。

远端 headless Neovim server 会以该目录作为当前目录启动，这有助于 LSP 等工具发现 `go.mod`、`package.json` 等项目文件。

如果留空，则保留远端 shell 的默认启动目录，通常是 `$HOME`。

## 自动重连

`remote.reconnect` 可以在 SSH job 异常退出时尝试重新拉起当前 workspace，例如临时网络中断后自动恢复。

```lua
require("remote-nvim").setup({
  remote = {
    reconnect = {
      enabled = true,
      max_attempts = 5,
      backoff_ms = 2000,
    },
  },
})
```

这是一种尽力而为的重连机制：插件会重新启动 workspace 和本地 client。显式执行 `:RemoteStop` 时不会触发重连。

## SSH 会话 Detach / Reattach

SSH 会话可以用 `:RemoteDetach` 显式 detach。Detach 会停止本地端口转发和本地 client，但保留远端 headless Neovim server 继续运行。

之后可以用：

```vim
:RemoteReattach
```

插件会校验保存的 PID 和远端端口，重新创建本地 tunnel，并启动本地 client。

Detach 记录保存在：

```text
stdpath("data")/remote-nvim/detached.json
```

如果校验失败，记录会被标记为 stale。可以用 `:RemoteKillDetached` 杀掉已 detach 的 server，或清理 stale 记录。

当前版本中 detach 仅支持 SSH。Devpod、Docker 镜像和 Docker 容器会返回明确的暂不支持提示。

## 本地剪贴板

默认本地 client 是 `nvim --remote-ui`，即使你从 Neovide 中执行 `:RemoteStart` 也是如此。这样可以保留 terminal UI 的滚动、字体和渲染行为，同时让远端 yank 写入本地剪贴板。

实现方式：

- 远端 server 启动时会安装一个 copy-only 的 OSC 52 clipboard provider。
- 在远端 UI 中使用 `yy`、visual mode `y` 或任何写入 `+` register 的操作，都可以尝试更新本地系统剪贴板。
- Paste 不直接查询 terminal 剪贴板，而是回退到最近一次缓存的 yank，因为许多 terminal 不支持 OSC 52 读取。
- 当默认 client 从 Neovide 启动时，插件会先恢复本地 Neovide clipboard provider，让远端 OSC 52 写入可以通过本地 terminal buffer 流入 Neovide 的系统剪贴板桥接。
- 对没有本地 clipboard provider 的 terminal client，插件会在打开嵌套 terminal UI 前安装本地 OSC 52 fallback，让 Warp 等支持 OSC 52 的 terminal 能收到剪贴板写入。

连接远端后可运行：

```vim
:RemoteClipboardCheck
```

健康状态通常应满足：

- `clipboard option` 包含 `unnamedplus`。
- `clipboard provider` 是 `remote-nvim OSC 52` 或保留的 Neovide provider。
- `osc52 available` 为 `true`。
- `copy +/*` 显示 `function/function`。
- `attached UIs` 至少为 `1`。

如果诊断正常但剪贴板仍不更新，请确认 terminal 或 terminal multiplexer 允许 OSC 52 写入。tmux 中可配置：

```tmux
set -g set-clipboard on
```

## 离线模式

插件默认会访问 GitHub 两次：

1. 本地查询可安装的 Neovim release。
2. 远端下载对应 Neovim release。

如果远端不能访问 GitHub，可以启用远端离线模式：本地下载 release 后上传到远端。

```lua
require("remote-nvim").setup({
  offline_mode = {
    enabled = true,
    no_github = false,
  },
})
```

如果本地和远端都不能访问 GitHub，可以启用完全离线模式：

```lua
require("remote-nvim").setup({
  offline_mode = {
    enabled = true,
    no_github = true,
  },
})
```

完全离线模式要求你提前准备 Neovim release 和 checksum 文件。可以在插件仓库根目录运行：

```bash
./scripts/neovim_download.sh -v <version> -d <cache-dir> -o <os-type> -a <arch-type> -t <release-type>
```

参数说明：

- `<version>`：`stable`、`nightly` 或具体版本，例如 `v0.9.4`。
- `<cache-dir>`：release 和 checksum 下载目录，需要和配置中的 `offline_mode.cache_dir` 一致。
- `<os-type>`：`Linux` 或 `macOS`。
- `<arch-type>`：`x86_64` 或 `arm64`。
- `<release-type>`：`binary` 或 `source`。

## 复制额外 Neovim 目录到远端

离线模式只阻止 `remote-nvim.nvim` 自己访问 GitHub，不会阻止你的插件管理器或其他插件联网。如果希望减少远端联网，可以把本地 Neovim 的 `data`、`state`、`cache` 或 `config` 子目录复制到远端。

例如复制 lazy.nvim 插件目录：

```lua
require("remote-nvim").setup({
  remote = {
    copy_dirs = {
      data = {
        base = vim.fn.stdpath("data"),
        dirs = { "lazy" },
        compression = {
          enabled = true,
          additional_opts = { "--exclude-vcs" },
        },
      },
    },
  },
})
```

如果目录较大，建议开启 `compression.enabled = true`。

## 状态栏集成

插件会在远端 Neovim 实例中设置：

```lua
vim.g.remote_neovim_host = true
```

可以用它在状态栏中显示远端环境信息。例如 lualine：

```lua
lualine_b = {
  {
    function()
      return vim.g.remote_neovim_host and ("Remote: %s"):format(vim.uv.os_gethostname()) or ""
    end,
  },
}
```

## 注意事项

- 远端 Neovim server 默认绑定到启动它的本地 Neovim 实例。如果关闭该本地实例，远端 server 也会被关闭，以避免遗留孤儿进程。
- 当前实现是在远端启动 headless server，然后用本地 TUI 连接。如果你用常规方式退出 TUI，server 也会被关闭。仅关闭 TUI 而保留 server 的能力目前通过 SSH detach 提供。
- Neovim `< v0.9.2` 与 `>= v0.9.2` 之间存在 UI 破坏性变更，版本混用可能不兼容。

## FAQ

### 为什么远端 shell 里配置过的工具在 remote-nvim 中找不到？

`remote-nvim` 通过 SSH 在远端执行命令，并从该命令环境启动 headless Neovim server。这个环境通常是非交互、非 login shell，因此 `~/.zshrc` 等交互式启动文件不一定会被加载。

把远端 Neovim 需要的 `PATH` 配置放到非交互 shell 也会加载的文件中。例如远端 login shell 是 zsh，`fzf` 安装在 `~/.fzf/bin`，可以在 `~/.zshenv` 中放：

```sh
export PATH="$HOME/.fzf/bin:$PATH"
```

而 fzf 的 key binding、completion 等交互式配置仍应放在 `~/.zshrc`。

### 为什么不用普通 ssh + nvim？

`remote-nvim.nvim` 在普通 SSH 体验之上提供了这些便利：

- 自动安装远端 Neovim。
- 不修改远端全局配置，统一写入独立目录。
- 可复制本地 Neovim 配置到远端。
- 保存历史会话，方便重连。
- 提供远端资源清理能力。
- 在远端启动 Neovim server，本地只连接 UI。

## 致谢

感谢 Neovim 社区以及相关插件作者。

## 脚注

- Docker、Devcontainer 和 Devpod 相关功能需要安装 `devpod` >= 0.5.0。
- FreeBSD 支持源码构建或使用远端已有的 Neovim。
