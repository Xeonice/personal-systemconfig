#!/usr/bin/env bash
# os/linux.sh —— Linux 平台安装流程（apt / Debian·Ubuntu 系）
# 依赖 lib/common.sh、lib/components.sh 已被 source。
# 说明：brew 不在 Linux 安装，统一用 apt + 官方安装器/release 包。

# 当前是否为 apt 系
_has_apt() { has apt-get; }

# apt 幂等安装
apt_install() {
  as_root apt-get install -y "$@"
}

# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
install_base_linux() {
  if ! _has_apt; then
    warn "未检测到 apt-get；本脚本目前仅支持 Debian/Ubuntu 系。请手动安装：zsh git wget curl"
    return 0
  fi
  log "apt 更新并安装基础工具"
  as_root apt-get update -y
  apt_install zsh git wget curl ca-certificates gnupg
  # kitty 配置（warp-style.conf）依赖 JetBrains Mono；老发行版无此包时仅告警
  apt_install fonts-jetbrains-mono \
    || warn "fonts-jetbrains-mono 安装失败（发行版可能无此包），kitty 将回退默认等宽字体"
}

# ---------------------------------------------------------------------------
# JetBrains Mono Nerd Font —— powerline-go / p10k 的 powerline 与图标字形依赖
#   apt 无 Nerd 字体包，从 nerd-fonts 官方 release 取 tar.xz 装到 ~/.local/share/fonts
# ---------------------------------------------------------------------------
install_nerd_font_linux() {
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
  if compgen -G "$font_dir/*.ttf" >/dev/null 2>&1; then
    ok "JetBrains Mono Nerd Font 已安装"
    return 0
  fi
  log "安装 JetBrains Mono Nerd Font（nerd-fonts release）"
  local tarball
  tarball="$(mktemp /tmp/jbmono-nerd.XXXXXX.tar.xz)"
  if download "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" "$tarball"; then
    mkdir -p "$font_dir"
    if tar -xJf "$tarball" -C "$font_dir" 2>/dev/null; then
      has fc-cache && fc-cache -f "$font_dir" >/dev/null 2>&1
      ok "Nerd Font 安装完成：$font_dir"
    else
      warn "Nerd Font 解压失败（需要 xz 支持），跳过"
    fi
    rm -f "$tarball"
  else
    warn "Nerd Font 下载失败，可稍后手动：https://www.nerdfonts.com/font-downloads"
  fi
}

# ---------------------------------------------------------------------------
# kitty —— 官方安装器装到 ~/.local（apt 版本通常过旧）
# ---------------------------------------------------------------------------
install_kitty_linux() {
  if has kitty; then ok "kitty 已安装：$(kitty --version 2>/dev/null)"; return 0; fi
  log "安装 kitty（官方安装器 → ~/.local/kitty.app）"
  curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin \
    launch=n || { warn "kitty 安装失败"; return 0; }
  # 创建可执行软链接与桌面集成
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
  # 桌面图标（可选，失败不致命）
  if [[ -d "$HOME/.local/kitty.app/share/applications" ]]; then
    mkdir -p "$HOME/.local/share/applications"
    cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" \
       "$HOME/.local/share/applications/" 2>/dev/null || true
    sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
       "$HOME/.local/share/applications/kitty.desktop" 2>/dev/null || true
    sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" \
       "$HOME/.local/share/applications/kitty.desktop" 2>/dev/null || true
  fi
  ok "kitty 安装完成"
}

# ---------------------------------------------------------------------------
# Google Chrome —— 官方 .deb
# ---------------------------------------------------------------------------
install_chrome_linux() {
  if has google-chrome || has google-chrome-stable; then
    ok "Google Chrome 已安装"; return 0
  fi
  if [[ "$(detect_arch)" != x86_64 ]]; then
    warn "Google Chrome 官方仅提供 x86_64 .deb，当前架构 $(detect_arch)，跳过"
    return 0
  fi
  log "安装 Google Chrome（官方 .deb）"
  local deb; deb="$(mktemp /tmp/chrome.XXXXXX.deb)"
  if download "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" "$deb"; then
    as_root apt-get install -y "$deb" || warn "Chrome 安装失败"
    rm -f "$deb"
  else
    warn "Chrome 下载失败，跳过"
  fi
}

# ---------------------------------------------------------------------------
# SwitchHosts —— 从 GitHub release 取 linux deb
# ---------------------------------------------------------------------------
install_switchhosts_linux() {
  if has switchhosts || has SwitchHosts; then ok "SwitchHosts 已安装"; return 0; fi
  log "安装 SwitchHosts（GitHub release .deb）"
  # release 同时提供 linux-amd64.deb 和 linux-arm64.deb，必须按本机架构选取，
  # 否则在 arm64 上装到 amd64 包会被 dpkg 以架构不匹配拒绝
  local arch_tok
  case "$(detect_arch)" in
    x86_64) arch_tok=amd64 ;;
    arm64)  arch_tok=arm64 ;;
    *) warn "SwitchHosts 无对应架构 .deb（$(detect_arch)），跳过"; return 0 ;;
  esac
  local api="https://api.github.com/repos/oldj/SwitchHosts/releases/latest"
  local url
  url="$(curl -fsSL "$api" 2>/dev/null \
        | grep -o "\"browser_download_url\": *\"[^\"]*linux-${arch_tok}\\.deb\"" \
        | head -1 | sed 's/.*"browser_download_url": *"//;s/"$//')"
  if [[ -z "$url" ]]; then
    warn "未能从 GitHub 获取 SwitchHosts ${arch_tok} .deb 链接，请手动到 https://github.com/oldj/SwitchHosts/releases 下载"
    return 0
  fi
  local deb; deb="$(mktemp /tmp/switchhosts.XXXXXX.deb)"
  if download "$url" "$deb"; then
    as_root apt-get install -y "$deb" || warn "SwitchHosts 安装失败"
    rm -f "$deb"
  else
    warn "SwitchHosts 下载失败，跳过"
  fi
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
run_linux() {
  log "===== Linux 安装流程开始 ====="

  install_base_linux        # zsh git wget curl + JetBrains Mono（两边都装）
  install_nerd_font_linux   # Nerd 字体（powerline-go / p10k 字形依赖）
  install_fnm               # fnm（两边都装）

  install_kitty_linux       # kitty（两边都装）
  install_chrome_linux      # chrome（两边都装）
  install_switchhosts_linux # switchhosts（两边都装）
  # 注意：hammerspoon / brew 仅 macOS，不在此安装

  install_node_lts
  install_powerline_go
  install_claude_code
  install_kitty_config

  log "===== Linux 安装流程结束 ====="
}
