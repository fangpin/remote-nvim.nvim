# 用 Neovim 做远程开发：remote-nvim.nvim 的设计与实践

远程开发的目标很简单：代码、依赖、构建工具运行在远端机器上，编辑体验仍然保持在本地。VS Code Remote 已经把这个模式做得很成熟，而 `remote-nvim.nvim` 做的是把类似体验带到 Neovim 里。

这篇文章会介绍 `remote-nvim.nvim` 解决了什么问题、整体架构是什么、一次 SSH 远程会话是如何启动的，以及在真实使用中容易遇到的环境变量、`fzf`、`gopls` 和工作目录问题。

## 为什么不是直接 SSH 上去运行 nvim

最朴素的远程开发方式是：

```sh
ssh remote-host
nvim
```

这种方式可用，但也有一些明显限制：

- 远端必须提前安装合适版本的 Neovim。
- 远端需要准备完整的 Neovim 配置和插件数据。
- 每台机器的配置容易漂移，清理成本高。
- 断开后恢复会话不够方便。
- 如果多人共用同一个远端账号，直接写全局配置容易互相影响。

`remote-nvim.nvim` 的思路是：本地 Neovim 负责发起和管理远程会话，远端只运行一个隔离的 headless Neovim server。本地再启动一个 Neovim UI，通过 RPC 连接到远端 server。这样可以把编辑界面留在本地，把语言服务、文件 IO、构建工具都放在远端执行。

## 插件支持的远程形态

`remote-nvim.nvim` 当前主要支持这些远程模式：

- SSH 主机
- SSH config 中配置过的主机
- Docker image
- Docker container
- Devpod / devcontainer

其中 SSH 是最直接的模式，也是理解插件原理的最好入口。下面主要以 SSH 为例。

## 一次 SSH 远程会话如何启动

从用户视角看，通常是通过 Telescope 选择一个入口：

- 从 SSH config 里选择 host。
- 手动输入 SSH connection string。
- 选择一个已经保存过的 remote workspace。

内部大致分成几个阶段。

### 1. 创建或加载 workspace 配置

插件会为每个远端 host 维护一份 workspace 配置，记录这类信息：

- provider 类型，例如 `ssh`。
- host 和 connection options。
- workspace ID。
- 远端 Neovim 安装目录。
- 使用的 Neovim 版本。
- 是否自动启动本地 client。
- 是否复制本地配置。
- SSH workspace 的远端工作目录 `working_dir`。

这些信息会持久化保存。后续再次连接同一个 workspace 时，插件可以复用历史选择，而不是每次重新询问。

### 2. 检查远端系统和 Neovim 版本

插件会通过 SSH 在远端执行命令，例如：

```sh
uname -s -m
echo $HOME
```

它用这些信息判断远端系统、架构、安装目录和可用的 Neovim 安装方式。

如果远端没有合适的 Neovim，插件可以把安装脚本复制过去，并下载安装到 workspace 专用目录下。这样不会污染远端用户的全局环境。

### 3. 准备隔离的 XDG 目录

远端 Neovim 不是直接使用远端用户的默认 `~/.config/nvim`、`~/.local/share/nvim` 等目录，而是使用 workspace 内的隔离目录，例如：

```text
~/.remote-nvim/workspaces/<workspace-id>/.config
~/.remote-nvim/workspaces/<workspace-id>/.local/share
~/.remote-nvim/workspaces/<workspace-id>/.local/state
~/.remote-nvim/workspaces/<workspace-id>/.cache
```

启动远端 Neovim 时，插件会设置：

```sh
XDG_CONFIG_HOME=...
XDG_DATA_HOME=...
XDG_STATE_HOME=...
XDG_CACHE_HOME=...
NVIM_APPNAME=nvim
```

这保证了远端会话有自己的配置、插件、缓存和状态目录。

### 4. 复制本地配置和插件数据

如果用户选择复制本地配置，插件会把本地 Neovim 配置同步到远端 workspace。

当前 SSH 传输使用 `rsync`，这样可以更好地处理增量同步，并排除 `.git` 这类不需要复制的元数据。压缩上传路径仍然通过 `tar | ssh` 的方式流式传输。

### 5. 启动远端 headless Neovim server

准备完成后，插件会先在远端找一个可用端口，然后启动 headless Neovim：

```sh
nvim --listen 0.0.0.0:<remote-port> --headless
```

如果 workspace 配置里保存了 `working_dir`，启动命令会额外带上：

```sh
--cmd 'cd <working_dir>'
```

这一步很重要。语言服务器、文件搜索、项目工具通常依赖当前工作目录来发现 `go.mod`、`package.json`、`.git` 等项目文件。让远端 Neovim 从项目根目录启动，能避免很多“找不到模块”或“项目根识别错误”的问题。

### 6. 建立 SSH 端口转发

远端 server 启动后，插件会在 SSH 命令上加端口转发：

```sh
ssh -L <local-port>:localhost:<remote-port> remote-host ...
```

本地只需要访问 `localhost:<local-port>`，就可以连接到远端 Neovim server。

### 7. 启动本地 Neovim UI

最后本地启动一个 Neovim client：

```sh
nvim --server localhost:<local-port> --remote-ui
```

此时 UI 在本地，实际 buffer、LSP、插件运行环境在远端。你看到的是本地终端里的 Neovim 界面，但它操作的是远端文件系统和远端工具链。

## 远程环境变量：为什么 `.zshrc` 不一定生效

