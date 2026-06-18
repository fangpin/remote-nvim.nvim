# UI 与诊断

这个仓库的 UI 不算多，但设计得并不随便。它不只是一个 progress log，而是 active session 的主要运行态检查面。

## `ui/progressview.lua`

Progress viewer 基于 NUI 搭出来：

- 外层容器是 `Popup` 或 `Split`
- 进度节点和 session-info 节点用 `NuiTree`
- 顶部标题行用 `NuiLine`

布局来自 `remote_nvim.config.progress_view`。

- `type = "split"` 时是侧边 split，可配置 size 和 position
- `type = "popup"` 时是 popup，可配置 border、anchor 和 resize 处理

这意味着 UI 可配置性不算深，但是真实存在。仓库没有自己重造窗口系统，而是把窗口行为大部分交给了 NUI。

## 一个窗口，三块 pane

Progress viewer 实际可以切换三块 pane：

- progress pane
- session-info pane
- help pane

`switch_to_pane()` 的实现很轻，只是换当前窗口绑定的 buffer，并在需要时折叠树节点。这样 UI 代码就能把注意力放在“数据怎么组织”，而不是“窗口怎么编排”。

## Progress 输出是被整形过的

这个 viewer 区分了多种 node 类型：

- run node
- section node
- command node
- stdout node

对于输出很长的命令，它会用 `section_deque_map` 和 `max_output_lines = 30` 来限制每个 section 可见的 stdout 行数。这样在安装、复制一类长命令期间，面板仍然可读，不会被一条输出完全淹没。

## Session 信息的刷新方式

`set_session_section(title, holds, entries)` 是 session pane 最关键的 API。

Provider 会通过它刷新某个 section，而不是一遍遍 append 重复行。结果就是 session pane 更像“当前状态视图”，而不是简单历史日志。

Provider 会往里塞的信息包括：

- 本地 OS 与 Neovim 版本
- 日志路径与插件版本
- host id 与远端路径
- 当前 working directory
- 运行态诊断，比如本地端口、远端 PID、reconnect 状态

## Clipboard diagnostics

`command.lua` 里的 `:RemoteClipboardCheck` 会连上远端 Neovim server，执行一段 Lua probe，再把结果带回本地。

它检查的内容包括：

- `vim.o.clipboard`
- `vim.g.clipboard`
- copy / paste 函数是否存在
- OSC52 是否可用
- `vim.g.remote_nvim_clipboard`
- 当前挂载的 UI 数量

然后命令会把结果在本地通知出来，并在支持时回写到 provider 的诊断状态里。

这很有用，因为远程工作流里的 clipboard 故障，往往不是单一配置缺失，而是本地桥接和远端桥接之间的契约不一致。

## Health check

`health.lua` 的边界更窄，它只负责验证本地 binary 可用性并输出版本。

检查范围包括：

- `curl`
- `tar`
- 配置的 SSH binary
- 配置的 rsync binary
- 配置的 Devpod binary
- 配置的 Docker binary

这里也体现了产品边界：没有 Devpod 仍然可能跑 SSH，但缺少 `curl`、`ssh` 或 `rsync` 时，复制和安装路径就会明显退化。

## 浮动 terminal 形式的本地 UI

`ui.lua` 暴露的 `float_term()` 被默认 `client_callback` 直接使用。它会创建一个近似全屏的浮动 terminal，用 `termopen()` 执行本地 attach 命令，并在进程正常退出时自动 unmount popup。

这就是为什么默认 attach 体验更像一个临时、聚焦的 UI 表面，而不是常驻 split。
