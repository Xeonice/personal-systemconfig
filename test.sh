#!/usr/bin/env bash
# test.sh —— 兼容旧入口，已被 install.sh 取代。
# 保留此文件只为不打断旧的肌肉记忆，实际逻辑转交 install.sh。
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "test.sh 已废弃，转交 install.sh ..." >&2
exec bash "$DIR/install.sh" "$@"
