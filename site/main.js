const translations = {
  en: {
    brandTagline: "remote development for Neovim",
    navDocs: "Docs",
    navGithub: "GitHub",
    navReadme: "README",
    navReadmeZh: "Chinese docs",
    eyebrow: "GitHub Pages showcase",
    heroTitle: "Remote-first Neovim, without giving up your local workflow.",
    heroLead:
      "Launch and manage remote Neovim sessions across SSH hosts, Docker images, Docker containers, and Devpod workspaces, then drive them from your local Neovim UI.",
    heroPrimaryCta: "Open repository",
    heroDocsCta: "Read detailed docs",
    heroSecondaryCta: "Install with lazy.nvim",
    statModes: "remote modes",
    statDocs: "implementation chapters",
    statClipboardValue: "OSC 52",
    statClipboard: "clipboard bridge",
    terminalLine1: ":RemoteStart",
    terminalLine2: "Provider: SSH config",
    terminalLine3: "Workspace: backend-prod",
    terminalLine4: "Remote server ready on port 34681",
    terminalLine5: "Local UI attached via --remote-ui",
    localLabel: "Local Neovim",
    clipboardNode: "OSC 52 clipboard",
    remoteLabel: "Remote runtime",
    providerNode: "SSH / Docker / Devpod",
    serverNode: "Headless Neovim server",
    showcaseEyebrow: "Real workflow",
    showcaseTitle: "A homepage that shows the actual product.",
    showcaseLead:
      "The first viewport should explain what the plugin does. The next band should show what it looks like in use.",
    mediaMetaTutorial: "Tutorial overview",
    mediaTitleTutorial: "See the plugin in motion before you install it.",
    mediaBodyTutorial:
      "Link directly to the existing demo video so visitors can inspect real usage instead of reading abstract claims.",
    watchDemo: "Watch demo",
    installSnippetLabel: "Install snippet",
    copyButton: "Copy",
    featuresEyebrow: "Capability map",
    featuresTitle: "Built around practical remote editing paths.",
    feature1Title: "Connection surfaces",
    feature1Body:
      "SSH with password, SSH keys, SSH config, Docker images, Docker containers, and Devpod-backed devcontainers.",
    feature2Title: "Remote bootstrap",
    feature2Body:
      "Install Neovim remotely, keep it isolated under a plugin-managed home, and sync selected local config directories.",
    feature3Title: "Operational diagnostics",
    feature3Body:
      "Inspect runtime details with `:RemoteInfo`, debug clipboard behavior with `:RemoteClipboardCheck`, and review logs when needed.",
    feature4Title: "Session lifecycle",
    feature4Body:
      "Reconnect to saved workspaces, use offline release transfers, and manage detached SSH sessions with explicit reattach and cleanup commands.",
    docsMapEyebrow: "Architecture docs",
    docsMapTitle: "Detailed chapters anchored in the current Lua codebase.",
    docsMapLead:
      "The docs section mirrors English and Chinese chapters across setup, providers, transport, persistence, UI, and offline install behavior.",
    docsCard1Meta: "Chapter 1",
    docsCard1Title: "System map and entrypoint",
    docsCard1Body:
      "Start with the ownership boundaries, then trace how `setup()` and `:RemoteStart` hand control to a provider session.",
    docsCard2Meta: "Chapter 3",
    docsCard2Title: "Provider lifecycle and persistence",
    docsCard2Body:
      "See how sessions are cached in-memory, what gets persisted to `workspace.json`, and how reconnect works.",
    docsCard3Meta: "Chapter 4",
    docsCard3Title: "SSH transport and Devpod funnel",
    docsCard3Body:
      "Inspect the rsync and tar upload paths, prompt handling, host parsing, and how Docker and devcontainer flows land on Devpod.",
    docsCard4Meta: "Chapter 7",
    docsCard4Title: "UI, diagnostics, and install scripts",
    docsCard4Body:
      "Follow the progress viewer, clipboard diagnostics, health checks, offline cache scan, and remote install scripts.",
    docsCardLink: "Read chapter",
    supportEyebrow: "Support matrix",
    supportTitle: "The project surface, at a glance.",
    tableHeadMode: "Remote mode",
    tableHeadStatus: "Current support",
    modeSshPassword: "SSH (password)",
    modeSshKey: "SSH (SSH key)",
    modeSshConfig: "SSH (`ssh_config`)",
    modeDockerImage: "Docker image",
    modeDockerContainer: "Docker container",
    modeDevcontainer: "Devcontainer",
    supportFull: "Fully supported",
    requirementsLabel: "Local requirements",
    requirementsBody:
      "OpenSSH client, Neovim 0.9+, `curl`, `rsync`, optional `tar`, and `devpod` when you want devcontainer workflows.",
    remoteReqLabel: "Remote requirements",
    remoteReqBody:
      "OpenSSH-compliant server, `bash`, either `curl` or `wget`, `rsync`, and network access to Neovim releases unless offline mode is used.",
    commandsLabel: "Key commands",
    commandsBody:
      "`:RemoteStart`, `:RemoteStop`, `:RemoteInfo`, `:RemoteCleanup`, `:RemoteClipboardCheck`, `:RemoteDetach`, `:RemoteReattach`.",
    timelineEyebrow: "Flow",
    timelineTitle: "How a remote session comes together.",
    timeline1Title: "Choose a remote provider",
    timeline1Body: "Pick SSH, Docker, Docker container, or Devpod from `:RemoteStart`.",
    timeline2Title: "Bootstrap the remote runtime",
    timeline2Body:
      "Install or reuse Neovim, prepare the isolated remote home, and sync selected local config.",
    timeline3Title: "Attach a local client",
    timeline3Body:
      "Forward the port and open `nvim --remote-ui` or your custom local client callback.",
    timeline4Title: "Inspect, detach, or reconnect",
    timeline4Body:
      "Use runtime diagnostics, clipboard checks, saved workspace records, and SSH detach/reattach when needed.",
    ctaEyebrow: "Implementation guide",
    ctaTitle: "The site now carries the detailed architecture docs.",
    ctaBody:
      "Use the docs section for implementation details, then drop to the README and vimdoc for installation steps and command reference.",
    ctaPrimary: "Open docs",
    ctaSecondary: "Read README",
    copySuccess: "Copied",
    docsNavHome: "Home",
    docsPageEyebrow: "Documentation",
    docsPageTitle: "Implementation notes, not just a landing page.",
    docsPageLead:
      "This section explains how the current Lua plugin is wired: command entrypoints, provider lifecycle, SSH transport, Devpod orchestration, session persistence, diagnostics UI, and remote install scripts.",
    docsHeroPrimary: "Open repository",
    docsHeroSecondary: "Open vimdoc",
    docsSidebarLabel: "Chapters",
    docsSidebarQuickLabel: "Quick references",
    docsMetaLabel: "Current chapter",
    docsLoading: "Loading chapter...",
    docsLoadError: "Failed to load this chapter.",
    docsIndexTitle: "Implementation chapters",
    docsIndexSummary:
      "Use this index as a system map. Each chapter tracks a real ownership boundary in the repo and points back to concrete Lua or shell files.",
  },
  "zh-CN": {
    brandTagline: "给 Neovim 的远程开发体验",
    navDocs: "文档",
    navGithub: "GitHub",
    navReadme: "README",
    navReadmeZh: "中文文档",
    eyebrow: "GitHub Pages 展示站",
    heroTitle: "把远程开发带进 Neovim，同时保住你的本地工作流。",
    heroLead:
      "在 SSH 主机、Docker 镜像、Docker 容器和 Devpod 工作区上启动并管理远程 Neovim 会话，再从本地 Neovim UI 驱动它们。",
    heroPrimaryCta: "打开仓库",
    heroDocsCta: "查看详细文档",
    heroSecondaryCta: "用 lazy.nvim 安装",
    statModes: "远程模式",
    statDocs: "实现章节",
    statClipboardValue: "OSC 52",
    statClipboard: "剪贴板桥接",
    terminalLine1: ":RemoteStart",
    terminalLine2: "Provider: SSH config",
    terminalLine3: "Workspace: backend-prod",
    terminalLine4: "远端服务已在 34681 端口就绪",
    terminalLine5: "本地 UI 已通过 --remote-ui 挂载",
    localLabel: "本地 Neovim",
    clipboardNode: "OSC 52 剪贴板",
    remoteLabel: "远端运行时",
    providerNode: "SSH / Docker / Devpod",
    serverNode: "Headless Neovim 服务",
    showcaseEyebrow: "真实工作流",
    showcaseTitle: "项目主页应该先把产品本身展示清楚。",
    showcaseLead:
      "首屏先解释插件做什么，下一屏直接展示它实际使用时是什么样子。",
    mediaMetaTutorial: "教程概览",
    mediaTitleTutorial: "安装之前，先看看插件真实跑起来的样子。",
    mediaBodyTutorial:
      "直接链接现有演示视频，让访客看到真实使用过程，而不是只读抽象描述。",
    watchDemo: "观看演示",
    installSnippetLabel: "安装片段",
    copyButton: "复制",
    featuresEyebrow: "能力地图",
    featuresTitle: "围绕真实远程编辑路径构建。",
    feature1Title: "连接入口",
    feature1Body:
      "支持 SSH 密码、SSH Key、SSH config、Docker 镜像、Docker 容器，以及基于 Devpod 的 devcontainer。",
    feature2Title: "远端启动准备",
    feature2Body:
      "自动在远端安装 Neovim，把运行目录隔离到插件管理空间，并同步你选择的本地配置目录。",
    feature3Title: "运行态诊断",
    feature3Body:
      "用 `:RemoteInfo` 查看运行信息，用 `:RemoteClipboardCheck` 排查剪贴板问题，需要时再看日志。",
    feature4Title: "会话生命周期",
    feature4Body:
      "支持保存工作区重连、离线 release 传输，以及带显式 reattach / cleanup 的 SSH detach 会话管理。",
    docsMapEyebrow: "架构文档",
    docsMapTitle: "按当前 Lua 代码边界拆开的详细章节。",
    docsMapLead:
      "文档区同时提供英文和中文镜像章节，覆盖 setup、provider、传输、持久化、UI 与离线安装流程。",
    docsCard1Meta: "第 1 章",
    docsCard1Title: "系统地图与入口层",
    docsCard1Body:
      "先看模块边界，再顺着 `setup()` 和 `:RemoteStart` 理解控制权如何流向 provider session。",
    docsCard2Meta: "第 3 章",
    docsCard2Title: "Provider 生命周期与持久化",
    docsCard2Body:
      "查看 session 如何在内存中缓存、哪些状态会落到 `workspace.json`，以及 reconnect 如何触发。",
    docsCard3Meta: "第 4 章",
    docsCard3Title: "SSH 传输与 Devpod 汇流",
    docsCard3Body:
      "拆开 rsync 与 tar 两条上传路径、交互提示处理、Host 解析，以及 Docker/devcontainer 最终如何落到 Devpod。",
    docsCard4Meta: "第 7 章",
    docsCard4Title: "UI、诊断与安装脚本",
    docsCard4Body:
      "跟进 progress viewer、clipboard diagnostics、health check、offline cache 扫描，以及远端安装脚本。",
    docsCardLink: "阅读章节",
    supportEyebrow: "支持矩阵",
    supportTitle: "项目能力边界，一眼看清。",
    tableHeadMode: "远程模式",
    tableHeadStatus: "当前支持情况",
    modeSshPassword: "SSH（密码）",
    modeSshKey: "SSH（SSH Key）",
    modeSshConfig: "SSH（`ssh_config`）",
    modeDockerImage: "Docker 镜像",
    modeDockerContainer: "Docker 容器",
    modeDevcontainer: "Devcontainer",
    supportFull: "完全支持",
    requirementsLabel: "本地要求",
    requirementsBody:
      "OpenSSH client、Neovim 0.9+、`curl`、`rsync`、可选 `tar`，以及在使用 devcontainer 工作流时需要的 `devpod`。",
    remoteReqLabel: "远端要求",
    remoteReqBody:
      "兼容 OpenSSH 的服务端、`bash`、`curl` 或 `wget`、`rsync`，以及在不启用离线模式时访问 Neovim release 的网络能力。",
    commandsLabel: "关键命令",
    commandsBody:
      "`:RemoteStart`、`:RemoteStop`、`:RemoteInfo`、`:RemoteCleanup`、`:RemoteClipboardCheck`、`:RemoteDetach`、`:RemoteReattach`。",
    timelineEyebrow: "流程",
    timelineTitle: "一次远程会话是怎样串起来的。",
    timeline1Title: "选择远程 provider",
    timeline1Body: "从 `:RemoteStart` 进入，选择 SSH、Docker、Docker container 或 Devpod。",
    timeline2Title: "准备远端运行时",
    timeline2Body: "安装或复用 Neovim，准备隔离的远端 home，并同步选定的本地配置。",
    timeline3Title: "挂载本地 client",
    timeline3Body: "建立端口转发，再打开 `nvim --remote-ui` 或你的自定义本地 client callback。",
    timeline4Title: "诊断、detach、重连",
    timeline4Body: "需要时查看运行诊断、排查剪贴板、复用保存的工作区记录，或处理 SSH detach / reattach。",
    ctaEyebrow: "实现指南",
    ctaTitle: "现在详细架构文档已经放进站点里了。",
    ctaBody:
      "实现细节看 docs，安装步骤和命令参考继续以 README 与 vimdoc 为准。",
    ctaPrimary: "打开文档",
    ctaSecondary: "查看 README",
    copySuccess: "已复制",
    docsNavHome: "首页",
    docsPageEyebrow: "文档",
    docsPageTitle: "这里放的是实现说明，不只是 landing page。",
    docsPageLead:
      "这一部分解释当前 Lua 插件是怎样接起来的：命令入口、provider 生命周期、SSH 传输、Devpod 编排、session 持久化、诊断 UI 以及远端安装脚本。",
    docsHeroPrimary: "打开仓库",
    docsHeroSecondary: "打开 vimdoc",
    docsSidebarLabel: "章节",
    docsSidebarQuickLabel: "快速参考",
    docsMetaLabel: "当前章节",
    docsLoading: "正在加载章节...",
    docsLoadError: "章节加载失败。",
    docsIndexTitle: "实现章节",
    docsIndexSummary:
      "把这个索引当成系统地图来看。每一章都对应仓库里真实的职责边界，并回指具体的 Lua 或 shell 文件。",
  },
};

