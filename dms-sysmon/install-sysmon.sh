#!/bin/bash
# DMS SysMonitorModal 安装脚本（需要 root）
# 用法: sudo bash install-sysmon.sh

set -e

DMS_DIR=/usr/share/quickshell/dms
MODAL_FILE="$DMS_DIR/Modals/SysMonitorModal.qml"
SRC_FILE="$(dirname "$0")/SysMonitorModal.qml"

echo "[1/3] 复制 SysMonitorModal.qml"
cp "$SRC_FILE" "$MODAL_FILE"
chmod 644 "$MODAL_FILE"

echo "[2/3] 注册 LazyLoader 到 DMSShell.qml"
SHELL_FILE="$DMS_DIR/DMSShell.qml"

# 在 processListModalLoader 块之后插入 sysMonitorModalLoader
awk '
    /id: processListModalLoader/ {
        print
        in_block = 1
        next
    }
    in_block && /^    }$/ {
        print
        print ""
        print "    LazyLoader {"
        print "        id: sysMonitorModalLoader"
        print ""
        print "        active: false"
        print ""
        print "        Component.onCompleted: PopoutService.sysMonitorModalLoader = sysMonitorModalLoader"
        print ""
        print "        SysMonitorModal {"
        print "            id: sysMonitorModal"
        print "            property bool wasShown: false"
        print ""
        print "            Component.onCompleted: {"
        print "                PopoutService.sysMonitorModal = sysMonitorModal;"
        print "            }"
        print ""
        print "            onVisibleChanged: {"
        print "                if (visible) {"
        print "                    wasShown = true;"
        print "                } else if (wasShown) {"
        print "                    PopoutService.unloadSysMonitorModal();"
        print "                }"
        print "            }"
        print "        }"
        print "    }"
        in_block = 0
        next
    }
    { print }
' "$SHELL_FILE" > "$SHELL_FILE.tmp" && mv "$SHELL_FILE.tmp" "$SHELL_FILE"

# 给 DMSShellIPC 传参
true

echo "[3/3] 注册 IPC target 到 DMSShellIPC.qml"
IPC_FILE="$DMS_DIR/DMSShellIPC.qml"

# 3a. required property
grep -q "sysMonitorModalLoader" "$IPC_FILE" || sed -i 's/^    required property var windowRuleModalLoader$/    required property var windowRuleModalLoader\n    required property var sysMonitorModalLoader/' "$IPC_FILE"

# 3b. 在 processlist target 块后插入 IpcHandler
awk '
    /target: "processlist"/ {
        print
        print ""
        print "    IpcHandler {"
        print "        function open(): string {"
        print "            root.sysMonitorModalLoader.active = true;"
        print "            Qt.callLater(() => {"
        print "                if (root.sysMonitorModalLoader.item)"
        print "                    root.sysMonitorModalLoader.item.show();"
        print "            });"
        print ""
        print "            return \"SYSMON_OPEN_SUCCESS\";"
        print "        }"
        print ""
        print "        function close(): string {"
        print "            if (root.sysMonitorModalLoader.item)"
        print "                root.sysMonitorModalLoader.item.hide();"
        print ""
        print "            return \"SYSMON_CLOSE_SUCCESS\";"
        print "        }"
        print ""
        print "        function toggle(): string {"
        print "            root.sysMonitorModalLoader.active = true;"
        print "            Qt.callLater(() => {"
        print "                if (root.sysMonitorModalLoader.item)"
        print "                    root.sysMonitorModalLoader.item.toggle();"
        print "            });"
        print ""
        print "            return \"SYSMON_TOGGLE_SUCCESS\";"
        print "        }"
        print ""
        print "        function focusOrToggle(): string {"
        print "            root.sysMonitorModalLoader.active = true;"
        print "            Qt.callLater(() => {"
        print "                if (root.sysMonitorModalLoader.item)"
        print "                    root.sysMonitorModalLoader.item.focusOrToggle();"
        print "            });"
        print ""
        print "            return \"SYSMON_FOCUS_OR_TOGGLE_SUCCESS\";"
        print "        }"
        print ""
        print "        target: \"sysmon\""
        print "    }"
        next
    }
    { print }
' "$IPC_FILE" > "$IPC_FILE.tmp" && mv "$IPC_FILE.tmp" "$IPC_FILE"

# 3c. DMSShell 传参给 IPC
grep -q "sysMonitorModalLoader: sysMonitorModalLoader" "$SHELL_FILE" || sed -i 's/^        windowRuleModalLoader: windowRuleModalLoader$/        windowRuleModalLoader: windowRuleModalLoader\n        sysMonitorModalLoader: sysMonitorModalLoader/' "$SHELL_FILE"

echo "[4/4] 注册 PopoutService 函数"
POPOUT_FILE="$DMS_DIR/Services/PopoutService.qml"

# 4a. properties
grep -q "sysMonitorModal" "$POPOUT_FILE" || sed -i 's/^    property var processListModalLoader: null$/    property var processListModalLoader: null\n    property var sysMonitorModal: null\n    property var sysMonitorModalLoader: null/' "$POPOUT_FILE"

# 4b. functions（插到 toggleProcessListModal 函数结束之后、下一个函数之前）
if grep -q "function toggleSysMonitorModal" "$POPOUT_FILE"; then
    echo "  PopoutService 已注册，跳过"
else
awk '
    /^    function toggleProcessListModal\(\)/ { in_fn = 1 }
    in_fn && /^    }$/ {
        print
        print ""
        print "    function showSysMonitorModal() {"
        print "        if (sysMonitorModal) {"
        print "            sysMonitorModal.show();"
        print "        } else if (sysMonitorModalLoader) {"
        print "            sysMonitorModalLoader.active = true;"
        print "            Qt.callLater(() => sysMonitorModal?.show());"
        print "        }"
        print "    }"
        print ""
        print "    function hideSysMonitorModal() {"
        print "        sysMonitorModal?.hide();"
        print "    }"
        print ""
        print "    function unloadSysMonitorModal() {"
        print "        if (sysMonitorModalLoader) {"
        print "            sysMonitorModal = null;"
        print "            sysMonitorModalLoader.active = false;"
        print "        }"
        print "    }"
        print ""
        print "    function toggleSysMonitorModal() {"
        print "        if (sysMonitorModal) {"
        print "            sysMonitorModal.toggle();"
        print "        } else if (sysMonitorModalLoader) {"
        print "            sysMonitorModalLoader.active = true;"
        print "            Qt.callLater(() => sysMonitorModal?.show());"
        print "        }"
        print "    }"
        in_fn = 0
        next
    }
    { print }
' "$POPOUT_FILE" > "$POPOUT_FILE.tmp" && mv "$POPOUT_FILE.tmp" "$POPOUT_FILE"
fi

echo "完成。重启 DMS: pkill -f \"qs -p /usr/share/quickshell/dms\" && dms run &"
