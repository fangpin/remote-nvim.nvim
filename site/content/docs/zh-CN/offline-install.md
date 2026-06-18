# 离线模式与安装脚本

这个仓库里的离线支持很务实，不是抽象概念。它真正要回答的问题是：远端机器访问不了 GitHub 时，怎么把一个可运行的 Neovim 放到远端。

## 离线缓存查找

`lua/remote-nvim/offline-mode.lua` 会扫描配置的缓存目录：

```text
stdpath("cache")/remote-nvim/version_cache
```

它会按 release version 建索引，并根据这些条件过滤：

- 操作系统
- 安装方式（`binary` 或 `source`）
- binary artifact 是否有对应 checksum

最后得到的是一张“版本 tag -> 本地 release 文件”的映射。这就是 provider 在开启 offline mode 且 `no_github = true` 时可用的版本来源。

## `_setup_remote()` 是怎样用离线模式的

当目标远端 Neovim 还没装好，而且 offline mode 已启用时：

- 如果 `no_github` 为 false，插件会先在本地通过 `scripts/neovim_download.sh` 下载所需 release
- 它会算出本地 release 文件路径，以及 binary 模式下可选的 checksum 文件路径
- 然后把这些 artifact 上传到远端 binary 目录
- 最后在执行远端安装脚本时追加 `-o`，让远端跳过联网下载

所以离线模式不是第二套安装系统，它只是“artifact 来源”换了一条路径，最后仍然回到同一个远端安装脚本。

## `scripts/neovim_download.sh`

下载脚本是本地辅助脚本。它负责：

- 校验 version、download type 和 architecture
- 组装 GitHub release URL
- checksum 匹配时复用现有 artifact
- 下载 binary release 或 source archive

这个脚本和 install 分开是合理的，因为现实里很常见的是：本地机器有网，远端机器没网。

## `scripts/neovim_install.sh`

安装脚本运行在远端，支持三种安装方式：

- `binary`
- `source`
- `system`

对于 binary 安装：

- Linux 侧预期拿到的是 AppImage，会解包后把里面的 `nvim` 链接出来
- macOS 侧预期拿到的是 tarball，会直接解压到版本目录

对于 source 安装：

- 预期 source tarball 已经在版本目录里
- 然后解压并用 `make` 或 `gmake` 构建 Neovim

对于 system 安装：

- 先检查远端 PATH 上是否已经存在 `nvim`
- 再把它软链到插件托管的版本目录里

不管哪种方式，最终目标布局都会落到：

```text
<remote_neovim_home>/nvim-downloads/<version>/bin/nvim
```

## 脚本同步与 checksum

Provider 不会每次 launch 都盲目重传 helper scripts。

- `_get_local_plugin_scripts_checksum()` 会遍历本地 `scripts/` 目录并按文件内容计算 checksum
- `_sync_plugin_scripts()` 会把它和远端 checksum marker 对比
- 只有 checksum 不一致时才重新上传整个脚本目录

这个优化很重要，因为 remote setup 本身已经足够昂贵，脚本同步不应该在每次 reconnect 时再额外制造无谓传输。

## 更实用的排障切法

安装失败时，先把问题切到下面几个桶里：

- 版本选择错了：更可能是 provider 的版本或安装方式选择
- 本地 artifact 不存在：更可能是离线缓存或 download 步骤
- 远端解包或构建失败：更可能是 `neovim_install.sh`
- 本地机器缺 binary：更可能是 `health.lua` 与环境准备问题

这个仓库的安装路径不算窄，但只要把“本地下载”“远端安装”“provider 编排”三层分开看，边界还是很清楚的。
