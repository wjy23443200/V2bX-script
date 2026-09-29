#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo '请以 root 身份运行清理脚本。' >&2
    exit 1
fi

# This recovery command is deliberately limited to the interrupted install
# shown by "v2bx: command not found". Never take over a working installation.
if [[ -e /usr/bin/v2bx || -L /usr/bin/v2bx ]]; then
    echo '检测到 v2bx 命令；可能已安装完成。已停止清理，请先检查服务状态。' >&2
    exit 1
fi
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet V2bX.service; then
    echo 'V2bX 服务正在运行，已停止清理。' >&2
    exit 1
fi
if command -v rc-service >/dev/null 2>&1 && rc-service V2bX status >/dev/null 2>&1; then
    echo 'V2bX 服务正在运行，已停止清理。' >&2
    exit 1
fi
if command -v pgrep >/dev/null 2>&1 && pgrep -x V2bX >/dev/null 2>&1; then
    echo 'V2bX 进程正在运行，已停止清理。' >&2
    exit 1
fi

paths=(
    /usr/local/V2bX
    /etc/V2bX
    /etc/systemd/system/V2bX.service
    /etc/init.d/V2bX
    /usr/bin/V2bX
    /usr/bin/v2bx
)
found=0
for path in "${paths[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
        found=1
        break
    fi
done
if (( found == 0 )); then
    echo '没有发现需要清理的 V2bX 安装残留。'
    exit 0
fi

# Disable the unit before moving its service file so it cannot start on reboot.
if [[ -e /etc/systemd/system/V2bX.service ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl disable V2bX.service
fi
if [[ -e /etc/init.d/V2bX ]] && command -v rc-update >/dev/null 2>&1; then
    rc-update del V2bX default
fi

umask 077
backup=$(mktemp -d /root/v2bx-recovery.XXXXXXXX)
for path in "${paths[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
        target="${backup}${path}"
        mkdir -p "$(dirname "$target")"
        mv -- "$path" "$target"
        echo "已移走：$path"
    fi
done
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
fi

echo "安装残留已移到：$backup"
echo '原始面板配置 /root/v2bx.private.json 已保留。现在可重新运行 README 中的安装命令。'