const docsChapters = [
  {
    slug: "overview",
    title: {
      en: "Overview",
      "zh-CN": "总览",
    },
    summary: {
      en: "System map, ownership boundaries, and the repo files that matter before you dive into a specific provider path.",
      "zh-CN": "先建立系统地图、职责边界，以及进入具体 provider 流程前最值得看的仓库文件。",
    },
  },
  {
    slug: "entrypoint-commands",
    title: {
      en: "Entrypoint and commands",
      "zh-CN": "入口层与命令面",
    },
    summary: {
      en: "How `setup()`, default config, command registration, and the local client callback turn user intent into a session launch.",
      "zh-CN": "解释 `setup()`、默认配置、命令注册和本地 client callback 如何把用户操作变成一次 session 启动。",
    },
  },
  {
    slug: "provider-lifecycle",
    title: {
      en: "Provider lifecycle",
      "zh-CN": "Provider 生命周期",
    },
    summary: {
      en: "Session caching, workspace bootstrap, reconnect behavior, remote working directory selection, and the shared launch pipeline.",
      "zh-CN": "覆盖 session 缓存、workspace 初始化、reconnect 行为、远端 working directory 选择，以及共享启动流水线。",
    },
  },
  {
    slug: "ssh-transport",
    title: {
      en: "SSH transport and config parsing",
      "zh-CN": "SSH 传输与配置解析",
    },
    summary: {
      en: "The rsync and tar transfer paths, prompt handling, port forwarding, detached launch, and best-effort `ssh_config` parsing.",
      "zh-CN": "拆解 rsync 与 tar 传输路径、交互提示处理、端口转发、detach 启动，以及 best-effort 的 `ssh_config` 解析。",
    },
  },
  {
    slug: "devpod",
    title: {
      en: "Devpod and container workflows",
      "zh-CN": "Devpod 与容器工作流",
    },
    summary: {
      en: "Why Docker image, container, and devcontainer support land on Devpod, and what DevpodProvider adds on top of SSHProvider.",
      "zh-CN": "说明 Docker image、container 和 devcontainer 为什么都落到 Devpod，以及 DevpodProvider 在 SSHProvider 之上额外做了什么。",
    },
  },
  {
    slug: "persistence-detach",
    title: {
      en: "Persistence and detached sessions",
      "zh-CN": "持久化与 detach 会话",
    },
    summary: {
      en: "What is stored in `workspace.json` and `detached.json`, how host ids are reused, and how reattach validates remote state.",
      "zh-CN": "介绍 `workspace.json` 和 `detached.json` 各自保存什么，host id 如何复用，以及 reattach 如何校验远端状态。",
    },
  },
  {
    slug: "ui-diagnostics",
    title: {
      en: "UI and diagnostics",
      "zh-CN": "UI 与诊断",
    },
    summary: {
      en: "The NUI-based progress viewer, session panes, clipboard diagnostics, and health checks exposed to the user.",
      "zh-CN": "覆盖基于 NUI 的 progress viewer、session 面板、clipboard diagnostics，以及对用户暴露的 health checks。",
    },
  },
  {
    slug: "offline-install",
    title: {
      en: "Offline mode and install scripts",
      "zh-CN": "离线模式与安装脚本",
    },
    summary: {
      en: "How the offline cache is scanned, when local release download happens, and what the remote install scripts actually do.",
      "zh-CN": "说明离线缓存如何扫描、何时会在本地预下载 release，以及远端安装脚本实际完成哪些动作。",
    },
  },
];

