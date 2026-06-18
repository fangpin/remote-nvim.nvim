# 入口层与命令面

入口层主要就是 `lua/remote-nvim/init.lua` 和 `lua/remote-nvim/command.lua`。这一层刻意保持得很薄：负责接住用户意图、归一化配置，然后把重活交给 provider session。

## `init.lua` 里的 `setup()`

`setup()` 实际上只做四件事：

- 用 `remote-nvim.constants.MIN_NEOVIM_VERSION` 检查最低 Neovim 版本
- 把用户配置 deep-merge 到 `M.default_opts`
- 创建 `M.session_provider = require("remote-nvim.providers.session_provider")()`
- 加载命令注册和高亮初始化

这意味着整个本地 Neovim 进程里只有一个共享的 `session_provider`。命令每次调用时不会重新构建一套新世界，而是路由进这个共享 provider 注册表。

## `default_opts` 真正定义了什么

`init.lua` 里的默认配置树是最完整的 schema 参考，比 README 摘要更细。

- `devpod`：binary 名称、SSH config 路径、搜索策略、dotfiles、GPG forwarding、container 列表模式
- `ssh_config`：SSH binary、rsync binary、配置文件列表，以及用于识别 SSH 交互输入的 prompt pattern
- `remote`：`app_name`、reconnect 策略、detach 开关，以及 `config`、`data`、`state`、`cache` 的复制规则
- `progress_view`：进度 UI 是 popup 还是 split
- `offline_mode`：离线缓存行为
- `log`：日志文件路径、级别和截断阈值
- `client_callback`：本地 UI 如何挂上来

默认 `client_callback` 会调用 `launch_terminal_client()`，最终打开一个浮动 terminal，执行：

```sh
nvim --server localhost:<port> --remote-ui
```

如果你覆写 `client_callback`，你替换的不是远端 setup，而只是远端服务和本地 tunnel 都就绪之后的“本地 attach”这一步。

## 本地剪贴板桥接

`init.lua` 不只是 merge 配置。默认本地 client 启动前，还会先走 `prepare_local_clipboard_bridge()`。

- 在 Neovide 里，它优先使用基于 `neovide.set_clipboard` / `neovide.get_clipboard` 的自定义适配层。
- 否则，它先尝试沿用本地已有 clipboard provider；如果不存在，再退回到 OSC52 provider。

这一层本地桥接正好和后面 `Provider:_get_clipboard_setup_cmd()` 注入到远端的 clipboard setup 对应起来。这个仓库把远端剪贴板支持当成一份双边契约，而不是只在远端开个开关。

## `command.lua` 里注册了哪些命令

`command.lua` 暴露的是完整用户命令面：

- `:RemoteStart`
- `:RemoteStop`
- `:RemoteInfo`
- `:RemoteCleanup`
- `:RemoteConfigDel`
- `:RemoteLog`
- `:RemoteClipboardCheck`
- `:RemoteDetach`
- `:RemoteReattach`
- `:RemoteKillDetached`

每个命令都尽量只做一层薄路由：

- 解析 host id，或者通过 `vim.ui.select` / Telescope 让用户选
- 校验当前 session 状态
- 向 `session_provider` 要一个 session，或者读取保存好的 workspace 记录
- 把具体动作下沉给 provider 实例方法

## `:RemoteStart` 本质上是个路由器

`RemoteStart` 有两种模式：

- 不带参数时，打开 Telescope extension，让用户选远程入口
- 带 host identifier 时，从 `ConfigProvider` 读取保存的 workspace 配置，重建 provider options，然后在对应 session 上调用 `launch_neovim()`

这点和重连行为很相关。命令层自己不会“从零重放整个 setup”，它只是重建 enough provider identity，让 `SessionProvider` 去复用现有 session 对象，或者初始化正确的 provider 类。

## 命令补全依赖持久化状态

多个命令的 completion 都直接依赖已保存或运行中的状态：

- `RemoteStart` 和 `RemoteCleanup` 从保存过的 workspace id 补全
- `RemoteInfo`、`RemoteStop`、clipboard 检查从当前 active session 补全
- detach 相关命令从 detached registry 补全

所以命令层虽然薄，但命令体验质量其实依赖 `workspace.json`、活跃 session 状态和 `detached.json` 是否一致。
