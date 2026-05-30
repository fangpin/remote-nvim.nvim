# 把 VS Code Remote 的体验带到 Neovim：remote-nvim.nvim 项目介绍

如果你长期使用 Neovim，又经常需要在远端机器、容器或 devcontainer 里开发，应该很熟悉这种割裂感：

本地 Neovim 顺手、配置完整、插件熟悉；但真正的代码、依赖、构建环境、测试数据却在远端。直接 SSH 上去跑 `nvim` 可以解决一部分问题，但远端配置很快会失控，插件和工具链也要重复安装。久而久之，每台机器都有一份“不知道从哪里来的 Neovim 环境”。

`remote-nvim.nvim` 想解决的就是这个问题：让你继续使用 Neovim，同时获得接近 VS Code Remote 的远程开发体验。

一句话概括：

> `remote-nvim.nvim` 会在远端准备并启动一个隔离的 headless Neovim server，本地 Neovim UI 通过 SSH 端口转发连过去。你看到的是本地熟悉的 Neovim 界面，实际编辑、LSP、插件和命令都运行在远端项目环境里。

## 为什么你可能需要它

很多团队的开发环境已经不再是单纯的本地目录：

- 代码在远端大机器上，依赖本地装不动。
- 编译、测试、数据访问只能在内网或跳板机上完成。
- 项目运行在 Docker / devcontainer 中，本地只是入口。
- 远端机器经常更换，不想每台都重新配置 Neovim。
- 希望本地 UI 保持顺手，但让 LSP、构建、文件搜索都贴近真实运行环境。

传统做法通常有三种：

1. 直接 `ssh remote && nvim`。
2. 在本地挂载远端文件系统。
3. 改用 VS Code Remote。

这些方式都有各自的问题。直接 SSH 上去，需要在远端维护完整 Neovim 配置；挂载远端文件系统，LSP 和文件监听常常不够稳定；改用 VS Code，则意味着放弃自己长期打磨的 Neovim 工作流。

`remote-nvim.nvim` 的定位就是给 Neovim 用户一个更自然的选择：编辑体验留在 Neovim，运行环境放在远端。

## 它能带来什么好处

### 1. 远端自动准备 Neovim

远端不需要你手动维护一套全局 Neovim 配置。插件可以检查远端系统和架构，安装或选择合适的 Neovim 版本，并把相关文件放到自己的 workspace 目录下。

这意味着你可以少关心“这台机器有没有 nvim”“版本是不是太旧”“配置会不会污染别人的账号”。

### 2. 本地配置可以复制到远端

你可以选择把本地 Neovim 配置同步到远端 workspace。远端运行的是你的 Neovim 配置，但文件、LSP、构建工具都在远端环境中执行。

对习惯 LazyVim、Telescope、fzf-lua、nvim-lspconfig 等插件的用户来说，这个体验很接近“把本地 Neovim 搬到了远端”。

### 3. 每个 workspace 相互隔离

插件不会默认写远端用户的全局 `~/.config/nvim`。它会为每个 workspace 准备独立的 XDG 目录：

```text
~/.remote-nvim/workspaces/<workspace-id>/.config
~/.remote-nvim/workspaces/<workspace-id>/.local/share
~/.remote-nvim/workspaces/<workspace-id>/.local/state
~/.remote-nvim/workspaces/<workspace-id>/.cache
```

这样你可以放心在共享远端账号、临时机器或容器里使用，不容易把环境搞乱。

### 4. 支持 SSH、Docker、Devpod 等入口

`remote-nvim.nvim` 不只是 SSH 工具。它支持：

- SSH 主机
- SSH config 里的 host
- Docker image
- Docker container
- Devpod / devcontainer

也就是说，它试图把常见远程开发入口收敛到一个 Neovim 插件里。

### 5. 可以记住 workspace 设置

连接过的 workspace 会保存下来。后续你可以直接选择历史 workspace 重新连接，而不是每次重新输入 host、端口、Neovim 版本、是否复制配置等选项。

