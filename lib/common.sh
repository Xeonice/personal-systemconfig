#!/usr/bin/env bash
# lib/common.sh —— 跨平台公共函数库（被 install.sh / os/*.sh source）
# 约定：所有脚本均以 bash 运行；这里不设 set -e，由入口 install.sh 统一控制。

# ---------------------------------------------------------------------------
# 颜色与日志
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_BLUE=$'\033[34m'; _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'; _C_RED=$'\033[31m'; _C_BOLD=$'\033[1m'
else
  _C_RESET=''; _C_BLUE=''; _C_GREEN=''; _C_YELLOW=''; _C_RED=''; _C_BOLD=''
fi

log()   { printf '%s\n' "${_C_BLUE}==>${_C_RESET} ${_C_BOLD}$*${_C_RESET}"; }
info()  { printf '%s\n' "    $*"; }
ok()    { printf '%s\n' "${_C_GREEN}  ✔${_C_RESET} $*"; }
warn()  { printf '%s\n' "${_C_YELLOW}  ⚠${_C_RESET} $*" >&2; }
error() { printf '%s\n' "${_C_RED}  ✗${_C_RESET} $*" >&2; }
die()   { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# 探测与工具函数
# ---------------------------------------------------------------------------
# 命令是否存在
has() { command -v "$1" >/dev/null 2>&1; }

# 操作系统：返回 macos / linux / unknown
detect_os() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)  echo linux ;;
    *)      echo unknown ;;
  esac
}

# CPU 架构：arm64 / x86_64 / ...
detect_arch() {
  local m; m="$(uname -m)"
  case "$m" in
    arm64|aarch64) echo arm64 ;;
    x86_64|amd64)  echo x86_64 ;;
    *)             echo "$m" ;;
  esac
}

# 是否为 Apple Silicon
is_apple_silicon() { [[ "$(detect_os)" == macos && "$(detect_arch)" == arm64 ]]; }

# sudo 包装：root 时直接执行，否则用 sudo（无 sudo 则报错）
as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif has sudo; then
    sudo "$@"
  else
    die "需要 root 权限执行：$* （未找到 sudo）"
  fi
}

# 备份已存在的文件/目录（非软链接）到 *.bak.<时间无关序号>，软链接直接删除
backup_path() {
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0
  if [[ -L "$target" ]]; then
    info "移除旧软链接 $target"
    rm -f "$target"
    return 0
  fi
  local bak="${target}.bak"
  local n=1
  while [[ -e "$bak" ]]; do bak="${target}.bak.${n}"; n=$((n + 1)); done
  warn "已存在 $target，备份到 $bak"
  mv "$target" "$bak"
}

# 把仓库内文件部署到目标路径（先备份旧的，再复制）
# 用法：deploy_file <源> <目标>
deploy_file() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || die "源文件不存在：$src"
  mkdir -p "$(dirname "$dst")"
  # 幂等：目标已是普通文件且内容一致时直接跳过，不再产生多余 .bak 备份
  if [[ -f "$dst" && ! -L "$dst" ]] && cmp -s "$src" "$dst"; then
    ok "$dst 已是最新"
    return 0
  fi
  backup_path "$dst"
  cp "$src" "$dst"
  ok "部署 $dst"
}

# 下载到指定文件（curl 优先，回退 wget），失败返回非零
download() {
  local url="$1" out="$2"
  if has curl; then
    curl -fsSL --retry 3 -o "$out" "$url"
  elif has wget; then
    wget -q -O "$out" "$url"
  else
    die "需要 curl 或 wget 才能下载：$url"
  fi
}

# 把 zsh 设为默认 shell（幂等）
ensure_default_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)" || { warn "未找到 zsh，跳过设置默认 shell"; return 0; }
  # 查真实登录 shell（$SHELL 在 chsh 后同一会话内不会更新，会导致重复 chsh / 重复输密码）
  local current_shell=""
  case "$(detect_os)" in
    macos) current_shell="$(dscl . -read "/Users/${USER:-$(id -un)}" UserShell 2>/dev/null | awk '{print $2}')" ;;
    linux) current_shell="$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7)" ;;
  esac
  [[ -n "$current_shell" ]] || current_shell="${SHELL:-}"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    ok "默认 shell 已是 zsh"
    return 0
  fi
  # 确保 zsh 在 /etc/shells 中
  if [[ -w /etc/shells || "$(id -u)" -eq 0 ]] || has sudo; then
    if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
      info "将 $zsh_path 写入 /etc/shells"
      printf '%s\n' "$zsh_path" | as_root tee -a /etc/shells >/dev/null
    fi
  fi
  if chsh -s "$zsh_path" 2>/dev/null; then
    ok "默认 shell 已切换为 zsh（重新登录后生效）"
  # chsh 需要在 tty 上交互输密码，管道/无人值守场景会失败；
  # 回退用 root 执行（此时 sudo 时间戳通常仍有效，无需再输密码）
  elif has sudo && as_root chsh -s "$zsh_path" "$(id -un)" 2>/dev/null; then
    ok "默认 shell 已切换为 zsh（重新登录后生效）"
  else
    warn "chsh 失败，请手动执行：chsh -s $zsh_path"
  fi
}
