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

### 必装（骨架，不询问）

| 组件 | Linux | macOS | 安装方式 |
|------|:----:|:----:|------|
| zsh / git / wget / curl | ✅ | ✅ | Linux: apt ・ macOS: brew |
| **zinit**（插件管理，取代 oh-my-zsh） | ✅ | ✅ | 由 `.zshrc` 首次启动时自动克隆 |
| **fnm**（Node 版本管理，取代 nvm） | ✅ | ✅ | Linux: 官方脚本 ・ macOS: brew |
| Node LTS | ✅ | ✅ | `fnm install --lts` |
| JetBrains Mono / Nerd Font | ✅ | ✅ | Linux: apt + nerd-fonts release ・ macOS: brew cask |
| kitty 配置 | ✅ | ✅ | clone [Xeonice/kitty-config](https://github.com/Xeonice/kitty-config) → `~/.config/kitty` |
| Claude Code | ✅ | ✅ | `curl -fsSL https://claude.ai/install.sh \| bash` |
| **Homebrew** | ❌ | ✅ | macOS 包管理器（Linux 用 apt） |

### 可选（安装前交互勾选）

已经装过的不会出现在选单里，直接跳过；一次问完，之后不再打断。

| 组件 | Linux | macOS | 安装方式 |
|------|:----:|:----:|------|
| kitty | ✅ | ✅ | Linux: 官方安装器 ・ macOS: brew cask |
| Google Chrome | ✅ | ✅ | Linux: 官方 .deb ・ macOS: brew cask |
| SwitchHosts | ✅ | ✅ | Linux: GitHub release .deb ・ macOS: brew cask |
| **1Password** | ✅ | ✅ | Linux: 官方 .deb（仅 amd64）・ macOS: brew cask |
| **Tailscale** | ✅ | ✅ | Linux: 官方 install.sh ・ macOS: brew cask `tailscale-app` |
| **Codex CLI** | ✅ | ✅ | Linux: GitHub release musl 二进制 ・ macOS: brew cask |
| **Hammerspoon** | ❌ | ✅ | brew cask；配置取自 kitty-config（Option + / 唤起 kitty） |
| **Raycast** | ❌ | ✅ | brew cask（macOS 专有，无 Linux 版） |

> 「两边都有的装两边，仅某平台有的只装那边」：Homebrew、Hammerspoon、Raycast 为 macOS 专属，其余跨平台组件两个分支都装。

选单交互：

```
==> 可选软件（3 项未安装）
     1) SwitchHosts
     2) Raycast
     3) Tailscale
    回车=全装，n=都不装，或输入编号（如 1 3 5 或 1,3,5）
    请选择>
```

无 tty（CI / 无人值守）时不阻塞，默认全部安装，行为与引入选单之前一致。

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
- **非交互**：Homebrew 安装走 `NONINTERACTIVE=1`，适合自动化；可选软件选单在无 tty 时自动全选，不会卡住。
- **先问后装**：所有询问集中在安装动作之前一次问完，装的过程中不再打断。
- **安全备份**：部署 `~/.zshrc`、`~/.hammerspoon/init.lua` 等前会自动备份旧文件为 `*.bak`。

## 备注

- macOS 上 Hammerspoon 首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中手动授权。
- Linux 目前仅适配 Debian / Ubuntu（apt）系；其它发行版会跳过 apt 步骤并给出提示。
- Google Chrome 官方 .deb 仅提供 x86_64，ARM Linux 会自动跳过。
- 1Password Linux 桌面版官方仅提供 amd64，ARM Linux 会自动跳过。
- Raycast 为 macOS 专有，Linux 分支不提供，也不会出现在选单中。
- macOS 上 Tailscale 装的是 cask `tailscale-app`（GUI）；若机器上已有 formula 版的 `tailscale` CLI，会被认作已安装而跳过。
