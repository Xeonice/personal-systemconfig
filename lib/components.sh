#!/usr/bin/env bash
# lib/components.sh —— 跨平台共用组件安装逻辑
# 这些组件在 linux / macos 上安装方式基本一致，集中在此，避免两份脚本重复。
# 依赖 lib/common.sh 已被 source。

KITTY_CONFIG_REPO="https://github.com/Xeonice/kitty-config.git"
KITTY_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"

# ---------------------------------------------------------------------------
# fnm —— 取代 nvm 的 Node 版本管理器
#   macOS 走 brew；其它平台走官方安装脚本（--skip-shell，shell 集成由 .zshrc 负责）
# ---------------------------------------------------------------------------
install_fnm() {
  if has fnm; then ok "fnm 已安装：$(fnm --version 2>/dev/null)"; return 0; fi
  # 之前装过但当前 shell 未把它加进 PATH（未 source 新 .zshrc）：直接复用，避免重复下载
  if [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
    ok "fnm 已安装：$(fnm --version 2>/dev/null)"
    return 0
  fi
  log "安装 fnm（替代 nvm）"
  if [[ "$(detect_os)" == macos ]] && has brew; then
    brew install fnm
  else
    # 官方安装脚本，装到 ~/.local/share/fnm；--skip-shell 避免它改写 .zshrc
    # 加 || 守卫：失败时仅告警，不让 set -euo pipefail 中断整个安装器
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell --install-dir "$HOME/.local/share/fnm" \
      || { warn "fnm 安装脚本失败，跳过（可稍后手动：curl -fsSL https://fnm.vercel.app/install | bash）"; return 0; }
    export PATH="$HOME/.local/share/fnm:$PATH"
  fi
  if has fnm; then ok "fnm 安装完成"; else warn "fnm 安装后未在 PATH 中，可能需重开终端"; fi
}

# 安装 Node LTS（需 fnm 已在 PATH）
install_node_lts() {
  if ! has fnm; then warn "fnm 不可用，跳过 Node 安装"; return 0; fi
  log "用 fnm 安装 Node LTS"
  eval "$(fnm env)" 2>/dev/null || true
  if fnm list 2>/dev/null | grep -q 'lts'; then
    ok "已存在 LTS Node"
  else
    fnm install --lts || warn "Node LTS 安装失败，可稍后手动：fnm install --lts"
  fi
  fnm default lts-latest 2>/dev/null || fnm default "$(fnm list 2>/dev/null | grep -o 'v[0-9.]*' | tail -1)" 2>/dev/null || true
  eval "$(fnm env)" 2>/dev/null || true
  if has node; then ok "Node 就绪：$(node -v 2>/dev/null)"; else warn "Node 暂不可用，重开终端后由 .zshrc 加载"; fi
}

# ---------------------------------------------------------------------------
# powerline-go —— Go 实现的 powerline 提示符（个人配置的标准组件）
#   macOS 走 brew；Linux 取 GitHub release 预编译二进制 → ~/.local/bin
#   注意：powerline 字形依赖 Nerd 字体（由各平台安装流程负责安装）
# ---------------------------------------------------------------------------
install_powerline_go() {
  if has powerline-go || [[ -x "$HOME/.local/bin/powerline-go" ]]; then
    ok "powerline-go 已安装"
    return 0
  fi
  log "安装 powerline-go"
  if [[ "$(detect_os)" == macos ]] && has brew; then
    brew install powerline-go || warn "powerline-go 安装失败，可稍后手动：brew install powerline-go"
    return 0
  fi
  local arch_tok
  case "$(detect_arch)" in
    x86_64) arch_tok=amd64 ;;
    arm64)  arch_tok=arm64 ;;
    *) warn "powerline-go 无对应架构预编译包（$(detect_arch)），跳过"; return 0 ;;
  esac
  local url="https://github.com/justjanne/powerline-go/releases/latest/download/powerline-go-linux-${arch_tok}"
  mkdir -p "$HOME/.local/bin"
  if download "$url" "$HOME/.local/bin/powerline-go"; then
    chmod +x "$HOME/.local/bin/powerline-go"
    ok "powerline-go 安装完成：$HOME/.local/bin/powerline-go"
  else
    warn "powerline-go 下载失败，可稍后手动安装：https://github.com/justjanne/powerline-go/releases"
  fi
}

# ---------------------------------------------------------------------------
# Claude Code —— 官方原生安装器（macOS / Linux 通用）
# ---------------------------------------------------------------------------
install_claude_code() {
  # claude 装在 ~/.local/bin，非登录 shell 的 PATH 可能没有，先补上避免误判重装
  [[ -x "$HOME/.local/bin/claude" ]] && export PATH="$HOME/.local/bin:$PATH"
  if has claude; then ok "Claude Code 已安装：$(claude --version 2>/dev/null | head -1)"; return 0; fi
  log "安装 Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash \
    || warn "Claude Code 安装失败，可稍后手动：curl -fsSL https://claude.ai/install.sh | bash"
}

# ---------------------------------------------------------------------------
# kitty 配置 —— clone Xeonice/kitty-config 到 ~/.config/kitty
# ---------------------------------------------------------------------------
install_kitty_config() {
  log "部署 kitty 配置（$KITTY_CONFIG_REPO）"
  local origin=""
  if [[ -d "$KITTY_CONFIG_DIR/.git" ]]; then
    origin="$(git -C "$KITTY_CONFIG_DIR" remote get-url origin 2>/dev/null || true)"
  fi
  # 仅当现有仓库的 origin 确实指向 Xeonice/kitty-config 才 pull；
  # 否则视为外来/无关仓库，备份后重新克隆，保证自愈（http/ssh 形式均匹配，排除同名他人仓库）
  if [[ "$origin" == *Xeonice/kitty-config* ]]; then
    info "已是 kitty-config 仓库，执行 git pull"
    git -C "$KITTY_CONFIG_DIR" pull --ff-only || warn "kitty-config 更新失败，保留现有配置"
  else
    [[ -d "$KITTY_CONFIG_DIR/.git" ]] && warn "现有 $KITTY_CONFIG_DIR 不是 kitty-config 仓库，备份后重新克隆"
    backup_path "$KITTY_CONFIG_DIR"
    git clone --depth 1 "$KITTY_CONFIG_REPO" "$KITTY_CONFIG_DIR" \
      || { warn "克隆 kitty-config 失败"; return 0; }
  fi
  ok "kitty 配置就绪：$KITTY_CONFIG_DIR"
}
