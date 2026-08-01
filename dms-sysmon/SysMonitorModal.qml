import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

FloatingWindow {
    id: root
    readonly property var log: Log.scoped("SysMonitorModal")

    property bool disablePopupTransparency: true
    property string searchText: ""
    property string processFilter: "all"
    property bool shouldHaveFocus: visible
    property alias shouldBeVisible: root.visible

    signal closingModal

    objectName: "sysMonitorModal"
    title: I18n.tr("System Monitor", "sysmon window title")
    minimumSize: Qt.size(620, 480)
    implicitWidth: 780
    implicitHeight: 860
    color: Theme.surfaceContainer
    visible: false

    onClosed: hide()

    function show() {
        if (!DgopService.dgopAvailable) {
            log.warn("dgop is not available");
            return;
        }
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        visible ? hide() : show();
    }

    function formatBytes(bytes) {
        if (bytes < 1024)
            return bytes.toFixed(0) + " B/s";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB/s";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
    }

    function addToHistory(arr, val) {
        const newArr = arr.slice();
        newArr.push(val);
        if (newArr.length > DgopService.historySize)
            newArr.shift();
        return newArr;
    }

    onVisibleChanged: {
        if (!visible) {
            closingModal();
            searchText = "";
            DgopService.removeRef(["cpu", "memory", "network", "disk", "system", "processes"]);
        } else {
            DgopService.addRef(["cpu", "memory", "network", "disk", "system", "processes"]);
            Qt.callLater(() => contentFocusScope.forceActiveFocus());
        }
    }

    SystemClock {
        id: sampleClock
        precision: SystemClock.Seconds
        onDateChanged: {
            if (date.getSeconds() % 1 === 0)
                sampleData();
        }
    }

    function sampleData() {
        DgopService.cpuHistory = addToHistory(DgopService.cpuHistory, DgopService.cpuUsage);
        DgopService.memoryHistory = addToHistory(DgopService.memoryHistory, DgopService.memoryUsage);
        const rx = (DgopService.networkHistory?.rx || []).slice();
        const tx = (DgopService.networkHistory?.tx || []).slice();
        rx.push(DgopService.networkRxRate);
        tx.push(DgopService.networkTxRate);
        if (rx.length > DgopService.historySize)
            rx.shift();
        if (tx.length > DgopService.historySize)
            tx.shift();
        DgopService.networkHistory = { "rx": rx, "tx": tx };
    }

    FocusScope {
        id: contentFocusScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.hide();
                event.accepted = true;
                return;
            }
        }

        Flickable {
            id: mainFlickable
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            contentWidth: width
            contentHeight: mainColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: DankScrollbar {
                policy: ScrollBar.AsNeeded
            }

            ColumnLayout {
                id: mainColumn
                width: mainFlickable.width
                spacing: Theme.spacingM

                AsciiClock {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StatCard {
                        Layout.fillWidth: true
                        title: "CPU"
                        icon: "memory"
                        value: DgopService.cpuUsage.toFixed(1) + "%"
                        subtitle: DgopService.cpuModel || (DgopService.cpuCores + " cores")
                        accentColor: Theme.primary
                        history: DgopService.cpuHistory
                        maxValue: 100
                        extraInfo: DgopService.cpuTemperature > 0 ? (DgopService.cpuTemperature.toFixed(0) + "°C") : ""
                        extraInfoColor: DgopService.cpuTemperature > 80 ? Theme.error : (DgopService.cpuTemperature > 60 ? Theme.warning : Theme.surfaceVariantText)
                    }

                    StatCard {
                        Layout.fillWidth: true
                        title: I18n.tr("Memory")
                        icon: "sd_card"
                        value: DgopService.memoryUsage.toFixed(1) + "%"
                        subtitle: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                        accentColor: Theme.secondary
                        history: DgopService.memoryHistory
                        maxValue: 100
                        extraInfo: DgopService.totalSwapKB > 0 ? ("Swap: " + DgopService.formatSystemMemory(DgopService.usedSwapKB)) : ""
                        extraInfoColor: Theme.surfaceVariantText
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM

                    StatCard {
                        Layout.fillWidth: true
                        title: I18n.tr("Network")
                        icon: "swap_horiz"
                        value: "↓ " + root.formatBytes(DgopService.networkRxRate)
                        subtitle: "↑ " + root.formatBytes(DgopService.networkTxRate)
                        accentColor: Theme.info
                        history: DgopService.networkHistory?.rx || []
                        history2: DgopService.networkHistory?.tx || []
                        maxValue: 0
                        showSecondary: true
                        extraInfo: ""
                        extraInfoColor: Theme.surfaceVariantText
                    }

                    StatCard {
                        Layout.fillWidth: true
                        title: I18n.tr("Disk")
                        icon: "storage"
                        value: "R: " + root.formatBytes(DgopService.diskReadRate)
                        subtitle: "W: " + root.formatBytes(DgopService.diskWriteRate)
                        accentColor: Theme.warning
                        history: DgopService.diskHistory?.read || []
                        history2: DgopService.diskHistory?.write || []
                        maxValue: 0
                        showSecondary: true
                        extraInfo: {
                            const rootMount = DgopService.diskMounts.find(m => m.mountpoint === "/");
                            if (rootMount) {
                                const usedPct = ((rootMount.used || 0) / Math.max(1, rootMount.total || 1) * 100).toFixed(0);
                                return "/ " + usedPct + "% used";
                            }
                            return "";
                        }
                        extraInfoColor: Theme.surfaceVariantText
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cavaColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    border.color: Theme.outlineLight
                    border.width: 1

                    ColumnLayout {
                        id: cavaColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "graphic_eq"
                                size: Theme.iconSize
                                color: Theme.tertiary
                            }

                            StyledText {
                                text: I18n.tr("Audio Spectrum", "cava section title")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: CavaService.cavaAvailable ? "" : I18n.tr("cava not available", "cava missing hint")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.warning
                                visible: !CavaService.cavaAvailable
                            }
                        }

                        Row {
                            id: cavaBars
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            spacing: 6

                            Repeater {
                                model: 6

                                Item {
                                    width: (cavaBars.width - 6 * 5) / 6
                                    height: cavaBars.height
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        id: barRect
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 4 + (CavaService.values[index] / 100) * (parent.height - 8)
                                        radius: 2
                                        color: Theme.tertiary

                                        Behavior on height {
                                            NumberAnimation {
                                                duration: 90
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MediaSection {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: sysInfoColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    border.color: Theme.outlineLight
                    border.width: 1

                    ColumnLayout {
                        id: sysInfoColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "computer"
                                size: Theme.iconSize
                                color: Theme.primary
                            }

                            StyledText {
                                text: I18n.tr("Hardware Info", "hardware info header")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: DgopService.uptime ? I18n.tr("Up: ") + DgopService.uptime : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: Theme.spacingL
                            rowSpacing: Theme.spacingXS

                            InfoRow { label: I18n.tr("Host"); value: DgopService.hostname || "--" }
                            InfoRow { label: I18n.tr("Distro"); value: DgopService.distribution || "--" }
                            InfoRow { label: I18n.tr("Kernel"); value: DgopService.kernelVersion || "--" }
                            InfoRow { label: I18n.tr("Arch"); value: DgopService.architecture || "--" }
                            InfoRow {
                                label: I18n.tr("CPU")
                                value: DgopService.cpuModel || (DgopService.cpuCores + " cores")
                                Layout.columnSpan: 2
                            }
                            InfoRow {
                                label: I18n.tr("Load")
                                value: DgopService.loadAverage || "--"
                            }
                            InfoRow {
                                label: I18n.tr("Processes")
                                value: DgopService.processCount > 0 ? DgopService.processCount.toString() : "--"
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 260
                    radius: Theme.cornerRadius
                    color: Theme.nestedSurface
                    border.color: Theme.outlineLight
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "view_list"
                                size: Theme.iconSize
                                color: Theme.info
                            }

                            StyledText {
                                text: I18n.tr("Running Processes", "process list title")
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            DankTextField {
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 2.8)
                                placeholderText: I18n.tr("Search processes...", "process search placeholder")
                                leftIconName: "search"
                                showClearButton: true
                                text: root.searchText
                                onTextChanged: root.searchText = text
                                ignoreUpDownKeys: true
                            }
                        }

                        ListView {
                            id: processList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: DankScrollbar {
                                policy: ScrollBar.AsNeeded
                            }

                            model: root.filteredProcesses

                            delegate: Rectangle {
                                width: processList.width
                                height: 28
                                radius: 4
                                color: mouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.rightMargin: Theme.spacingS
                                    spacing: Theme.spacingM

                                    StyledText {
                                        text: modelData.pid
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                        Layout.preferredWidth: 48
                                    }

                                    StyledText {
                                        text: modelData.command || "--"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: (modelData.cpu || 0).toFixed(1) + "%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.info
                                        Layout.preferredWidth: 56
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    StyledText {
                                        text: DgopService.formatSystemMemory(modelData.memoryKB || 0)
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceTextMedium
                                        Layout.preferredWidth: 72
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    readonly property var filteredProcesses: {
        if (!DgopService.allProcesses || DgopService.allProcesses.length === 0)
            return [];

        let procs = DgopService.allProcesses.slice();

        if (processFilter === "user") {
            procs = procs.filter(p => p.username === UserInfoService.username);
        } else if (processFilter === "system") {
            procs = procs.filter(p => p.username !== UserInfoService.username);
        }

        if (searchText.length > 0) {
            const search = searchText.toLowerCase();
            procs = procs.filter(p => {
                const cmd = (p.command || "").toLowerCase();
                const fullCmd = (p.fullCommand || "").toLowerCase();
                const pid = p.pid.toString();
                return cmd.includes(search) || fullCmd.includes(search) || pid.includes(search);
            });
        }

        procs.sort((a, b) => (b.cpu || 0) - (a.cpu || 0));

        return procs.slice(0, 60);
    }

    component AsciiClock: Item {
        id: asciiRoot

        readonly property var digitGlyphs: [
            [
                " ██████ ",
                "██    ██",
                "██    ██",
                "██    ██",
                " ██████ "
            ],
            [
                "    ██  ",
                "  ████  ",
                "    ██  ",
                "    ██  ",
                "  ██████"
            ],
            [
                " ██████ ",
                "██    ██",
                "   ████ ",
                " ██     ",
                "████████"
            ],
            [
                "████████",
                "      ██",
                "  ████  ",
                "      ██",
                "████████"
            ],
            [
                "██    ██",
                "██    ██",
                "████████",
                "      ██",
                "      ██"
            ],
            [
                "████████",
                "██      ",
                "███████ ",
                "      ██",
                "███████ "
            ],
            [
                " ██████ ",
                "██      ",
                "███████ ",
                "██    ██",
                " ██████ "
            ],
            [
                "████████",
                "      ██",
                "    ██  ",
                "   ██   ",
                "   ██   "
            ],
            [
                " ██████ ",
                "██    ██",
                " ██████ ",
                "██    ██",
                " ██████ "
            ],
            [
                " ██████ ",
                "██    ██",
                " ███████",
                "      ██",
                " ██████ "
            ]
        ]

        readonly property var colonGlyph: [
            "      ",
            "  ██  ",
            "      ",
            "  ██  ",
            "      "
        ]

        SystemClock {
            id: asciiClock
            precision: SystemClock.Minutes
        }

        readonly property var timeLines: {
            const h = asciiClock.date.getHours();
            const m = asciiClock.date.getMinutes();
            const hh = String(h).padStart(2, "0");
            const mm = String(m).padStart(2, "0");
            const glyphIds = [parseInt(hh[0], 10), parseInt(hh[1], 10), parseInt(mm[0], 10), parseInt(mm[1], 10)];
            const lines = [];
            for (let row = 0; row < 5; row++) {
                let line = "";
                for (let i = 0; i < 4; i++) {
                    line += digitGlyphs[glyphIds[i]][row];
                    if (i === 1)
                        line += colonGlyph[row];
                }
                lines.push(line);
            }
            return lines;
        }

        readonly property string dateText: {
            const d = asciiClock.date;
            const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            return weekdays[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate() + " " + d.getFullYear();
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingM

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Repeater {
                    model: asciiRoot.timeLines

                    Text {
                        text: modelData
                        font.family: "monospace"
                        font.pixelSize: Math.round(Theme.fontSizeMedium * 1.05)
                        font.bold: true
                        color: Theme.primary
                        horizontalAlignment: Text.AlignHCenter
                        style: Text.Raised
                        styleColor: Theme.withAlpha(Theme.primary, 0.35)
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: asciiRoot.dateText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceTextMedium
            }
        }
    }

    component StatCard: Rectangle {
        id: card

        property string title: ""
        property string icon: ""
        property string value: ""
        property string subtitle: ""
        property color accentColor: Theme.primary
        property var history: []
        property var history2: null
        property real maxValue: 100
        property bool showSecondary: false
        property string extraInfo: ""
        property color extraInfoColor: Theme.surfaceVariantText

        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.color: Theme.outlineLight
        border.width: 1
        implicitHeight: 148

        Canvas {
            id: graphCanvas
            anchors.fill: parent
            anchors.margins: 4
            renderStrategy: Canvas.Cooperative

            property var hist: card.history
            property var hist2: card.history2

            onHistChanged: requestPaint()
            onHist2Changed: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.clearRect(0, 0, width, height);

                if (!hist || hist.length < 2)
                    return;

                let max = card.maxValue;
                if (max <= 0) {
                    max = 1;
                    for (let k = 0; k < hist.length; k++)
                        max = Math.max(max, hist[k]);
                    if (hist2) {
                        for (let l = 0; l < hist2.length; l++)
                            max = Math.max(max, hist2[l]);
                    }
                    max *= 1.1;
                }

                const c = card.accentColor;
                const grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Theme.withAlpha(c, 0.25));
                grad.addColorStop(1, Theme.withAlpha(c, 0.02));

                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.moveTo(0, height);
                for (let i = 0; i < hist.length; i++) {
                    const x = (width / (DgopService.historySize - 1)) * i;
                    const y = height - (hist[i] / max) * height * 0.8;
                    ctx.lineTo(x, y);
                }
                ctx.lineTo((width / (DgopService.historySize - 1)) * (hist.length - 1), height);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = Theme.withAlpha(c, 0.8);
                ctx.lineWidth = 2;
                ctx.beginPath();
                for (let j = 0; j < hist.length; j++) {
                    const px = (width / (DgopService.historySize - 1)) * j;
                    const py = height - (hist[j] / max) * height * 0.8;
                    j === 0 ? ctx.moveTo(px, py) : ctx.lineTo(px, py);
                }
                ctx.stroke();

                if (hist2 && hist2.length >= 2 && card.showSecondary) {
                    ctx.strokeStyle = Theme.withAlpha(c, 0.4);
                    ctx.lineWidth = 1.5;
                    ctx.setLineDash([4, 4]);
                    ctx.beginPath();
                    for (let m = 0; m < hist2.length; m++) {
                        const sx = (width / (DgopService.historySize - 1)) * m;
                        const sy = height - (hist2[m] / max) * height * 0.8;
                        m === 0 ? ctx.moveTo(sx, sy) : ctx.lineTo(sx, sy);
                    }
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingS

                DankIcon {
                    name: card.icon
                    size: Theme.iconSize
                    color: card.accentColor
                }

                StyledText {
                    text: card.title
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: card.extraInfo
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: SettingsData.monoFontFamily
                    color: card.extraInfoColor
                    visible: card.extraInfo.length > 0
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                text: card.value
                font.pixelSize: Theme.fontSizeXLarge
                font.family: SettingsData.monoFontFamily
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                text: card.subtitle
                font.pixelSize: Theme.fontSizeSmall
                font.family: SettingsData.monoFontFamily
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    component InfoRow: RowLayout {
        property string label: ""
        property string value: ""

        spacing: Theme.spacingS
        Layout.fillWidth: true

        StyledText {
            text: parent.label
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            Layout.preferredWidth: 76
        }

        StyledText {
            text: parent.value
            font.pixelSize: Theme.fontSizeSmall
            font.family: SettingsData.monoFontFamily
            color: Theme.surfaceText
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    component MediaSection: Rectangle {
        id: mediaRoot

        property MprisPlayer activePlayer: MprisController.activePlayer

        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.color: Theme.outlineLight
        border.width: 1
        Layout.preferredHeight: 120

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: !mediaRoot.activePlayer

            DankIcon {
                name: "music_note"
                size: Theme.iconSize
                color: Theme.surfaceTextSecondary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.tr("No Media Playing", "no media hint")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingL
            visible: mediaRoot.activePlayer

            Item {
                width: 100
                height: 84
                Layout.preferredWidth: 100
                Layout.preferredHeight: 84

                DankAlbumArt {
                    width: 80
                    height: 80
                    anchors.centerIn: parent
                    activePlayer: mediaRoot.activePlayer
                    albumSize: 64
                    animationScale: 1.05
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacingXS

                StyledText {
                    text: MprisController.stableTitle || I18n.tr("Unknown")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    text: MprisController.stableArtist || I18n.tr("Unknown Artist")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                DankSeekbar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    activePlayer: mediaRoot.activePlayer
                }
            }

            Row {
                spacing: Theme.spacingS
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: prevArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0)

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_previous"
                        size: 14
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.previousOrRewind()
                    }
                }

                Rectangle {
                    id: playPauseButton
                    width: 32
                    height: 32
                    radius: 16
                    color: MediaAccentService.accent

                    DankIcon {
                        anchors.centerIn: parent
                        name: mediaRoot.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                        size: 16
                        color: MediaAccentService.onAccent
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaRoot.activePlayer?.togglePlaying()
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: playPauseButton.verticalCenter
                    color: nextArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0)

                    DankIcon {
                        anchors.centerIn: parent
                        name: "skip_next"
                        size: 14
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MprisController.next()
                    }
                }
            }
        }
    }
}