最近的 SSH workspace working directory 支持也会保存远端项目目录。首次输入项目根目录后，后续远端 Neovim 会直接从这个目录启动。

如果网络短暂抖动，也可以打开基础版自动重连。插件会在 SSH job 异常退出后按配置重新拉起当前 workspace，避免每次手动从头连接。

## 快速使用方式

安装插件后，通常通过 Telescope 入口启动：

```vim
:Telescope remote-nvim
```

你可以选择：

- 从 SSH config 里选择一个远端 host。
- 手动输入 SSH connection string。
- 连接已有 workspace。
- 创建 Docker / Devpod / devcontainer workspace。

对于 SSH 场景，第一次连接时插件会完成这些事情：

1. 测试 SSH 连接。
2. 判断远端系统和架构。
3. 选择或安装远端 Neovim。
4. 询问是否复制本地 Neovim 配置。
5. 询问远端工作目录，也就是项目根目录。
6. 启动远端 headless Neovim。
7. 在本地启动 Neovim UI 连接过去。

如果你连接的是一个 Go 项目，推荐在工作目录提示时填写项目根目录，例如：

```text
/data00/home/user/go_repos/src/example.com/team/project
```

这样远端 Neovim 启动时会自动进入项目根目录，`gopls` 也更容易正确发现 `go.mod`。

## 一个典型工作流

假设你有一台远端开发机 `devbox`，项目在：

```text
/data00/home/user/work/my-service
```

你的使用流程可以是：

1. 在本地 Neovim 中运行 `:Telescope remote-nvim`。
2. 选择 SSH config 中的 `devbox`。
3. 首次连接时填写远端 working directory：`/data00/home/user/work/my-service`。
4. 选择是否复制本地 Neovim 配置。
5. 插件启动远端 Neovim server，并打开本地 UI。
6. 之后每次通过 saved workspace 直接重连。

从使用者视角看，你仍然是在 Neovim 里工作；但所有跟项目强相关的东西，比如 LSP、文件搜索、终端命令、构建工具，都已经在远端执行。

## 相比直接 SSH + nvim，有什么不同

直接 SSH 上去运行 `nvim` 当然也能用，但 `remote-nvim.nvim` 更像是一套 workspace 管理器：

- 它能自动准备远端 Neovim。
- 它能隔离配置和插件数据。
- 它能复制本地配置。
- 它能保存历史 workspace。
- 它能在连接意外断开时尝试自动重连。
- 它能通过本地 UI 连接远端 server。
- 它能统一 SSH、Docker、Devpod 等入口。

更重要的是，它减少了远端环境的长期维护成本。你不需要把每台机器都配置成完整开发环境，只需要让插件能通过 SSH 连接，并具备基础依赖。

## 它适合谁

这个插件尤其适合这些用户：

- 你主要使用 Neovim，而不是 VS Code。
- 你经常在远端 Linux 机器上开发。
- 你的项目依赖远端内网、数据、编译链或大机器资源。
- 你希望远端 Neovim 配置隔离、可清理、可复用。
- 你需要在 SSH、Docker、devcontainer 之间切换。
- 你希望 LSP 和工具链运行在真实项目环境中。

如果你只是偶尔 SSH 上去改一个配置文件，直接 `ssh && vim` 就够了。但如果远程开发是你的日常工作流，`remote-nvim.nvim` 会更值得尝试。

## 原理简述

理解这个插件的核心，只需要抓住一句话：

> 本地负责发起连接和显示 UI，远端负责运行真正的 Neovim server。

一次 SSH 会话大致是这样启动的。

### 1. 本地创建 workspace

插件为每个远端记录 workspace 配置，包括 host、connection options、workspace ID、远端 Neovim 目录、是否复制配置、是否自动启动 client、远端工作目录等。

这些配置会持久化，方便下次连接复用。

### 2. 远端准备隔离目录