const storageKey = "remote-nvim-site-language";
const buttonSelector = "[data-lang-button]";
const i18nSelector = "[data-i18n]";

function getDictionary(lang) {
  return translations[lang] || translations.en;
}

function getLanguage() {
  const saved = window.localStorage.getItem(storageKey);
  return saved && translations[saved] ? saved : "en";
}

function applyTranslations(lang) {
  const dictionary = getDictionary(lang);
  document.documentElement.lang = lang;

  document.querySelectorAll(i18nSelector).forEach((node) => {
    const key = node.dataset.i18n;
    if (!key || dictionary[key] === undefined) {
      return;
    }
    node.textContent = dictionary[key];
  });

  document.querySelectorAll(buttonSelector).forEach((button) => {
    const isActive = button.dataset.langButton === lang;
    button.classList.toggle("active", isActive);
    button.setAttribute("aria-pressed", isActive ? "true" : "false");
  });
}

function installLanguageToggle(onChange) {
  document.querySelectorAll(buttonSelector).forEach((button) => {
    button.addEventListener("click", () => {
      const lang = button.dataset.langButton;
      if (!translations[lang]) {
        return;
      }

      window.localStorage.setItem(storageKey, lang);
      applyTranslations(lang);
      if (typeof onChange === "function") {
        onChange(lang);
      }
    });
  });
}

