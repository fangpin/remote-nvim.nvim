# Provider 生命周期

这个插件真正的发动机在 `lua/remote-nvim/providers/provider.lua`。SSH 和 Devpod 本质上都是在这个共享生命周期之上加薄层。

## Session 对象与复用

`SessionProvider:get_or_initialize_session()` 会按唯一 host id 只创建一次 provider 对象，之后都从 `self.sessions` 里复用。

- SSH session 一般按 host 作为 key；如果 SSH 选项里带了 `-p`，通常会变成 `host:port`
- Devpod session 则按传入 provider options 的 Devpod workspace id 作为 key

结果是 provider 对象会在整个本地 Neovim 进程生命周期里积累运行态状态：当前端口、progress viewer、远端 PID、重连计数器、缓存的 workspace 配置等等。

## Workspace 初始化

共享初始化入口是 `_setup_workspace_variables()`。

它负责：

- 在没有记录时创建初始 workspace 记录
- 读取或迁移保存的 `working_dir` 和 `working_dirs`
- 用 `uname -s -m` 探测远端 OS 和架构
- 选择或复用远端 Neovim 版本与安装方式
- 找出远端基础 home，一般是 `$HOME/.remote-nvim`
- 推导 workspace 级别的 XDG 路径
- 缓存本地要复制过去的 `config`、`data`、`state`、`cache` 路径
- 刷新 progress view 里的 session 信息

这就是为什么 provider 状态会比较“厚”：等真正 launch 的时候，provider 已经拿到一个归一化过的远端模型和一份持久化 workspace 记录。

## Working directory 的处理

`_setup_remote_working_dir()` 是一条 SSH 特有、而且明显有状态的逻辑。

- 如果 provider 类型是 SSH，且当前还没有设置 working directory，它会优先提供历史使用过的目录列表
- 选中的目录会成为当前 `working_dir`，同时被追加进 `working_dirs` 历史列表
- 这些值会被重新写回 `workspace.json`

这不是表面上的 UX 装饰。后续运行时 provider 能直接给出历史目录选择，而不是每次都强迫用户重新手输。

## 共享启动流水线

当 `launch_neovim()` 进入 `Provider:_launch_neovim()`，共享流程基本固定：

1. 处理 provider-stopped 状态，并在 fresh run 时重置 reconnect 计数器
2. 必要时创建一条新的 progress-view run
3. 调用 `_setup_workspace_variables()`
4. 调用 `_setup_remote_working_dir()`
5. 调用 `_setup_remote()`
6. 调用 `_launch_remote_neovim_server()`
7. 调用 `_launch_local_neovim_client()`

所以 provider 既负责远端 bootstrap，也负责最后的本地 attach。

## `_setup_remote()` 才是真正的重活

`_setup_remote()` 会创建远端目录、同步 helper scripts、判断远端 Neovim 是否已安装、必要时安装，并上传选定的本地目录。

几个关键点：

- 每个 workspace 都有隔离的 XDG 树，落在远端 workspace 路径下
- helper scripts 会先算 checksum，只有内容变了才重新上传
- 支持三种安装方式：`binary`、`source`、`system`
- 离线模式开启时，可以先在本地下载 release 再上传到远端
- 它会询问是否复制本地 config，然后分别处理 `data`、`state`、`cache` 的额外复制规则

这里才是大部分操作成本所在。命令路由很轻，`_setup_remote()` 并不轻。

## Reconnect 行为

远端异常退出最后都会走到 `_handle_remote_server_exit()`。

- 如果 session 是刻意 detach 的，这次退出会被当成成功处理
- 否则，如果 `remote.reconnect.enabled = true` 且尝试次数没超，就会通过 `_schedule_reconnect()` 安排重试
- 重试延迟是线性的，公式接近 `backoff_ms * attempt_number`
- 如果不再重连，provider 会刷新诊断、必要时展示 progress view、停止当前 session，并重置大部分运行态状态

因为 reconnect 是在 provider 对象内部实现的，所以它可以直接复用现有 workspace 元数据，并沿着同一条 `_launch_neovim(false)` 路径再次拉起。
