#!/usr/bin/env bash
# install.sh —— personal-systemconfig 跨平台安装入口（macOS / Linux）
#
# 两种用法：
#   1) 克隆后本地运行： git clone <repo> && cd personal-systemconfig && ./install.sh
#   2) 一行远程引导：    bash -c "$(curl -fsSL https://raw.githubusercontent.com/Xeonice/personal-systemconfig/master/install.sh)"
#      （远程模式下会自动把仓库克隆到 ~/.personal-systemconfig 再执行）
#
set -euo pipefail

REPO_URL="https://github.com/Xeonice/personal-systemconfig.git"
REPO_HOME="$HOME/.personal-systemconfig"

# ---------------------------------------------------------------------------
# 定位脚本所在目录；若是被 curl 管道执行（无本地文件），先克隆仓库再 re-exec
# ---------------------------------------------------------------------------
# 直接给全局 REPO_DIR 赋值，避免用命令替换捕获——否则 git pull/clone 的 stdout
# 会被拼进路径，导致重复远程引导时 exec 一个不存在的路径而失败。
REPO_DIR=""
resolve_repo_dir() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" && -f "$src" ]]; then
    # 本地运行：解析真实目录
    REPO_DIR="$(cd "$(dirname "$src")" && pwd)"
    return 0
  fi
  # 远程管道运行：克隆 / 更新到 REPO_HOME 后由调用方 re-exec
  if [[ -d "$REPO_HOME/.git" ]]; then
    if ! git -C "$REPO_HOME" pull --ff-only; then
      echo "⚠ 仓库更新失败（非快进/有本地改动），将使用 $REPO_HOME 中已有的缓存版本继续。" >&2
      echo "  如需最新版：删除 $REPO_HOME 后重试。" >&2
    fi
  else
    command -v git >/dev/null 2>&1 || {
      echo "需要 git 才能引导安装，请先安装 git。" >&2; exit 1; }
    git clone "$REPO_URL" "$REPO_HOME"
  fi
  REPO_DIR="$REPO_HOME"
}

resolve_repo_dir

# 远程引导：当前不是从仓库内运行，则切换到克隆出的脚本继续
if [[ -z "${BASH_SOURCE[0]:-}" || ! -f "${BASH_SOURCE[0]:-}" ]]; then
  exec bash "$REPO_DIR/install.sh" "$@"
fi

# ---------------------------------------------------------------------------
# 载入函数库
# ---------------------------------------------------------------------------
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"
# shellcheck source=lib/components.sh
source "$REPO_DIR/lib/components.sh"

OS="$(detect_os)"

log "personal-systemconfig 安装器"
info "系统：$OS / 架构：$(detect_arch)"
info "仓库：$REPO_DIR"
echo

# ---------------------------------------------------------------------------
# 平台分发
# ---------------------------------------------------------------------------
case "$OS" in
  macos)
    # shellcheck source=os/macos.sh
    source "$REPO_DIR/os/macos.sh"
    run_macos
    ;;
  linux)
    # shellcheck source=os/linux.sh
    source "$REPO_DIR/os/linux.sh"
    run_linux
    ;;
  *)
    die "暂不支持的系统：$(uname -s)"
    ;;
esac

# ---------------------------------------------------------------------------
# 通用收尾：部署 .zshrc + 切换默认 shell
# ---------------------------------------------------------------------------
echo
log "部署 shell 配置"
deploy_file "$REPO_DIR/shell/zshrc" "$HOME/.zshrc"
deploy_file "$REPO_DIR/shell/p10k.zsh" "$HOME/.p10k.zsh"
info "首次启动 zsh 时，zinit 会自动克隆并安装所有插件（含 powerlevel10k 主题）"

ensure_default_zsh

echo
ok "全部完成！请重新打开终端（或执行 'exec zsh'）以加载新配置。"
if [[ "$OS" == macos ]]; then
  info "Mac 提示：记得在系统设置里给 Hammerspoon 授予「辅助功能」权限。"
fi