function installCopyButton() {
  const copyButton = document.querySelector("[data-copy-target]");
  if (!copyButton) {
    return;
  }

  const defaultLabel = () => getDictionary(getLanguage()).copyButton;

  copyButton.addEventListener("click", async () => {
    const targetId = copyButton.dataset.copyTarget;
    const target = targetId ? document.getElementById(targetId) : null;
    if (!target) {
      return;
    }

    try {
      await navigator.clipboard.writeText(target.innerText);
      copyButton.textContent = getDictionary(getLanguage()).copySuccess;
      window.setTimeout(() => {
        copyButton.textContent = defaultLabel();
      }, 1400);
    } catch (error) {
      console.error("Failed to copy install snippet", error);
    }
  });
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function inlineMarkdown(text) {
  return text
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
}

function markdownToHtml(markdown) {
  const lines = markdown.replace(/\r\n/g, "\n").split("\n");
  const html = [];
  let inCodeBlock = false;
  let codeFence = "";
  let codeLines = [];
  let inList = false;
  let paragraphLines = [];

  function flushParagraph() {
    if (!paragraphLines.length) {
      return;
    }
    html.push(`<p>${inlineMarkdown(paragraphLines.join(" "))}</p>`);
    paragraphLines = [];
  }

  function flushList() {
    if (inList) {
      html.push("</ul>");
      inList = false;
    }
  }

  function flushCode() {
    if (!inCodeBlock) {
      return;
    }
    const languageClass = codeFence ? ` class="language-${codeFence}"` : "";
    html.push(`<pre><code${languageClass}>${escapeHtml(codeLines.join("\n"))}</code></pre>`);
    inCodeBlock = false;
    codeFence = "";
    codeLines = [];
  }

  for (const line of lines) {
    const codeMatch = line.match(/^```(.*)$/);
    if (codeMatch) {
      if (inCodeBlock) {
        flushCode();
      } else {
        flushParagraph();
        flushList();
        inCodeBlock = true;
        codeFence = codeMatch[1].trim();
      }
      continue;
    }

    if (inCodeBlock) {
      codeLines.push(line);
      continue;
    }

    if (/^\s*$/.test(line)) {
      flushParagraph();
      flushList();
      continue;
    }

    const headingMatch = line.match(/^(#{1,3})\s+(.*)$/);
    if (headingMatch) {
      flushParagraph();
      flushList();
      const level = Math.min(headingMatch[1].length + 1, 4);
      html.push(`<h${level}>${inlineMarkdown(headingMatch[2])}</h${level}>`);
      continue;
    }

    const listMatch = line.match(/^- (.*)$/);
    if (listMatch) {
      flushParagraph();
      if (!inList) {
        html.push("<ul>");
        inList = true;
      }
      html.push(`<li>${inlineMarkdown(listMatch[1])}</li>`);
      continue;
    }

    paragraphLines.push(line.trim());
  }

  flushParagraph();
  flushList();
  flushCode();

  return html.join("\n");
}

function getBasePrefix() {
  return document.documentElement.dataset.basePrefix || ".";
}

function joinBase(path) {
  return `${getBasePrefix()}/${path}`.replace(/\/{2,}/g, "/");
}

function chapterBySlug(slug) {
  return docsChapters.find((chapter) => chapter.slug === slug) || docsChapters[0];
}

function currentSlug() {
  return window.location.hash.replace(/^#/, "") || docsChapters[0].slug;
}

function renderDocsNav(lang, activeSlug) {
  const container = document.getElementById("docs-nav");
  if (!container) {
    return;
  }

  container.innerHTML = docsChapters
    .map((chapter) => {
      const active = chapter.slug === activeSlug ? " active" : "";
      const title = chapter.title[lang] || chapter.title.en;
      return `<a class="docs-nav-link${active}" href="#${chapter.slug}"><span>${title}</span></a>`;
    })
    .join("");
}

async function renderDocsChapter(lang) {
  const contentNode = document.getElementById("docs-content");
  const titleNode = document.getElementById("docs-title");
  const summaryNode = document.getElementById("docs-summary");
  if (!contentNode || !titleNode || !summaryNode) {
    return;
  }

  const slug = currentSlug();
  const chapter = chapterBySlug(slug);
  const dictionary = getDictionary(lang);
  renderDocsNav(lang, chapter.slug);

  titleNode.textContent = chapter.title[lang] || chapter.title.en;
  summaryNode.textContent = chapter.summary[lang] || chapter.summary.en;
  document.title = `remote-nvim.nvim Docs - ${chapter.title[lang] || chapter.title.en}`;
  contentNode.innerHTML = `<p>${dictionary.docsLoading}</p>`;

  const localePath = lang === "zh-CN" ? "zh-CN" : "en";
  const markdownPath = joinBase(`content/docs/${localePath}/${chapter.slug}.md`);

  try {
    const response = await window.fetch(markdownPath, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to fetch ${markdownPath}: ${response.status}`);
    }
    const markdown = await response.text();
    contentNode.innerHTML = markdownToHtml(markdown);
  } catch (error) {
    console.error(error);
    contentNode.innerHTML = `<p>${dictionary.docsLoadError}</p>`;
  }
}

function installDocsPage() {
  const initialLang = getLanguage();
  applyTranslations(initialLang);
  renderDocsNav(initialLang, currentSlug());
  renderDocsChapter(initialLang);
  installLanguageToggle((lang) => {
    renderDocsChapter(lang);
  });
  window.addEventListener("hashchange", () => {
    renderDocsChapter(getLanguage());
  });
}

function installHomePage() {
  applyTranslations(getLanguage());
  installLanguageToggle();
  installCopyButton();
}

if (document.body.dataset.page === "docs") {
  installDocsPage();
} else {
  installHomePage();
}
