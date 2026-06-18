# Devpod 与容器工作流

这个仓库对外宣称支持 Docker image、Docker container 和 devcontainer，但实现路径其实比表面能力更收敛。

## 为什么 Devpod 这么关键

`lua/remote-nvim/providers/devpod/devpod_provider.lua` 是继承 `SSHProvider` 的，而不是反过来。这已经说明了实现模型：

- Devpod 负责创建 workspace 和生成 SSH config
- 一旦 workspace 存在，remote-nvim 基本上就把它当成一个 SSH 目标来处理

所以 Devpod 不是一套与 SSH 平行的传输栈，而是一层 workspace orchestration，最终还是把运行态落回 SSH 风格的连接。

## DevpodProvider 额外补了什么

在共享 provider 生命周期之上，`DevpodProvider` 额外承担：

- 校验配置的 `devpod` binary 是否存在
- 持有 workspace source 元数据，比如 repo、image、container 或 existing workspace id
- 通过 `-F <ssh_config_path>` 使用 Devpod 生成的 SSH config
- 在本地执行 `devpod up`、`stop`、`delete` 和 provider 管理命令

构造函数里会预设 `_up_default_opts`，例如 `--open-ide=false`、`--configure-ssh=true`、`--ide=none`。对于非 existing source，还会把生成的 SSH config 路径写进启动参数。

## Workspace 拉起路径

Devpod 特有的核心方法是 `_launch_devpod_workspace()`。

它会：

- 先确保 provider setup 已经完成
- 根据选择的 source 和 source id 组装 `devpod up` 参数
- 把只属于后续 SSH 层的原始 SSH config flags 从 Devpod 命令行里剥掉
- 先在本地执行 `devpod up`，再进入共享的 `_launch_neovim(false)` 路径

也就是说，Devpod 把“工作区存在”这件事解决后，后续远端 setup 基本都还是共用 provider 流程。

## Provider setup 与 cleanup

DevpodProvider 还要处理一些 SSHProvider 不需要的副作用：

- `_handle_provider_setup()` 可能会执行 `devpod provider list --output json` 和 `devpod provider add`
- `stop_neovim()` 除了停 Neovim，也可能会停掉底层 Devpod workspace
- `clean_up_remote_host()` 在远端 cleanup 之后，还可以额外删除整个 Devpod workspace

这让 Devpod session 的生命周期比普通 SSH 更宽。停止远端 Neovim 进程可能还不够，workspace 本身也可能需要在本地被创建、停止或删除。

## 这种分层的价值

这种架构让传输复用最大化：

- SSH executor 继续负责上传、远端命令和 tunnel
- 共享 provider 继续负责安装、配置复制、progress view、诊断和本地 attach
- Devpod 特化逻辑只聚焦在 workspace provisioning 与 lifecycle

所以当 devcontainer 流程失败时，先判断问题落在哪一段：

- workspace 创建前失败：多半是 DevpodProvider 或本地 Devpod CLI 状态
- workspace 已创建，但 attach 前失败：多半是共享 provider setup
- copy 或 tunnel 过程中失败：更可能是 SSH executor 行为
