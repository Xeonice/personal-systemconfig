#!/usr/bin/env bash
# os/macos.sh —— macOS 平台安装流程
# 依赖 lib/common.sh、lib/components.sh 已被 source。

# ---------------------------------------------------------------------------
# Homebrew —— macOS 的包管理器（仅 Mac 安装；Linux 用 apt）
# ---------------------------------------------------------------------------
# 把 brew 注入当前 shell 环境（Apple Silicon 在 /opt/homebrew，Intel 在 /usr/local）
brew_shellenv() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  # 先注入再检测：非登录 shell（ssh/管道）的 PATH 往往没有 brew，
  # 否则已安装也会被误判而重跑整个 Homebrew 安装器
  brew_shellenv
  if has brew; then
    ok "Homebrew 已安装：$(brew --version | head -1)"
  else
    log "安装 Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew 安装失败"
    brew_shellenv
  fi
}

# brew formula 幂等安装
brew_install() {
  local pkg="$1"
  if brew list --formula 2>/dev/null | grep -qx "$pkg"; then
    ok "$pkg 已安装"
  else
    log "brew install $pkg"; brew install "$pkg"
  fi
}

# brew cask 幂等安装；若同名 App 已存在于 /Applications 则跳过
brew_cask() {
  local cask="$1" app="$2"
  if brew list --cask 2>/dev/null | grep -qx "$cask"; then
    ok "$cask 已安装（brew cask）"; return 0
  fi
  if [[ -n "$app" && -d "/Applications/$app" ]]; then
    ok "$app 已存在于 /Applications，跳过 $cask"; return 0
  fi
  log "brew install --cask $cask"; brew install --cask "$cask"
}

# ---------------------------------------------------------------------------
# Hammerspoon 配置 —— 用 kitty-config 仓库里现成的 hammerspoon-init.lua（Option + /）
# ---------------------------------------------------------------------------
install_hammerspoon_config() {
  local src="$KITTY_CONFIG_DIR/hammerspoon-init.lua"
  if [[ ! -f "$src" ]]; then
    warn "未找到 ${src}（kitty-config 可能未克隆成功），跳过 Hammerspoon 配置"
    return 0
  fi
  deploy_file "$src" "$HOME/.hammerspoon/init.lua"
  info "Hammerspoon 配置：Option + / 全局唤起 kitty"
  warn "首次使用需在「系统设置 → 隐私与安全性 → 辅助功能」中授权 Hammerspoon"
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
run_macos() {
  log "===== macOS 安装流程开始 ====="

  # 本地克隆运行路径下也确保 CLT（远程引导路径已在 install.sh 中处理，幂等）
  ensure_xcode_clt

  install_homebrew

  # 基础工具（两边都装）
  brew_install zsh
  brew_install git
  brew_install wget
  brew_install fnm

  # 字体依赖（全新机器没有会回退 Menlo / 图标显示为方块）：
  #   - font-jetbrains-mono：kitty warp-style.conf 引用的 "JetBrains Mono" 字族
  #   - font-jetbrains-mono-nerd-font：powerline-go / p10k 的 powerline 与图标字形
  brew_cask font-jetbrains-mono ""
  brew_cask font-jetbrains-mono-nerd-font ""

  # ---- 可选软件：先一次性问完，再统一安装，中途不打断 ----
  # 检测式尽量贴近"用户眼里装没装"：看 App 是否在 /Applications，
  # 纯 CLI 的看命令能否找到（此时 brew_shellenv 已注入过 PATH）。
  # 不查 brew cask 列表，这样手动装的 App 同样会被认作已安装。
  optional_reset
  optional_add kitty       "kitty 终端"        '[[ -d /Applications/kitty.app ]]'
  optional_add chrome      "Google Chrome"     '[[ -d "/Applications/Google Chrome.app" ]]'
  optional_add switchhosts "SwitchHosts"       '[[ -d /Applications/SwitchHosts.app ]]'
  optional_add hammerspoon "Hammerspoon"       '[[ -d /Applications/Hammerspoon.app ]]'
  optional_add raycast     "Raycast"           '[[ -d /Applications/Raycast.app ]]'
  optional_add onepassword "1Password"         '[[ -d /Applications/1Password.app ]]'
  # tailscale 在 macOS 上有两种装法：cask 的 GUI App，或 formula 的纯 CLI。
  # 任一存在即视作已装，避免给已经用 formula 版的机器重复装一个 App。
  optional_add tailscale   "Tailscale"         '[[ -d /Applications/Tailscale.app ]] || has tailscale'
  # codex cask 交付的是 bin/codex 二进制，不是 .app，只能查命令
  optional_add codex       "Codex CLI"         'has codex'
  optional_select

  optional_run kitty       brew_cask kitty          "kitty.app"
  optional_run chrome      brew_cask google-chrome  "Google Chrome.app"
  optional_run switchhosts brew_cask switchhosts    "SwitchHosts.app"
  optional_run hammerspoon brew_cask hammerspoon    "Hammerspoon.app"
  optional_run raycast     brew_cask raycast        "Raycast.app"
  optional_run onepassword brew_cask 1password      "1Password.app"
  # cask 名是 tailscale-app；tailscale 只是它的旧别名
  optional_run tailscale   brew_cask tailscale-app  "Tailscale.app"
  optional_run codex       brew_cask codex          ""

  # 共用组件
  install_node_lts
  install_powerline_go
  install_claude_code
  install_kitty_config

  # 依赖 kitty-config 已克隆。用 is_active 而非 is_selected：
  # 早就装了 Hammerspoon 的机器不会出现在选单里，配置照样要铺。
  if optional_is_active hammerspoon; then
    install_hammerspoon_config
  else
    info "未安装 Hammerspoon，跳过其配置部署"
  fi

  log "===== macOS 安装流程结束 ====="
}
