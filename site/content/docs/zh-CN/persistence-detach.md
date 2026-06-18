# 持久化与 detach 会话

这个仓库的持久化状态刻意保持得比较小，并拆成两份文件：

- `workspace.json`，由 `ConfigProvider` 管
- `detached.json`，由 `DetachedRegistry` 管

## `config.lua` 里的 workspace 持久化

`ConfigProvider` 会把记录写到：

```text
stdpath("data")/remote-nvim/workspace.json
```

每条记录都按 host id 做 key，并通过 `update_workspace_config()` merge。里面可能保存的字段包括：

- provider 类型
- host 和 connection options
- workspace id
- remote home
- OS 和架构
- 选择过的 Neovim 版本与安装方式
- 是否复制配置
- 是否自动启动本地 client
- working directory 与 working-directory 历史
- Devpod source 元数据

这份存储是 `:RemoteStart <host-id>`、命令补全和复用过往 workspace 选择的基础。

## Session cache 和持久化配置是两层

需要把这两层明确分开：

- `SessionProvider.sessions` 只存在于运行时，里面是已经实例化过的 provider 对象
- `ConfigProvider._config_data` 是持久化数据，Neovim 重启后还在

命令层经常同时用这两层。一个命令可能先读持久化 workspace 数据来重建 provider options，再去 session cache 里复用或初始化 provider 对象。

## Detached session 的持久化

detach 的 SSH 状态会写到：

```text
stdpath("data")/remote-nvim/detached.json
```

`DetachedRegistry` 本身非常克制，只提供：

- `get_all()`
- `get(host_id)`
- `upsert(host_id, record)`
- `mark_stale(host_id)`
- `remove(host_id)`

`Provider:_detached_record()` 写进去的记录包括：

- provider
- host
- connection options
- workspace id
- remote Neovim home
- working directory
- remote port
- remote PID
- remote servername
- Neovim version
- 创建时间与最后可见时间
- detached 状态

## detach / reattach 实际上怎么工作

Detach 并不会把整个 session 对象序列化下来，它只持久化“之后能重建本地侧所需的最小元数据”。

`detach_neovim()` 会：

- 校验 provider 必须是 SSH，且 detach 模式已启用
- 写入 detached record
- 把 provider 状态标记成 detached
- 停掉本地 tunnel job
- 清空本地端口状态

`reattach_neovim(record)` 会：

- 用 `kill -0` 检查远端 PID 还活着
- 检查远端端口是否还可连接
- 找一个新的本地空闲端口
- 重建 port-forward tunnel
- 再次启动本地 client
- 重连成功后删除 detached record

如果远端 PID 或端口检查失败，这条记录不会被盲目复用，而是会被标成 stale。

## 为什么会有 stale 状态

这是一个很务实的保护。Detached record 可能比真实的远端进程活得更久。如果插件假设“既然有记录，那远端一定还在”，就会把重连做得很脆弱。

现在的做法更稳一点：一旦无法证明远端还活着，就显式标成 stale，再把清理动作引导到 `:RemoteKillDetached`。