插件会在远端创建自己的 workspace 目录，并设置 XDG 变量：

```sh
XDG_CONFIG_HOME=...
XDG_DATA_HOME=...
XDG_STATE_HOME=...
XDG_CACHE_HOME=...
NVIM_APPNAME=nvim
```

这样远端 Neovim 的配置、插件、缓存、状态都在 workspace 内，不会污染全局环境。

### 3. 复制配置和安装 Neovim

插件会通过 `rsync` 或压缩流传输必要文件。SSH 普通传输路径使用 `rsync`，可以增量同步并排除 `.git` 等元数据。

如果远端没有合适的 Neovim，插件会把安装脚本复制到远端，并下载安装到专用目录。

### 4. 启动 headless Neovim server

远端会启动：

```sh
nvim --listen 0.0.0.0:<remote-port> --headless
```

如果 workspace 保存了工作目录，还会加上：

```sh
--cmd 'cd <working_dir>'
```

这能保证 LSP 和项目工具从项目根目录启动。

### 5. SSH 端口转发 + 本地 UI

插件通过 SSH 建立端口转发：

```sh
ssh -L <local-port>:localhost:<remote-port> remote-host
```

随后本地启动：

```sh
nvim --server localhost:<local-port> --remote-ui
```

最终效果就是：本地显示 UI，远端运行 Neovim 和项目工具。

## 常见问题和解决思路

### 1. 为什么远端找不到 fzf

常见原因是你把 fzf 初始化放在了 `~/.zshrc`，但 SSH 远端命令通常是非交互 shell，不一定加载 `~/.zshrc`。

`~/.zshrc` 适合放 key binding、completion、prompt 等交互配置。二进制路径最好放到非交互 shell 能读取的位置。

对于 zsh，可以在 `~/.zshenv` 里放：

```sh
export PATH="$HOME/.fzf/bin:$HOME/.local/bin:$PATH"
```

保持 `~/.zshenv` 简单、安静、无副作用，不要在里面执行可能失败或有输出的命令。

### 2. Go 项目里出现 could not import

如果你看到类似：

```text
could not import xxx
go.mod file not found in current directory or any parent directory
```

不一定是依赖下载失败。更常见的原因是远端 Neovim 从 `$HOME` 启动，而不是从项目根目录启动。

解决方式：

```vim
:cd /path/to/project
:LspRestart gopls
```

更推荐在创建 SSH workspace 时填写远端 working directory。插件会保存它，下次启动时自动进入项目根目录。

### 3. goenv / asdf / mise 没生效

远端 headless Neovim 继承的是 SSH 非交互环境。如果你依赖版本管理器，需要确保 shims 在 `PATH` 前面。

以 goenv 为例：

```sh
export PATH="$HOME/.goenv/shims:$HOME/.goenv/bin:$PATH"
```

改完后重启 remote-nvim session，让远端 Neovim 和 gopls 继承新的环境。

### 4. 怎么确认远端环境是否正确

可以直接测试：

```sh
ssh remote-host 'echo "$SHELL"; echo "$PATH"; command -v fzf; command -v go; go env GOMOD GOPRIVATE GOPROXY'
```

如果这个命令里找不到工具，remote-nvim 启动的远端 Neovim 大概率也找不到。

## 小结

`remote-nvim.nvim` 的价值不在于“用插件包了一层 SSH”，而在于它把远程开发中最麻烦的几件事系统化了：

- 远端 Neovim 自动准备。
- workspace 配置持久化。
- 配置和插件数据隔离。
- 本地 UI 连接远端 server。
- 意外断开后的基础版自动重连。
- SSH、Docker、Devpod 入口统一。
- 项目工作目录和远端工具链更贴近真实运行环境。

如果你是 Neovim 用户，又需要长期在远端机器或容器里工作，这个插件值得放进你的工具箱。它让远程开发不再是“忍受一台临时机器上的半成品 Neovim”，而是把你熟悉的 Neovim 工作流带到真正运行代码的地方。
