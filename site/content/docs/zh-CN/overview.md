# 这个仓库实际是什么

`remote-nvim.nvim` 是一个 Lua 插件。它会在远端目标上启动 headless Neovim 进程，再把本地 Neovim UI 挂到这个远端进程上。README 讲的是用户视角，这里更关心内部结构，可以先按三层理解：

- `lua/remote-nvim/init.lua` 负责插件 setup、默认配置树、本地 client 的剪贴板桥接，以及默认 `client_callback`。
- `lua/remote-nvim/command.lua` 暴露用户命令面，把一次命令调用转成 session 查找、选择或 provider 操作。
- `lua/remote-nvim/providers/` 才是真正的生命周期层：workspace 初始化、远端安装、配置上传、端口转发、重连、detach、清理，以及 provider 特有的编排逻辑。

## 系统地图

这个仓库顶部刻意很薄，状态和流程都收敛在 provider 层。

- `init.lua` 里的 `setup()` 会把用户配置 merge 到 `default_opts`，创建 `SessionProvider`，注册命令，初始化高亮，并截断日志文件。
- `providers/session_provider.lua` 里的 `SessionProvider` 是内存中的枢纽，按唯一 host id 懒加载 provider 对象并复用。
- `config.lua` 里的 `ConfigProvider` 是持久化枢纽，把 workspace 记录写到 `stdpath("data")/remote-nvim/workspace.json`。
- `providers/provider.lua` 里的 `Provider` 是共享生命周期实现。SSH 和 Devpod 都是在这个共享底座上加薄薄一层。

这点很关键：大多数用户可见行为实际上都来自 `Provider`，哪怕 session 是由 SSH 或 Devpod 特化类创建的。

## 真正重要的职责边界

理解这个仓库时，可以优先盯这些文件边界：

- `init.lua`：默认配置和本地入口接线
- `command.lua`：用户命令面和选择逻辑
- `providers/provider.lua`：共享远端生命周期与运行态状态
- `providers/ssh/ssh_provider.lua`：SSH 身份与选项归一化
- `providers/ssh/ssh_executor.lua`：SSH 命令执行、传输、prompt 处理、端口转发、detach 启动
- `providers/ssh/ssh_config_parser.lua`：支持 `Include` 的 best-effort SSH 配置解析
- `providers/devpod/devpod_provider.lua`：建立在 SSH 传输之上的 Devpod 工作区生命周期
- `config.lua` 与 `detached_registry.lua`：持久化
- `ui/progressview.lua`、`ui.lua`、`health.lua`：UI 与诊断
- `offline-mode.lua` 以及 `scripts/*.sh`：离线 release 查找与远端安装流程

## 该怎样读后续章节

后面的文档都遵循同一个原则：按代码边界讲当前行为，而不是按 feature 文案讲故事。

- 想知道 `setup()` 到底做了什么，先看入口层章节。
- 想回答“我选了一个 host 之后到底发生了什么”，直接看 provider 生命周期章节。
- 关心 rsync、tar 上传、交互提示或 detach，会更适合看 SSH 传输章节。
- 排查 progress view、clipboard、health check 或安装失败时，再看 UI 和离线安装章节。

这个站点是补充 README 和 vimdoc 的，不是替代它们。README 更适合安装与使用示例，这里的文档更适合读控制流和实现边界。