SSH provider 的远端命令形式接近：

```sh
ssh remote-host '<command>'
```

这类命令通常由远端用户的默认 shell 以非交互、非 login 的方式执行。例如远端登录 shell 是 zsh 时，往往相当于：

```sh
zsh -c '<command>'
```

这意味着 `~/.zshrc` 不一定会被加载。`~/.zshrc` 本来就更适合放交互式配置，比如 prompt、补全、key binding 和 fzf shell integration。

如果远端 Neovim、LSP 或插件需要找到某个二进制，例如 `fzf`、`go`、`node`，更稳妥的方式是把轻量的 `PATH` 配置放到非交互 shell 会读取的位置。

对于 zsh，通常可以放在 `~/.zshenv`：

```sh
export PATH="$HOME/.goenv/shims:$HOME/.goenv/bin:$HOME/.fzf/bin:$HOME/.local/bin:$PATH"
```

需要注意，`~/.zshenv` 应该尽量保持轻量、无输出、无副作用。不要在里面执行耗时命令或可能失败的命令，例如：

```sh
go env -w ...
brew --prefix ...
```

这些命令在非交互 SSH 环境中失败时，可能污染插件任务输出，甚至导致远程启动失败。

## `fzf` 找不到的典型原因

很多用户会把 fzf 初始化放在 `~/.zshrc`：

```sh
source ~/.fzf.zsh
```

这主要配置的是交互式 shell 的快捷键和补全，并不等同于把 `fzf` 二进制加入远端 Neovim 的 `PATH`。

对 `remote-nvim.nvim` 来说，关键是远端 headless Neovim 进程能执行：

```sh
command -v fzf
```

因此建议把二进制路径放到 `~/.zshenv`：

```sh
export PATH="$HOME/.fzf/bin:$PATH"
```

而 fzf 的交互式初始化仍然保留在 `~/.zshrc`。

## Go / gopls 的工作目录问题

Go 项目里最常见的问题是：

```text
could not import xxx
go.mod file not found in current directory or any parent directory
```

这不一定是 `GOPRIVATE` 或 `GOPROXY` 没配好，也可能是远端 Neovim 从 `$HOME` 启动，而不是从项目根目录启动。

例如项目在：

```text
/data00/home/user/go_repos/src/example.com/team/project
```

但远端 Neovim 的当前目录是：

```text
/data00/home/user
```

某些工具看到相对路径时，就可能从 home 目录开始解析，找不到项目里的 `go.mod`。

新的 SSH workspace working directory 机制就是为了解决这个问题：首次创建 SSH workspace 时输入项目根目录，插件会保存到 workspace setting。后续启动远端 Neovim 时会自动执行：

```sh
--cmd 'cd /data00/home/user/go_repos/src/example.com/team/project'
```

这样 gopls、文件搜索、终端命令都会以项目根作为默认上下文。

## 配置和排查建议

### 检查远端非交互环境

可以直接运行：

```sh
ssh remote-host 'echo "$SHELL"; echo "$PATH"; command -v fzf; command -v go; go env GOMOD GOPRIVATE GOPROXY'
```

如果这里找不到 `fzf` 或 `go`，那么 remote-nvim 启动的 headless Neovim 大概率也找不到。

### 检查 Neovim 当前工作目录

进入远端 UI 后执行：

```vim
:pwd
```

如果不是项目根目录，可以临时修复：

```vim
:cd /path/to/project
:LspRestart gopls
```

长期方案是给 SSH workspace 保存 `working_dir`。

### 检查 gopls 使用的 Go 版本

如果项目使用 `goenv`、`asdf`、`mise` 等版本管理器，要确保 shims 出现在远端 headless Neovim 的 `PATH` 前面。

对于 `goenv`：

```sh
export PATH="$HOME/.goenv/shims:$HOME/.goenv/bin:$PATH"
```

然后重启 remote-nvim session，让远端 Neovim 和 gopls 继承新环境。

## 适合什么场景

`remote-nvim.nvim` 适合这些场景：

- 你主要使用 Neovim，但需要在远端 Linux 机器上开发。
- 项目依赖、数据或构建环境只能在远端访问。
- 你希望远端环境隔离，不想污染远端默认 Neovim 配置。
- 你希望快速恢复之前连接过的远端 workspace。
- 你希望在容器、Devpod、SSH 主机之间使用统一入口。

它不适合的场景也很明确：

- 你只需要偶尔 SSH 上去改一个文件。
- 远端无法安装或运行 Neovim。
- 网络延迟极高，无法稳定维持 UI RPC 连接。
- 团队已经完全绑定了另一套远程 IDE 工作流。

## 总结

`remote-nvim.nvim` 的核心不是简单地“帮你 SSH 上去运行 nvim”，而是把远程开发拆成几个可管理的部分：

- 本地发起和管理 workspace。
- 远端安装并运行隔离的 headless Neovim。
- 通过 SSH 传输配置、同步文件和做端口转发。
- 本地 Neovim UI 连接远端 server。
- workspace setting 持久化用户选择。

理解这个模型后，很多问题都会变得清楚：`fzf` 找不到，多半是非交互 shell 的 `PATH`；Go import 失败，可能是工作目录或 Go 版本管理器；远端配置混乱，则应该看 XDG 目录和 workspace setting。

对重度 Neovim 用户来说，这个插件提供了一条很自然的远程开发路径：保留 Neovim 的编辑体验，同时把代码执行环境放到真正应该运行的地方。
