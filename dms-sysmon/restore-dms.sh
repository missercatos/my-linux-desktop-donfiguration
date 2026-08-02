#!/bin/bash
# 恢复 DMS 到 8月1日 git 提交的配置（需要 root）
# 用法: sudo bash restore-dms.sh

set -e

DMS_DIR=/usr/share/quickshell/dms
PKG=/var/cache/pacman/pkg/dms-shell-1.5.3-1-x86_64.pkg.tar.zst
REAL_HOME=$(eval echo ~${SUDO_USER:-$USER})

echo "[1/4] 从 pacman 原始包还原 DMSShell/DMSShellIPC/PopoutService"
if [ ! -f "$PKG" ]; then
    echo "错误: 找不到 $PKG"
    exit 1
fi
TMP=$(mktemp -d)
tar --zstd -xf "$PKG" -C "$TMP"
cp "$TMP/usr/share/quickshell/dms/DMSShell.qml" "$DMS_DIR/DMSShell.qml"
cp "$TMP/usr/share/quickshell/dms/DMSShellIPC.qml" "$DMS_DIR/DMSShellIPC.qml"
cp "$TMP/usr/share/quickshell/dms/Services/PopoutService.qml" "$DMS_DIR/Services/PopoutService.qml"
rm -rf "$TMP"
echo "  已还原。"

echo "[2/4] 清理 GitHub 插件配置 (plugin_settings.json)"
if [ -f "$REAL_HOME/.config/DankMaterialShell/plugin_settings.json" ]; then
    rm -f "$REAL_HOME/.config/DankMaterialShell/plugin_settings.json"
    echo "  已删除 plugin_settings.json"
fi

echo "[3/4] 运行旧版 6 步安装脚本 (dotfiles git HEAD 版本)"
bash "$(dirname "$0")/install-sysmon.sh"

echo "[4/4] 重启 DMS"
pkill -f "qs -p /usr/share/quickshell/dms" 2>/dev/null || true
pkill -f "dms run" 2>/dev/null || true
sleep 2
NIRI_SOCK=$(ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)
if [ -n "$NIRI_SOCK" ]; then
    NIRI_SOCKET=$NIRI_SOCK niri msg action spawn -- "dms" "run" || true
fi
sleep 5
pgrep -af "dms run" || echo "警告: DMS 未启动，请手动运行: dms run"
echo "完成。"
