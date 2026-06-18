# SSH 传输与配置解析

SSH 相关行为主要集中在三个文件：

- `providers/ssh/ssh_provider.lua`
- `providers/ssh/ssh_executor.lua`
- `providers/ssh/ssh_config_parser.lua`

## SSHProvider 本身很小

`SSHProvider` 主要只做三件事：

- 归一化连接选项
- 用 `SSHExecutor` 替换掉通用 executor
- 根据 host 和可选的 `-p` 端口推导唯一 host id

这个类故意保持得很薄，因为绝大部分生命周期行为已经在共享的 `Provider` 里了。

## `SSHExecutor` 才是传输核心

`SSHExecutor` 在通用 executor 之上加了 SSH 特有职责：

- 用配置里的 SSH binary 构造远端命令
- 用配置里的 rsync binary 构造 rsync 调用
- 处理交互式 SSH prompt
- 启动只负责端口转发的 SSH job
- 用 pidfile 启动 detach 的远端命令

这层划分在排障时非常有用。如果问题出在 copy、prompt 处理或 tunnel 创建，通常应该去看 `SSHExecutor`，而不是 `SSHProvider`。

## 上传实际上有两条完全不同的路径

`SSHExecutor:upload()` 会直接分叉：

- 非压缩上传走 `rsync`
- 压缩上传会构造 `tar czf - ... | ssh ... "tar xvzf -"` 这条流式管道

仓库里的 `AGENTS.md` 专门强调这件事是有原因的：你改 rsync 路径时，不能不小心把压缩路径也顺带改坏，因为压缩路径依赖的是 tar streaming，不是 rsync 语义。

非压缩上传大致会生成：

```sh
rsync -r -e 'ssh <opts>' --exclude .git <local> <host>:<remote>
```

压缩上传时，`SSHExecutor` 会先找本地路径的公共父目录，打包选中的路径，再在远端解压到目标目录，并执行 `chown -R $(whoami)`。

## Prompt 处理由配置驱动

交互式 SSH 输入不是硬编码在 executor 里的，而是由插件配置里的 `ssh_prompts` 驱动。

每条 prompt 定义包括：

- 匹配 stdout 的 plain string
- 输入是否是 secret
- 值是 static 还是 dynamic
- 可选的默认值或自定义提示文案

`process_stdout()` 会扫描新增的 SSH 输出，只要发现匹配字符串，就调用 `_process_prompt()`。如果 prompt 被标成 static，成功执行后它的输入值可以在当前 session 内被缓存。

## 端口转发与 detach 启动

运行态里有两个很关键的传输辅助方法：

- `start_port_forward(local_port, remote_port)` 会启动一个带 `-N -L ...` 的 SSH job
- `run_detached_server_command(command, pidfile)` 会用 `nohup sh -c ...` 启动远端后台进程，并把 shell PID 写到 pidfile

只有当 `remote.detach.enabled = true` 且 provider 类型是 SSH 时，才会走 detach 路径。这个模式下，插件会把：

- 真正继续活在远端的 Neovim server 进程
- 可以被停止和重建的本地端口转发 tunnel

明确拆成两段。这也是 `:RemoteDetach` / `:RemoteReattach` 能成立的前提。

## `ssh_config` 解析是 best effort

`ssh_config_parser.lua` 开头就写得很直接：它不是一个严格、完整、逐条符合 OpenSSH 规范的 parser。

它只做插件真正需要的部分：

- 处理 `Host` block
- 处理 `Include`
- 跟踪全局选项
- 对普通 host 继承忽略 `Match` block
- 在后处理中让 wildcard host 的配置能回流到具体 host 上

它还会把相对 include 路径按父配置文件目录展开，并在 include 无法解析时记日志。

实际意义很简单：这个 parser 追求的是“足够好地列出 host、近似拿到配置”，而不是完整模拟 OpenSSH 的所有边角语义。
