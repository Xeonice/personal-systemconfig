# personal-systemconfig

跨平台（macOS / Linux）个人系统初始化配置。一条命令把新机器装成顺手的开发环境。

## 快速开始

```bash
# 方式一：克隆后运行
git clone https://github.com/Xeonice/personal-systemconfig.git
cd personal-systemconfig
./install.sh

# 方式二：一行远程引导（会自动克隆到 ~/.personal-systemconfig）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Xeonice/personal-systemconfig/master/install.sh)"
```

安装器会自动识别系统（`uname`），执行对应分支，最后部署 `.zshrc` 并把默认 shell 切到 zsh。

## 安装内容

| 组件 | Linux | macOS | 安装方式 |
|------|:----:|:----:|------|
| zsh / git / wget / curl | ✅ | ✅ | Linux: apt ・ macOS: brew |
| **zinit**（插件管理，取代 oh-my-zsh） | ✅ | ✅ | 由 `.zshrc` 首次启动时自动克隆 |
| **fnm**（Node 版本管理，取代 nvm） | ✅ | ✅ | Linux: 官方脚本 ・ macOS: brew |
| Node LTS | ✅ | ✅ | `fnm install --lts` |
| kitty | ✅ | ✅ | Linux: 官方安装器 ・ macOS: brew cask |
| kitty 配置 | ✅ | ✅ | clone [Xeonice/kitty-config](https://github.com/Xeonice/kitty-config) → `~/.config/kitty` |
| Google Chrome | ✅ | ✅ | Linux: 官方 .deb ・ macOS: brew cask |
| Claude Code | ✅ | ✅ | `curl -fsSL https://claude.ai/install.sh \| bash` |
| SwitchHosts | ✅ | ✅ | Linux: GitHub release .deb ・ macOS: brew cask |
| **Homebrew** | ❌ | ✅ | macOS 包管理器（Linux 用 apt） |
| **Hammerspoon** | ❌ | ✅ | brew cask；配置取自 kitty-config（Option + / 唤起 kitty） |

> 「两边都有的装两边，仅某平台有的只装那边」：Homebrew、Hammerspoon 为 macOS 专属，其余跨平台组件两个分支都装。

## 仓库结构

```
personal-systemconfig/
├── install.sh          # 入口：识别系统 → 分发 → 部署 .zshrc → 切默认 shell
├── lib/
│   ├── common.sh       # 日志、系统/架构探测、备份、下载等公共函数
│   └── components.sh   # 跨平台共用组件：fnm / node / claude code / kitty 配置
├── os/
│   ├── macos.sh        # macOS 流程（brew + cask + hammerspoon）
│   └── linux.sh        # Linux 流程（apt + 官方安装器 / release 包）
├── shell/
│   ├── zshrc           # 新版 .zshrc（zinit + powerlevel10k + fnm），部署为 ~/.zshrc
│   └── p10k.zsh        # powerlevel10k 外观配置，部署为 ~/.p10k.zsh
├── test.sh             # 旧入口的兼容 shim，转交 install.sh
└── README.md
```

## 设计要点

- **幂等**：所有步骤先检测再安装，可重复运行。
- **跨平台**：`.zshrc` 同一份兼容 macOS / Linux，自动处理 Homebrew shellenv、fnm 路径。
- **非交互**：Homebrew 安装走 `NONINTERACTIVE=1`，适合自动化。
- **安全备份**：部署 `~/.zshrc`、`~/.hammerspoon/init.lua` 等前会自动备份旧文件为 `*.bak`。

## 备注

- macOS 上 Hammerspoon 首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中手动授权。
- Linux 目前仅适配 Debian / Ubuntu（apt）系；其它发行版会跳过 apt 步骤并给出提示。
- Google Chrome 官方 .deb 仅提供 x86_64，ARM Linux 会自动跳过。
