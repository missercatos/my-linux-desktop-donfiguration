import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    color: "transparent"
    visible: false
    fullscreen: true

    onClosed: hide()

    readonly property real tileBgAlpha: Math.min(1, Math.max(0.55, Theme.popupTransparency * 2))
    readonly property int tileGap: 12
    readonly property int tilePadding: Math.max(Theme.spacingL, Math.round(Theme.spacingM * 1.5))

    // ============ GRID SYSTEM ============
    property int gridCols: 12
    readonly property int gridRows: 13

    readonly property real gridWidth: tileArea.width
    readonly property real gridHeight: tileArea.height
    readonly property real cellWidth: (gridWidth - tileGap * (gridCols - 1)) / gridCols
    readonly property real cellHeight: (gridHeight - tileGap * (gridRows - 1)) / gridRows

    function colX(c) { return c * (cellWidth + tileGap); }
    function rowY(r) { return r * (cellHeight + tileGap); }
    function colW(span) { return span * cellWidth + (span - 1) * tileGap; }
    function rowH(span) { return span * cellHeight + (span - 1) * tileGap; }

    // ---- drag state ----
    property var draggingTile: null
    property real dragPosX: 0
    property real dragPosY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragMouseX: 0
    property real dragMouseY: 0
    property var dragEvicted: ({})
    property int dragTargetCol: -1
    property int dragTargetRow: -1

    readonly property bool animEnabled: draggingTile === null

    function tileBeginDrag(tile, mx, my) {
        if (root.draggingTile)
            return;
        root.draggingTile = tile;
        tile.z = 100;
        root.dragStartX = tile.x;
        root.dragStartY = tile.y;
        root.dragMouseX = mx;
        root.dragMouseY = my;
        root.dragPosX = tile.x;
        root.dragPosY = tile.y;
        root.dragEvicted = {};
        root.dragTargetCol = tile.gridCol;
        root.dragTargetRow = tile.gridRow;
    }

    function tileDrag(tile, mx, my) {
        if (root.draggingTile !== tile)
            return;
        root.dragPosX = Math.max(0, Math.min(gridWidth - tile.width, root.dragStartX + (mx - root.dragMouseX)));
        root.dragPosY = Math.max(0, Math.min(gridHeight - tile.height, root.dragStartY + (my - root.dragMouseY)));
        const tc = Math.max(0, Math.min(gridCols - tile.colSpan, Math.round(root.dragPosX / (cellWidth + tileGap))));
        const tr = Math.max(0, Math.min(gridRows - tile.rowSpan, Math.round(root.dragPosY / (cellHeight + tileGap))));
        if (tc === root.dragTargetCol && tr === root.dragTargetRow)
            return;
        const prevC = root.dragTargetCol;
        const prevR = root.dragTargetRow;
        root.dragTargetCol = tc;
        root.dragTargetRow = tr;
        if (tc === tile.gridCol && tr === tile.gridRow) {
            return;
        }
        root.resolveEviction(tile, tc, tr);
        const fail = false;
        for (const t of root.tiles) {
            const target = { "col": root.dragTargetCol, "row": root.dragTargetRow, "colSpan": tile.colSpan, "rowSpan": tile.rowSpan };
            if (t !== tile && root.rectsOverlap(t, target)) {
                root.dragTargetCol = prevC;
                root.dragTargetRow = prevR;
                return;
            }
        }
    }

    function tileEndDrag(tile) {
        if (root.draggingTile !== tile)
            return;
        root.draggingTile = null;
        tile.gridCol = root.dragTargetCol;
        tile.gridRow = root.dragTargetRow;
        tile.z = 20;
        root.saveLayout();
    }

    function resolveEviction(dt, tc, tr) {
        const target = { "col": tc, "row": tr, "colSpan": dt.colSpan, "rowSpan": dt.rowSpan };
        const origin = { "col": dt.gridCol, "row": dt.gridRow, "colSpan": dt.colSpan, "rowSpan": dt.rowSpan };
        const allTiles = root.tiles.filter(function(t) { return t !== dt; });
        let savedPos = {};
        for (const t of allTiles)
            savedPos[t.tileId] = { "col": t.gridCol, "row": t.gridRow };
        let moved = {};
        let evicted = [];
        for (const t of allTiles) {
            if (root.rectsOverlap(t, target))
                evicted.push(t);
        }
        if (evicted.length === 0)
            return;
        function isFree(rect, ignored) {
            if (root.rectsOverlap(target, rect))
                return false;
            for (const t of allTiles) {
                if (t === ignored)
                    continue;
                const pos = moved[t.tileId] || t;
                const r = { "col": pos.gridCol, "row": pos.gridRow, "colSpan": t.colSpan, "rowSpan": t.rowSpan };
                if (root.rectsOverlap(r, rect))
                    return false;
            }
            return true;
        }
        let originUsed = false;
        for (const o of evicted) {
            const w = o.colSpan;
            const h = o.rowSpan;
            let best = root.bfsFreeAnchor(o.gridCol, o.gridRow, w, h, isFree);
            if (!best && !originUsed && w <= dt.colSpan && h <= dt.rowSpan) {
                best = { "col": origin.col, "row": origin.row };
                originUsed = true;
            }
            if (best) {
                moved[o.tileId] = { "gridCol": best.col, "gridRow": best.row };
                o.gridCol = best.col;
                o.gridRow = best.row;
            } else {
                for (const t of allTiles) {
                    t.gridCol = savedPos[t.tileId].col;
                    t.gridRow = savedPos[t.tileId].row;
                }
                return;
            }
        }
    }

    function bfsFreeAnchor(sx, sy, w, h, isFreeFn) {
        let candidates = [];
        for (let d = 0; d < gridCols + gridRows; d++) {
            for (let dx = -d; dx <= d; dx++) {
                let dy = d - Math.abs(dx);
                for (let s = -1; s <= 1; s += 2) {
                    const ry = sy + s * dy;
                    if (ry < 0 || ry + h > gridRows)
                        continue;
                    if (dx === 0 && dy === 0) {
                        const r = { "col": sx, "row": sy };
                        if (isFreeFn(r, null))
                            return { "col": sx, "row": sy };
                    } else {
                        for (let sd = -1; sd <= 1; sd += 2) {
                            const rx = sx + sd * dx;
                            if (rx < 0 || rx + w > gridCols)
                                continue;
                            const r = { "col": rx, "row": ry };
                            if (isFreeFn(r, null))
                                candidates.push({ "col": rx, "row": ry, "dist": d });
                        }
                    }
                }
            }
            if (candidates.length > 0) {
                candidates.sort(function(a, b) { return a.dist - b.dist; });
                return { "col": candidates[0].col, "row": candidates[0].row };
            }
        }
        return null;
    }

    // ---- layout algorithm ----
    function rectsOverlap(a, b) {
        const ac = a.col !== undefined ? a.col : a.gridCol;
        const ar = a.row !== undefined ? a.row : a.gridRow;
        const bc = b.col !== undefined ? b.col : b.gridCol;
        const br = b.row !== undefined ? b.row : b.gridRow;
        return !(ac + a.colSpan <= bc || bc + b.colSpan <= ac ||
                 ar + a.rowSpan <= br || br + b.rowSpan <= ar);
    }

    function placeTile(tile, tc, tr) {
        if (tile.gridCol === tc && tile.gridRow === tr)
            return;
        const target = { "col": tc, "row": tr, "colSpan": tile.colSpan, "rowSpan": tile.rowSpan };
        const origin = { "col": tile.gridCol, "row": tile.gridRow, "colSpan": tile.colSpan, "rowSpan": tile.rowSpan };
        const allTiles = root.tiles.filter(function(t) { return t !== tile; });
        tile.gridCol = -100;
        tile.gridRow = -100;
        let evicted = [];
        for (const t of allTiles) {
            if (root.rectsOverlap(t, target))
                evicted.push(t);
        }
        function isFree(rect) {
            if (root.rectsOverlap(target, rect))
                return false;
            for (const t of allTiles) {
                const r = { "col": t.gridCol, "row": t.gridRow, "colSpan": t.colSpan, "rowSpan": t.rowSpan };
                if (root.rectsOverlap(r, rect))
                    return false;
            }
            return true;
        }
        let originUsed = false;
        for (const o of evicted) {
            const w = o.colSpan;
            const h = o.rowSpan;
            let best = root.bfsFreeAnchor(o.gridCol, o.gridRow, w, h, isFree);
            if (!best && !originUsed && w === tile.colSpan && h === tile.rowSpan) {
                best = { "col": origin.col, "row": origin.row };
                originUsed = true;
            }
            if (best) {
                o.gridCol = best.col;
                o.gridRow = best.row;
            }
        }
        tile.gridCol = tc;
        tile.gridRow = tr;
    }

    // ---- layout persistence ----
    property var tileLayout: ({})

    readonly property string layoutPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell/sysmon_layout.json"

    FileView {
        id: layoutFile
        path: root.layoutPath
        blockLoading: false
        blockWrites: false

        onLoaded: {
            try {
                root.tileLayout = JSON.parse(layoutFile.text());
            } catch (e) {
                root.tileLayout = {};
            }
            const ver = root.tileLayout.__v;
            if (ver !== 3) {
                root.tileLayout = {};
                return;
            }
            for (const t of root.tiles) {
                const cfg = root.gridFromLayout(t.tileId, null);
                if (cfg) {
                    t.gridCol = cfg.col;
                    t.gridRow = cfg.row;
                }
            }
        }
    }

    function gridFromLayout(id, fallback) {
        const cfg = root.tileLayout[id];
        if (cfg && cfg.col !== undefined && cfg.row !== undefined)
            return cfg;
        return fallback;
    }

    function saveLayout() {
        const out = { "__v": 3 };
        for (const t of root.tiles) {
            out[t.tileId] = { "col": t.gridCol, "row": t.gridRow };
        }
        root.tileLayout = out;
        layoutFile.setText(JSON.stringify(out, null, 2));
    }

    function resetLayout() {
        root.tileLayout = {};
        for (const t of root.tiles) {
            t.gridCol = t.defaultCol;
            t.gridRow = t.defaultRow;
        }
        layoutFile.setText("{}");
    }

    property var tiles: []

    function registerTile(t) {
        root.tiles.push(t);
    }

    // ============ DATA SAMPLING ============
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

    function focusOrToggle() {
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

    function formatBytesPlain(bytes) {
        if (bytes < 1024)
            return bytes.toFixed(0) + " B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).toFixed(1) + " KB";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB";
        return (bytes / (1024 * 1024 * 1024)).toFixed(2) + " GB";
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
            CavaService.refCount = Math.max(0, CavaService.refCount - 1);
        } else {
            DgopService.addRef(["cpu", "memory", "network", "disk", "system", "processes"]);
            CavaService.refCount++;
            Qt.callLater(() => contentFocusScope.forceActiveFocus());
            GitHubService.refresh();
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

        Item {
            id: tileArea
            anchors.fill: parent
            anchors.margins: root.tilePadding
            clip: false

            // ================= TILE BASE =================
            component SysTile: Item {
                id: tile

                property string tileId: ""
                property string tileTitle: ""
                property string tileIcon: ""
                property int defaultCol: 0
                property int defaultRow: 0
                property int colSpan: 1
                property int rowSpan: 1
                property int gridCol: root.gridFromLayout(tileId, { "col": defaultCol, "row": defaultRow }).col
                property int gridRow: root.gridFromLayout(tileId, { "col": defaultCol, "row": defaultRow }).row

                readonly property real titleBarHeight: Math.max(24, Math.min(32, cellHeight * 0.32))
                readonly property real contentMargin: Math.max(6, Math.min(Theme.spacingM, Math.round(cellWidth * 0.06)))

                x: root.draggingTile === tile ? root.dragPosX : root.colX(tile.gridCol)
                y: root.draggingTile === tile ? root.dragPosY : root.rowY(tile.gridRow)
                width: root.colW(tile.colSpan)
                height: root.rowH(tile.rowSpan)
                z: 20

                Behavior on x { enabled: root.animEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: root.animEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: root.animEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: root.animEnabled; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Component.onCompleted: {
                    root.registerTile(tile);
                    const cfg = root.gridFromLayout(tileId, null);
                    if (cfg) {
                        tile.gridCol = cfg.col;
                        tile.gridRow = cfg.row;
                    }
                }

                Rectangle {
                    id: tileBg
                    anchors.fill: parent
                    radius: Theme.cornerRadius * 1.2
                    color: Theme.withAlpha(Theme.surfaceContainer, root.tileBgAlpha)
                    border.color: Theme.outlineLight
                    border.width: 1
                }

                // drag feedback
                Rectangle {
                    id: dragOverlay
                    anchors.fill: parent
                    radius: Theme.cornerRadius * 1.2
                    color: "transparent"
                    border.color: Theme.withAlpha(Theme.primary, 0.55)
                    border.width: 2
                    visible: root.draggingTile === tile
                    scale: 1.02
                }

                RowLayout {
                    id: titleBar
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: tile.titleBarHeight
                    spacing: 6

                    DankIcon {
                        name: tile.tileIcon
                        size: Math.max(12, Math.min(Theme.iconSize, tile.titleBarHeight - 8))
                        color: Theme.surfaceTextSecondary
                    }

                    StyledText {
                        text: tile.tileTitle
                        font.pixelSize: Math.max(10, Math.min(Theme.fontSizeMedium, tile.titleBarHeight * 0.5))
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    DankIcon {
                        name: "drag_indicator"
                        size: 12
                        color: Theme.surfaceVariantText
                    }
                }

                Item {
                    id: tileContent
                    anchors { top: titleBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.margins: tile.contentMargin
                    anchors.topMargin: 2
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.ArrowCursor

                    onPressed: mouse => {
                        if (mouse.button !== Qt.LeftButton)
                            return;
                        if ((mouse.modifiers & Qt.ControlModifier) === 0) {
                            mouse.accepted = false;
                            return;
                        }
                        root.tileBeginDrag(tile, mouse.x, mouse.y);
                        cursorShape = Qt.ClosedHandCursor;
                    }
                    onPositionChanged: mouse => {
                        if (root.draggingTile === tile) {
                            root.tileDrag(tile, mouse.x, mouse.y);
                        } else if (mouse.modifiers & Qt.ControlModifier) {
                            cursorShape = Qt.OpenHandCursor;
                        }
                    }
                    onReleased: mouse => {
                        if (root.draggingTile === tile) {
                            root.tileEndDrag(tile);
                            cursorShape = Qt.OpenHandCursor;
                        }
                    }
                }

                default property alias tileData: tileContent.data
            }

            // ================= ASCII CLOCK =================
            component AsciiClock: Item {
                id: asciiRoot

                readonly property var digitGlyphs: [
                    [ " ██████ ", "██    ██", "██    ██", "██    ██", " ██████ " ],
                    [ "    ██  ", "  ████  ", "    ██  ", "    ██  ", "  ██████" ],
                    [ " ██████ ", "██    ██", "   ████ ", " ██     ", "████████" ],
                    [ "████████", "      ██", "  ████  ", "      ██", "████████" ],
                    [ "██    ██", "██    ██", "████████", "      ██", "      ██" ],
                    [ "████████", "██      ", "███████ ", "      ██", "███████ " ],
                    [ " ██████ ", "██      ", "███████ ", "██    ██", " ██████ " ],
                    [ "████████", "      ██", "    ██  ", "   ██   ", "   ██   " ],
                    [ " ██████ ", "██    ██", " ██████ ", "██    ██", " ██████ " ],
                    [ " ██████ ", "██    ██", " ███████", "      ██", " ██████ " ]
                ]

                readonly property var colonGlyph: [ "      ", "  ██  ", "      ", "  ██  ", "      " ]

                SystemClock {
                    id: asciiClock
                    precision: SystemClock.Seconds
                }

                readonly property var timeLines: {
                    const d = asciiClock.date;
                    const hh = String(d.getHours()).padStart(2, "0");
                    const mm = String(d.getMinutes()).padStart(2, "0");
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

                readonly property string secondsText: String(asciiClock.date.getSeconds()).padStart(2, "0")

                readonly property real asciiFont: Math.max(10, Math.min(15, asciiRoot.height / 12))

                Column {
                    anchors.centerIn: parent
                    spacing: Math.max(4, Math.round(asciiRoot.height * 0.05))

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1

                        Repeater {
                            model: asciiRoot.timeLines

                            Text {
                                text: modelData
                                font.family: "monospace"
                                font.pixelSize: asciiRoot.asciiFont
                                font.bold: true
                                color: Theme.primary
                                horizontalAlignment: Text.AlignHCenter
                                style: Text.Raised
                                styleColor: Theme.withAlpha(Theme.primary, 0.35)
                            }
                        }
                    }

                    RowLayout {
                        width: asciiRoot.width
                        spacing: 8

                        StyledText {
                            text: asciiRoot.dateText
                            font.pixelSize: Math.max(10, Math.min(Theme.fontSizeLarge, asciiRoot.height * 0.09))
                            font.weight: Font.Medium
                            color: Theme.surfaceTextMedium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: asciiRoot.secondsText
                            font.pixelSize: Math.max(14, Math.min(Theme.fontSizeXLarge, asciiRoot.height * 0.12))
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                    }
                }
            }

            // ================= SPARK CARD =================
            component SparkCard: Item {
                id: card

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

                Canvas {
                    id: graphCanvas
                    anchors.fill: parent
                    anchors.bottomMargin: Math.max(24, card.height * 0.22)
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
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: card.value
                            font.pixelSize: Math.max(12, Math.min(Theme.fontSizeXLarge, card.height * 0.13))
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: card.extraInfo
                            font.pixelSize: Math.max(9, Math.min(Theme.fontSizeSmall, card.height * 0.08))
                            font.family: SettingsData.monoFontFamily
                            color: card.extraInfoColor
                            visible: card.extraInfo.length > 0
                        }
                    }

                    StyledText {
                        text: card.subtitle
                        font.pixelSize: Math.max(9, Math.min(Theme.fontSizeSmall, card.height * 0.08))
                        font.family: SettingsData.monoFontFamily
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ================= INFO ROW =================
            component InfoRow: RowLayout {
                property string label: ""
                property string value: ""

                spacing: 6
                Layout.fillWidth: true

                StyledText {
                    text: parent.label
                    font.pixelSize: Math.max(9, Math.min(Theme.fontSizeSmall, 13))
                    color: Theme.surfaceVariantText
                    Layout.preferredWidth: Math.max(52, Math.min(80, parent.width * 0.26))
                }

                StyledText {
                    text: parent.value
                    font.pixelSize: Math.max(9, Math.min(Theme.fontSizeSmall, 13))
                    font.family: SettingsData.monoFontFamily
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // ================= GITHUB GRAPH =================
            component GitHubGraph: Item {
                id: graph

                property bool editing: false
                property string usernameText: GitHubService.username
                property string tokenText: GitHubService.token

                function levelColor(count) {
                    if (count <= 0)
                        return Theme.withAlpha(Theme.surfaceContainerHigh, 0.5);
                    if (count >= 10)
                        return Theme.primary;
                    if (count >= 7)
                        return Theme.withAlpha(Theme.primary, 0.72);
                    if (count >= 4)
                        return Theme.withAlpha(Theme.primary, 0.45);
                    return Theme.withAlpha(Theme.primary, 0.24);
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Column {
                            spacing: 0

                            StyledText {
                                text: "GitHub"
                                font.pixelSize: Math.max(10, Math.min(Theme.fontSizeMedium, 14))
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: GitHubService.username.length > 0 ? "@" + GitHubService.username : I18n.tr("Not logged in", "github not logged in")
                                font.pixelSize: 9
                                color: Theme.surfaceTextMedium
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: "+" + GitHubService.totalContributions
                            font.pixelSize: Math.max(12, Math.min(Theme.fontSizeLarge, 16))
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.primary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                            DankIcon {
                                anchors.centerIn: parent
                                name: "edit"
                                size: 11
                                color: Theme.surfaceTextMedium
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: graph.editing = !graph.editing
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        visible: !graph.editing

                        readonly property real cellSize: {
                            const cols = 53;
                            const totalW = width - 8;
                            const totalH = height - 28;
                            return Math.max(3, Math.min(8, Math.floor(Math.min(totalW / (cols * 1.1), totalH / 9.5))));
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: Math.max(1, Math.floor(parent.cellSize * 0.28))

                            Repeater {
                                model: GitHubService.weeks

                                Column {
                                    spacing: Math.max(1, Math.floor(parent.cellSize * 0.28))

                                    Repeater {
                                        model: modelData

                                        Rectangle {
                                            width: parent.cellSize
                                            height: parent.cellSize
                                            radius: 1
                                            color: graph.levelColor(modelData)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: GitHubService.weeks.length === 0

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: GitHubService.loading ? I18n.tr("Loading...", "github loading") : (GitHubService.error.length > 0 ? GitHubService.error : I18n.tr("No data", "github no data"))
                                font.pixelSize: 10
                                color: Theme.surfaceTextMedium
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("Click edit to log in", "github login hint")
                                font.pixelSize: 9
                                color: Theme.surfaceVariantText
                                visible: !GitHubService.loading
                            }
                        }

                        Column {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: 2

                            Row {
                                spacing: 6
                                clip: true

                                Repeater {
                                    model: GitHubService.monthLabels

                                    StyledText {
                                        text: modelData
                                        font.pixelSize: 8
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                        visible: modelData.length > 0
                                    }
                                }
                            }

                            Row {
                                spacing: 3
                                anchors.right: parent.right

                                StyledText {
                                    text: "Less"
                                    font.pixelSize: 8
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Repeater {
                                    model: [0, 4, 7, 10]

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 1
                                        color: graph.levelColor(modelData)
                                    }
                                }

                                StyledText {
                                    text: "More"
                                    font.pixelSize: 8
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        spacing: 4
                        visible: graph.editing

                        DankTextField {
                            Layout.fillWidth: true
                            placeholderText: I18n.tr("Username", "github username placeholder")
                            text: graph.usernameText
                            onTextChanged: graph.usernameText = text
                            ignoreUpDownKeys: true
                        }

                        DankTextField {
                            Layout.fillWidth: true
                            placeholderText: "ghp_... (read-only token)"
                            text: graph.tokenText
                            echoMode: TextInput.Password
                            onTextChanged: graph.tokenText = text
                            ignoreUpDownKeys: true
                        }

                        Row {
                            spacing: 6

                            Button {
                                text: I18n.tr("Save", "github save")
                                onClicked: {
                                    GitHubService.saveCredentials(graph.usernameText, graph.tokenText);
                                    graph.editing = false;
                                }
                            }

                            Button {
                                text: I18n.tr("Clear", "github clear")
                                onClicked: {
                                    GitHubService.clearCredentials();
                                    graph.editing = false;
                                }
                            }
                        }
                    }
                }
            }

            // ================= MEDIA SECTION =================
            component MediaSection: Item {
                id: mediaRoot

                property MprisPlayer activePlayer: MprisController.activePlayer

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: !mediaRoot.activePlayer

                    DankIcon {
                        name: "music_note"
                        size: 22
                        color: Theme.surfaceTextSecondary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: I18n.tr("No Media Playing", "no media hint")
                        font.pixelSize: 10
                        color: Theme.surfaceTextMedium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: mediaRoot.activePlayer

                    Item {
                        width: 60
                        height: 60
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60

                        DankAlbumArt {
                            width: 52
                            height: 52
                            anchors.centerIn: parent
                            activePlayer: mediaRoot.activePlayer
                            albumSize: 48
                            animationScale: 1.05
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        StyledText {
                            text: MprisController.stableTitle || I18n.tr("Unknown")
                            font.pixelSize: Math.max(10, Math.min(Theme.fontSizeLarge, 14))
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: MprisController.stableArtist || I18n.tr("Unknown Artist")
                            font.pixelSize: 10
                            color: Theme.surfaceTextMedium
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        DankSeekbar {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            activePlayer: mediaRoot.activePlayer
                        }
                    }

                    Row {
                        spacing: 6
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            anchors.verticalCenter: playPauseButton.verticalCenter
                            color: prevArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "skip_previous"
                                size: 12
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
                            width: 30
                            height: 30
                            radius: 15
                            color: MediaAccentService.accent

                            DankIcon {
                                anchors.centerIn: parent
                                name: mediaRoot.activePlayer?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                                size: 15
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
                            width: 24
                            height: 24
                            radius: 12
                            anchors.verticalCenter: playPauseButton.verticalCenter
                            color: nextArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "skip_next"
                                size: 12
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

            // ================= CAVA BARS (24) =================
            component CavaBars: Item {
                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: CavaService.values

                        Item {
                            width: Math.max(3, Math.min(6, 200 / Math.max(1, CavaService.values.length)))
                            height: Math.min(70, parent.height * 0.85)

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                height: Math.max(2, parent.height * (modelData / 100))
                                anchors.bottom: parent.bottom
                                radius: 1.5
                                color: Theme.withAlpha(Theme.primary, 0.45 + 0.55 * (modelData / 100))
                            }
                        }
                    }
                }

                StyledText {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: CavaService.cavaAvailable ? "" : I18n.tr("cava not installed", "cava missing")
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                    visible: !CavaService.cavaAvailable
                }
            }

            // ================= AUDIO =================
            component AudioContent: Item {
                id: audioRoot

                readonly property var sink: AudioService.sink
                readonly property var audio: audioRoot.sink?.audio ?? null
                readonly property int volumePercent: audioRoot.audio ? Math.round(audioRoot.audio.volume * 100) : 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        DankIcon {
                            name: {
                                if (!audioRoot.audio || audioRoot.audio.muted || audioRoot.volumePercent === 0)
                                    return "volume_off";
                                if (audioRoot.volumePercent <= 33)
                                    return "volume_down";
                                return "volume_up";
                            }
                            size: 18
                            color: audioRoot.audio && !audioRoot.audio.muted && audioRoot.volumePercent > 0 ? Theme.primary : Theme.surfaceTextSecondary
                        }

                        StyledText {
                            text: audioRoot.volumePercent + "%"
                            font.pixelSize: Math.max(14, Math.min(Theme.fontSizeXLarge, audioRoot.height * 0.16))
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: muteArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "notifications_off"
                                size: 12
                                color: audioRoot.audio?.muted ? Theme.error : Theme.surfaceTextMedium
                            }

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (audioRoot.audio) {
                                        SessionData.suppressOSDTemporarily();
                                        audioRoot.audio.muted = !audioRoot.audio.muted;
                                    }
                                }
                            }
                        }
                    }

                    DankSlider {
                        id: volumeSlider
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        enabled: audioRoot.audio != null
                        minimum: 0
                        maximum: AudioService.sinkMaxVolume
                        showValue: true
                        unit: "%"
                        valueOverride: audioRoot.volumePercent

                        onSliderValueChanged: function (newValue) {
                            if (audioRoot.audio) {
                                SessionData.suppressOSDTemporarily();
                                audioRoot.audio.volume = newValue / 100.0;
                                if (newValue > 0 && audioRoot.audio.muted) {
                                    audioRoot.audio.muted = false;
                                }
                                AudioService.playVolumeChangeSoundIfEnabled();
                            }
                        }
                    }

                    Binding {
                        target: volumeSlider
                        property: "value"
                        value: audioRoot.audio ? Math.min(AudioService.sinkMaxVolume, Math.round(audioRoot.audio.volume * 100)) : 0
                        when: !volumeSlider.isDragging
                    }

                    StyledText {
                        text: audioRoot.sink?.name || I18n.tr("No audio device", "no audio device")
                        font.pixelSize: 9
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            // ================= GPU POWER =================
            component GpuContent: Item {
                id: gpu

                property real powerW: 0
                property real usagePct: -1
                property real tempC: 0
                property var history: []

                readonly property var gpuInfo: DgopService.availableGpus && DgopService.availableGpus.length > 0 ? DgopService.availableGpus[0] : null

                Timer {
                    id: gpuTimer
                    interval: 2000
                    repeat: true
                    running: root.visible
                    onTriggered: gpu.fetchPower()
                }

                function fetchPower() {
                    if (gpuFetcher.running)
                        return;
                    gpuFetcher.command = ["sh", "-c", "nvidia-smi --query-gpu=power.draw,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || (cat /sys/class/drm/card*/device/hwmon/hwmon*/power1_input 2>/dev/null | sort -n | tail -1) || echo 0"];
                    gpuFetcher.running = true;
                }

                Process {
                    id: gpuFetcher
                    running: false
                    command: []

                    stdout: StdioCollector {
                        onStreamFinished: gpu.parse(text)
                    }
                }

                function parse(raw) {
                    const t = raw.trim();
                    if (!t)
                        return;
                    if (t.includes(",")) {
                        const p = t.split(",");
                        gpu.powerW = parseFloat(p[0]) || 0;
                        gpu.usagePct = parseFloat(p[1]) || 0;
                        gpu.tempC = parseFloat(p[2]) || 0;
                    } else {
                        gpu.powerW = (parseFloat(t) || 0) / 1e6;
                    }
                    const h = gpu.history.slice();
                    h.push(gpu.powerW);
                    if (h.length > 40)
                        h.shift();
                    gpu.history = h;
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: gpu.powerW.toFixed(0) + " W"
                            font.pixelSize: Math.max(16, Math.min(Theme.fontSizeXLarge, gpu.height * 0.14))
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: gpu.tempC > 0 ? gpu.tempC.toFixed(0) + "°C" : ""
                            font.pixelSize: 10
                            font.family: SettingsData.monoFontFamily
                            color: gpu.tempC > 80 ? Theme.error : (gpu.tempC > 65 ? Theme.warning : Theme.surfaceVariantText)
                        }

                        StyledText {
                            text: gpu.usagePct >= 0 ? gpu.usagePct.toFixed(0) + "%" : ""
                            font.pixelSize: 10
                            font.family: SettingsData.monoFontFamily
                            color: Theme.info
                        }
                    }

                    SparkCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        value: ""
                        subtitle: gpu.gpuInfo ? (gpu.gpuInfo.displayName || gpu.gpuInfo.fullName || "GPU") : I18n.tr("No GPU info", "gpu no info")
                        accentColor: Theme.primary
                        history: gpu.history
                        maxValue: 0
                        extraInfo: gpu.gpuInfo?.vendor || ""
                    }
                }
            }

            // ================= POMODORO =================
            component PomodoroContent: Item {
                id: pomo

                property bool running: false
                property bool isBreak: false
                property int remainingSec: 25 * 60
                property int workMin: 25
                property int breakMin: 5
                property int completedRounds: 0

                readonly property int totalSec: pomo.isBreak ? pomo.breakMin * 60 : pomo.workMin * 60

                Timer {
                    id: ticker
                    interval: 1000
                    repeat: true
                    running: pomo.running
                    onTriggered: {
                        pomo.remainingSec--;
                        if (pomo.remainingSec <= 0) {
                            if (pomo.isBreak) {
                                pomo.isBreak = false;
                                pomo.remainingSec = pomo.workMin * 60;
                                ToastService.showInfo(I18n.tr("Pomodoro: work time!", "pomodoro work"));
                            } else {
                                pomo.completedRounds++;
                                pomo.isBreak = true;
                                pomo.remainingSec = pomo.breakMin * 60;
                                ToastService.showInfo(I18n.tr("Pomodoro: break time!", "pomodoro break"));
                            }
                        }
                    }
                }

                function fmt(sec) {
                    const m = Math.floor(sec / 60);
                    const s = sec % 60;
                    return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: pomo.isBreak ? I18n.tr("Break", "pomodoro break label") : I18n.tr("Focus", "pomodoro work label")
                            font.pixelSize: Math.max(10, Math.min(Theme.fontSizeMedium, 13))
                            font.weight: Font.Bold
                            color: pomo.isBreak ? Theme.success : Theme.primary
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: "🍅 x" + pomo.completedRounds
                            font.pixelSize: 9
                            color: Theme.surfaceVariantText
                            visible: pomo.completedRounds > 0
                        }
                    }

                    StyledText {
                        text: pomo.fmt(pomo.remainingSec)
                        font.pixelSize: Math.max(22, Math.min(42, pomo.height * 0.24))
                        font.family: SettingsData.monoFontFamily
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (pomo.remainingSec / Math.max(1, pomo.totalSec))))
                            height: parent.height
                            radius: 2.5
                            color: pomo.isBreak ? Theme.success : Theme.primary
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        Rectangle {
                            width: 40
                            height: 26
                            radius: 13
                            color: startArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.4) : Theme.withAlpha(Theme.primary, 0.25)

                            DankIcon {
                                anchors.centerIn: parent
                                name: pomo.running ? "pause" : "play_arrow"
                                size: 13
                                color: Theme.primary
                            }

                            MouseArea {
                                id: startArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pomo.running = !pomo.running
                            }
                        }

                        Rectangle {
                            width: 40
                            height: 26
                            radius: 13
                            color: resetArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.3)

                            DankIcon {
                                anchors.centerIn: parent
                                name: "restart_alt"
                                size: 13
                                color: Theme.surfaceTextMedium
                            }

                            MouseArea {
                                id: resetArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pomo.running = false;
                                    pomo.isBreak = false;
                                    pomo.remainingSec = pomo.workMin * 60;
                                }
                            }
                        }

                        Rectangle {
                            width: 40
                            height: 26
                            radius: 13
                            color: skipArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.3)

                            DankIcon {
                                anchors.centerIn: parent
                                name: "skip_next"
                                size: 13
                                color: Theme.surfaceTextMedium
                            }

                            MouseArea {
                                id: skipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pomo.isBreak = !pomo.isBreak;
                                    pomo.remainingSec = (pomo.isBreak ? pomo.breakMin : pomo.workMin) * 60;
                                }
                            }
                        }
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Column {
                            spacing: 0

                            StyledText {
                                text: "25m"
                                font.pixelSize: 8
                                color: pomo.workMin === 25 && !pomo.isBreak ? Theme.primary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            MouseArea {
                                width: 30
                                height: 14
                                onClicked: {
                                    pomo.workMin = 25;
                                    pomo.remainingSec = 25 * 60;
                                }
                            }
                        }

                        Column {
                            spacing: 0

                            StyledText {
                                text: "50m"
                                font.pixelSize: 8
                                color: pomo.workMin === 50 && !pomo.isBreak ? Theme.primary : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            MouseArea {
                                width: 30
                                height: 14
                                onClicked: {
                                    pomo.workMin = 50;
                                    pomo.remainingSec = 50 * 60;
                                }
                            }
                        }

                        Column {
                            spacing: 0

                            StyledText {
                                text: "5m"
                                font.pixelSize: 8
                                color: pomo.breakMin === 5 && pomo.isBreak ? Theme.success : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            MouseArea {
                                width: 30
                                height: 14
                                onClicked: pomo.breakMin = 5
                            }
                        }

                        Column {
                            spacing: 0

                            StyledText {
                                text: "10m"
                                font.pixelSize: 8
                                color: pomo.breakMin === 10 && pomo.isBreak ? Theme.success : Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            MouseArea {
                                width: 30
                                height: 14
                                onClicked: pomo.breakMin = 10
                            }
                        }
                    }
                }
            }

            // ================= MASCOT =================
            component MascotContent: Item {
                id: mascot

                property string imagePath: ""
                property string asciiArt: ""
                property bool editing: false

                readonly property string mascotPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell/mascot.json"

                FileView {
                    id: mascotFile
                    path: mascot.mascotPath
                    blockLoading: false
                    blockWrites: false

                    onLoaded: {
                        try {
                            const cfg = JSON.parse(mascotFile.text());
                            mascot.imagePath = cfg.image || "";
                            mascot.asciiArt = cfg.ascii || "";
                        } catch (e) {
                            // empty config
                        }
                    }
                }

                function save() {
                    mascotFile.setText(JSON.stringify({ "image": mascot.imagePath, "ascii": mascot.asciiArt }, null, 2));
                    mascot.editing = false;
                }

                function clearArt() {
                    mascot.imagePath = "";
                    mascot.asciiArt = "";
                    mascotFile.setText("{}");
                    mascot.editing = false;
                }

                readonly property real asciiFontSize: {
                    if (mascot.asciiArt.length === 0)
                        return 10;
                    const lines = mascot.asciiArt.split("\n");
                    let maxLen = 1;
                    for (const l of lines)
                        maxLen = Math.max(maxLen, l.length);
                    const byH = (mascot.height - 20) / Math.max(1, lines.length);
                    const byW = (mascot.width - 8) / (maxLen * 0.6);
                    return Math.max(6, Math.min(byH, byW, 24));
                }

                // ---- display ----
                Column {
                    anchors.fill: parent
                    visible: !mascot.editing
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: mascot.height - 34
                        Layout.fillHeight: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: mascot.imagePath.length > 0
                            source: mascot.imagePath
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: mascot.imagePath.length === 0 && mascot.asciiArt.length > 0
                            contentWidth: width
                            contentHeight: contentCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: contentCol
                                width: parent.width

                                Repeater {
                                    model: mascot.asciiArt.split("\n")

                                    Text {
                                        text: modelData
                                        font.family: "monospace"
                                        font.pixelSize: mascot.asciiFontSize
                                        color: Theme.primary
                                        style: Text.Raised
                                        styleColor: Theme.withAlpha(Theme.primary, 0.2)
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: mascot.imagePath.length === 0 && mascot.asciiArt.length === 0

                            DankIcon {
                                name: "pets"
                                size: 30
                                color: Theme.surfaceTextSecondary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No mascot yet", "mascot empty")
                                font.pixelSize: 10
                                color: Theme.surfaceTextMedium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Button {
                            text: mascot.imagePath.length === 0 && mascot.asciiArt.length === 0 ? I18n.tr("Set mascot", "mascot set") : I18n.tr("Edit", "mascot edit")
                            onClicked: mascot.editing = true
                        }

                        Button {
                            text: I18n.tr("Clear", "mascot clear")
                            visible: mascot.imagePath.length > 0 || mascot.asciiArt.length > 0
                            onClicked: mascot.clearArt()
                        }
                    }
                }

                // ---- edit panel ----
                ColumnLayout {
                    anchors.fill: parent
                    visible: mascot.editing
                    spacing: 4

                    StyledText {
                        text: I18n.tr("Image path (file:// or /path)", "mascot image label")
                        font.pixelSize: 9
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        Layout.fillWidth: true
                        placeholderText: "/home/user/pic.png"
                        text: mascot.imagePath
                        onTextChanged: mascot.imagePath = text
                        ignoreUpDownKeys: true
                    }

                    StyledText {
                        text: I18n.tr("or ASCII art", "mascot ascii label")
                        font.pixelSize: 9
                        color: Theme.surfaceVariantText
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
                        border.color: Theme.outlineLight
                        border.width: 1

                        TextArea {
                            id: asciiEditor
                            anchors.fill: parent
                            anchors.margins: 2
                            font.family: "monospace"
                            font.pixelSize: 10
                            color: Theme.surfaceText
                            placeholderText: I18n.tr("Type ASCII art here...", "mascot ascii placeholder")
                            text: mascot.asciiArt
                            onTextChanged: mascot.asciiArt = text
                            wrapMode: TextEdit.NoWrap
                        }
                    }

                    Row {
                        spacing: 6

                        Button {
                            text: I18n.tr("Save", "mascot save")
                            onClicked: mascot.save()
                        }

                        Button {
                            text: I18n.tr("Clear", "mascot clear")
                            onClicked: mascot.clearArt()
                        }

                        Button {
                            text: I18n.tr("Cancel", "mascot cancel")
                            onClicked: mascot.editing = false
                        }
                    }
                }
            }

            // ================= CALENDAR =================
            component CalendarGrid: Item {
                id: calRoot

                property date viewDate: new Date()
                property date selectedDate: new Date()

                readonly property var weekHeaders: ["S", "M", "T", "W", "T", "F", "S"]

                function monthGrid() {
                    const year = calRoot.viewDate.getFullYear();
                    const month = calRoot.viewDate.getMonth();
                    const first = new Date(year, month, 1);
                    const startDow = first.getDay();
                    const daysInMonth = new Date(year, month + 1, 0).getDate();
                    const prevDays = new Date(year, month, 0).getDate();
                    const cells = [];
                    for (let i = 0; i < 42; i++) {
                        const d = i - startDow + 1;
                        if (d < 1) {
                            cells.push({ "day": prevDays + d, "inMonth": false, "date": new Date(year, month - 1, prevDays + d) });
                        } else if (d > daysInMonth) {
                            cells.push({ "day": d - daysInMonth, "inMonth": false, "date": new Date(year, month + 1, d - daysInMonth) });
                        } else {
                            cells.push({ "day": d, "inMonth": true, "date": new Date(year, month, d) });
                        }
                    }
                    return cells;
                }

                function isToday(d) {
                    const t = new Date();
                    return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate();
                }

                function isSelected(d) {
                    return d.getFullYear() === calRoot.selectedDate.getFullYear() && d.getMonth() === calRoot.selectedDate.getMonth() && d.getDate() === calRoot.selectedDate.getDate();
                }

                function monthLabel() {
                    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                    return months[calRoot.viewDate.getMonth()] + " " + calRoot.viewDate.getFullYear();
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: prevMonthArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "chevron_left"
                                size: 12
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: prevMonthArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calRoot.viewDate = new Date(calRoot.viewDate.getFullYear(), calRoot.viewDate.getMonth() - 1, 1)
                            }
                        }

                        StyledText {
                            text: calRoot.monthLabel()
                            font.pixelSize: Math.max(9, Math.min(Theme.fontSizeSmall, 12))
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: nextMonthArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            DankIcon {
                                anchors.centerIn: parent
                                name: "chevron_right"
                                size: 12
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: nextMonthArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calRoot.viewDate = new Date(calRoot.viewDate.getFullYear(), calRoot.viewDate.getMonth() + 1, 1)
                            }
                        }
                    }

                    Grid {
                        Layout.fillWidth: true
                        columns: 7
                        spacing: 2

                        Repeater {
                            model: calRoot.weekHeaders

                            StyledText {
                                width: (calRoot.width - 14) / 7
                                text: modelData
                                font.pixelSize: 8
                                font.weight: Font.Medium
                                color: Theme.surfaceTextMedium
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    Grid {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        spacing: 2

                        Repeater {
                            model: calRoot.monthGrid()

                            Rectangle {
                                width: (calRoot.width - 14) / 7
                                height: Math.max(14, (calRoot.height - 52) / 6)
                                radius: 4
                                color: {
                                    if (calRoot.isSelected(modelData.date))
                                        return Theme.primary;
                                    if (calRoot.isToday(modelData.date))
                                        return Theme.withAlpha(Theme.primary, 0.35);
                                    if (!modelData.inMonth)
                                        return Theme.withAlpha(Theme.surfaceContainerHigh, 0.2);
                                    return "transparent";
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: Math.max(8, Math.min(10, parent.height * 0.35))
                                    font.family: SettingsData.monoFontFamily
                                    color: calRoot.isSelected(modelData.date) ? Theme.onPrimary : (modelData.inMonth ? Theme.surfaceText : Theme.surfaceVariantText)
                                }

                                Rectangle {
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    color: Theme.primary
                                    visible: modelData.inMonth && CalendarService.hasEventsForDate(modelData.date)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        calRoot.selectedDate = modelData.date;
                                        calRoot.viewDate = new Date(modelData.date.getFullYear(), modelData.date.getMonth(), 1);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= WEATHER CONTENT =================
            component WeatherContent: Item {
                id: wxRoot
                visible: WeatherService.weather.available || WeatherService.weather.loading
                Component.onCompleted: WeatherService.addRef()
                Component.onDestruction: WeatherService.removeRef()

                readonly property real fSize: Math.max(14, Math.min(28, wxRoot.height * 0.22))

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        DankIcon {
                            name: WeatherService.getWeatherIcon(WeatherService.weather.wCode)
                            size: Math.max(28, Math.min(52, wxRoot.height * 0.4))
                            color: Theme.primary
                        }

                        StyledText {
                            text: {
                                if (!WeatherService.weather.available) return "--";
                                const t = SettingsData.useFahrenheit ? WeatherService.weather.tempF : WeatherService.weather.temp;
                                return t + "°";
                            }
                            font.pixelSize: wxRoot.fSize
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                    }

                    StyledText {
                        text: WeatherService.weather.city || ""
                        font.pixelSize: Math.max(9, Math.min(13, wxRoot.height * 0.1))
                        color: Theme.surfaceTextMedium
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: WeatherService.weather.isDay ? I18n.tr("Feels like", "weather feels") : I18n.tr("Low", "weather low")
                            font.pixelSize: 9
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: {
                                if (!WeatherService.weather.available) return "--°";
                                const t = SettingsData.useFahrenheit ? WeatherService.weather.feelsLikeF : WeatherService.weather.feelsLike;
                                return t + "°";
                            }
                            font.pixelSize: 9
                            color: Theme.surfaceTextMedium
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: I18n.tr("Humidity", "weather humidity")
                            font.pixelSize: 9
                            color: Theme.surfaceVariantText
                        }

                        StyledText {
                            text: WeatherService.weather.humidity > 0 ? WeatherService.weather.humidity + "%" : "--"
                            font.pixelSize: 9
                            color: Theme.surfaceTextMedium
                        }
                    }
                }
            }

            // ================= MATRIX RAIN =================
            component MatrixRainContent: Item {
                id: mtxRoot

                readonly property int colCount: Math.max(8, Math.floor(mtxRoot.width / 11))
                readonly property real colW: mtxRoot.width / colCount
                readonly property int visibleRows: Math.floor(mtxRoot.height / 14)

                property var heads: []
                property var tails: []

                Timer {
                    interval: 50
                    running: mtxRoot.visible
                    repeat: true
                    onTriggered: mtxCanvas.requestPaint()
                }

                Canvas {
                    id: mtxCanvas
                    anchors.fill: parent

                    onWidthChanged: {
                        mtxRoot.heads = [];
                        mtxRoot.tails = [];
                        for (let i = 0; i < mtxRoot.colCount; i++) {
                            mtxRoot.heads.push(Math.random() * mtxRoot.visibleRows * -1);
                            mtxRoot.tails.push(Math.max(2, Math.floor(Math.random() * 3 + 3)));
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        const w = width, h = height;
                        ctx.fillStyle = "#051005";
                        ctx.fillRect(0, 0, w, h);

                        for (let i = 0; i < mtxRoot.colCount; i++) {
                            let hy = mtxRoot.heads[i];
                            hy += 0.3 + Math.random() * 0.3;
                            if (hy > mtxRoot.visibleRows + mtxRoot.tails[i])
                                hy = -mtxRoot.tails[i];
                            mtxRoot.heads[i] = hy;

                            const mid = hy;
                            const len = mtxRoot.tails[i];
                            for (let j = 0; j < len; j++) {
                                const ry = mid - j;
                                if (ry < 0)
                                    continue;
                                const cy = ry * 14;
                                const alpha = 1 - j / len;
                                if (alpha < 0.05)
                                    continue;
                                const ch = String.fromCharCode(0x30A0 + Math.floor(Math.random() * 90));
                                ctx.font = "bold 11px monospace";
                                ctx.textAlign = "center";
                                if (j === 0)
                                    ctx.fillStyle = "rgba(180,255,180," + alpha.toFixed(2) + ")";
                                else if (j === 1)
                                    ctx.fillStyle = "rgba(80,255,80," + (alpha * 0.8).toFixed(2) + ")";
                                else
                                    ctx.fillStyle = "rgba(0,180,0," + (alpha * 0.5).toFixed(2) + ")";
                                ctx.fillText(ch, i * mtxRoot.colW + mtxRoot.colW / 2, cy + 10);
                            }
                        }
                    }
                }
            }

            // ================= RAINBOW CAT =================
            component RainbowCatContent: Item {
                id: rcRoot

                property real scrollX: 0
                readonly property real rowH: Math.min(rcRoot.height / 5, 20)

                readonly property var catPixels: [
                    [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
                    [0,1,0,0,1,0,0,1,1,0,0,0,1,0,1,0],
                    [0,1,1,1,0,0,0,0,1,1,0,0,0,0,0,0],
                    [0,0,1,1,0,0,1,1,1,1,0,0,0,0,0,0],
                    [0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0],
                    [0,0,0,1,1,1,1,1,1,1,1,1,0,1,0,0],
                    [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
                    [0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0],
                    [0,0,0,1,1,1,1,0,0,1,1,1,0,0,0,0],
                    [0,0,0,1,1,1,1,0,0,1,1,1,0,0,0,0],
                    [0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0],
                    [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0]
                ]

                readonly property var catColors: ["#FFB8C6","#FFA3B5","#FF95A8","#FFC5A3","#FFA9A3","#FFA3A6","#FFA3A6","#FFA3A6","#FFA3A6","#FFA3A6","#FFA3A6","#FFA3A6"]

                Timer {
                    interval: 80
                    running: rcRoot.visible
                    repeat: true
                    onTriggered: rcCanvas.requestPaint()
                }

                Canvas {
                    id: rcCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d");
                        const w = width, h = height;
                        const t = Date.now() / 1000;

                        ctx.fillStyle = "#0a0a1a";
                        ctx.fillRect(0, 0, w, h);

                        for (let i = 0; i < 12; i++) {
                            const sy = (t * 40 + i * 28) % (h + 20) - 10;
                            ctx.fillStyle = "rgba(255,255,255," + (0.3 + Math.random() * 0.4).toFixed(2) + ")";
                            ctx.beginPath();
                            ctx.arc(i * 28 % w, sy, 1.5 + Math.random(), 0, Math.PI * 2);
                            ctx.fill();
                        }

                        rcRoot.scrollX = (rcRoot.scrollX + 2) % (w * 2);
                        const colors = ["#FF0000","#FF9900","#FFFF00","#00FF00","#0000FF","#6600FF"];
                        for (let s = 0; s < 4; s++) {
                            const sx = (rcRoot.scrollX + s * w * 0.25) % w - w * 0.25;
                            for (let i = 0; i < 6; i++) {
                                ctx.fillStyle = colors[i];
                                const ly = h * 0.6 + i * rcRoot.rowH;
                                ctx.fillRect(sx, ly, w * 0.25 + 4, rcRoot.rowH);
                            }
                        }

                        const pixelW = (w * 0.75) / 16;
                        const pixelH = (h * 0.7) / 12;
                        const catX = 8;
                        const catY = h * 0.05 + Math.sin(t * 6) * 4;

                        for (let py = 0; py < rcRoot.catPixels.length; py++) {
                            for (let px = 0; px < rcRoot.catPixels[py].length; px++) {
                                if (rcRoot.catPixels[py][px]) {
                                    ctx.fillStyle = rcRoot.catColors[py];
                                    ctx.fillRect(catX + px * pixelW, catY + py * pixelH, pixelW + 1, pixelH + 1);
                                }
                            }
                        }

                        const eyeBlink = Math.floor(t * 2) % 12 > 1;
                        ctx.fillStyle = "#000";
                        ctx.fillRect(catX + 12 * pixelW, catY + 2 * pixelH, 2, eyeBlink ? 2 : 1);
                        ctx.fillRect(catX + 13 * pixelW, catY + 2 * pixelH, 2, eyeBlink ? 2 : 1);
                    }
                }
            }

            // ================= NEWS CONTENT =================
            component NewsContent: Item {
                id: newsRoot

                readonly property string configPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell/sysmon_news.json"
                readonly property int maxItems: 8

                property var entries: []
                property string selSource: "zhihu"
                property string keywords: ""
                property int refreshInterval: 900

                FileView {
                    id: newsConfig
                    path: newsRoot.configPath
                    blockLoading: false
                    onLoaded: {
                        try {
                            const o = JSON.parse(newsConfig.text());
                            newsRoot.selSource = o.source || "zhihu";
                            newsRoot.keywords = o.keywords || "";
                            newsRoot.refreshInterval = o.interval || 900;
                        } catch (e) {}
                    }
                }
                function saveConfig() {
                    newsConfig.setText(JSON.stringify({
                        "source": newsRoot.selSource,
                        "keywords": newsRoot.keywords,
                        "interval": newsRoot.refreshInterval
                    }, null, 2));
                }

                Timer {
                    id: newsTimer
                    interval: newsRoot.refreshInterval * 1000
                    running: newsRoot.visible
                    repeat: true
                    onTriggered: newsRoot.fetch()
                }

                Component.onCompleted: { if (newsRoot.visible) newsRoot.fetch(); }
                onVisibleChanged: { if (visible && newsRoot.entries.length === 0) newsRoot.fetch(); }

                function fetch() {
                    let url, parser;
                    if (newsRoot.selSource === "baidu") {
                        url = "https://top.baidu.com/api/board?platform=wise&tab=realtime";
                        parser = baiduParser;
                    } else if (newsRoot.selSource === "hn") {
                        url = "https://hacker-news.firebaseio.com/v0/topstories.json?orderBy=%22%24key%22&limitToFirst=20";
                        parser = hnParser;
                    } else {
                        url = "https://news-at.zhihu.com/api/4/news/latest";
                        parser = zhihuParser;
                    }
                    const proc = new Process();
                    proc.command = ["curl", "-sS", "--connect-timeout", "5", "--max-time", "10",
                                     "-H", "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0",
                                     url];
                    proc.onFinished = function() {
                        let data;
                        try { data = JSON.parse(proc.stdout); } catch (e) { return; }
                        const result = parser(data);
                        if (newsRoot.keywords) {
                            const kws = newsRoot.keywords.split(",").map(function(k) { return k.trim().toLowerCase(); }).filter(function(k) { return k; });
                            const neg = kws.filter(function(k) { return k.startsWith("-"); }).map(function(k) { return k.slice(1); });
                            const pos = kws.filter(function(k) { return !k.startsWith("-"); });
                            if (pos.length > 0 || neg.length > 0) {
                                result = result.filter(function(e) {
                                    const t = e.title.toLowerCase();
                                    if (neg.some(function(n) { return t.includes(n); })) return false;
                                    if (pos.length > 0 && !pos.some(function(p) { return t.includes(p); })) return false;
                                    return true;
                                });
                            }
                        }
                        newsRoot.entries = result.slice(0, newsRoot.maxItems);
                    };
                    proc.run();
                }

                function zhihuParser(d) {
                    const stories = d.stories || [];
                    return stories.map(function(s) {
                        return { "title": s.title, "url": s.url || ("https://daily.zhihu.com/story/" + s.id) };
                    });
                }

                function baiduParser(d) {
                    const items = [];
                    const cards = (d.data && d.data.cards) || [];
                    for (const card of cards) {
                        const content = card.content || [];
                        for (const c of content) {
                            if (c.word && c.url)
                                items.push({ "title": c.word, "url": c.url });
                        }
                    }
                    return items;
                }

                function hnParser(d) {
                    const ids = (Array.isArray(d) ? d : []).slice(0, newsRoot.maxItems + 10);
                    if (ids.length === 0)
                        return [];
                    let remaining = ids.length;
                    const results = [];
                    for (let i = 0; i < Math.min(ids.length, 15); i++) {
                        const proc = new Process();
                        const itemUrl = "https://hacker-news.firebaseio.com/v0/item/" + ids[i] + ".json";
                        proc.command = ["curl", "-sS", "--connect-timeout", "3", "--max-time", "5", itemUrl];
                        const idx = i;
                        proc.onFinished = function() {
                            remaining--;
                            try {
                                const item = JSON.parse(proc.stdout);
                                if (item && item.title)
                                    results[idx] = { "title": item.title, "url": item.url || ("https://news.ycombinator.com/item?id=" + item.id) };
                            } catch (e) {}
                            if (remaining <= 0) {
                                newsRoot.entries = results.filter(function(r) { return r; }).slice(0, newsRoot.maxItems);
                            }
                        };
                        proc.run();
                    }
                    return [];
                }

                property bool showSettings: false

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label {
                            text: {
                                if (newsRoot.selSource === "baidu") return I18n.tr("Baidu Hot", "news baidu");
                                if (newsRoot.selSource === "hn") return "HN";
                                return I18n.tr("Zhihu Daily", "news zhihu");
                            }
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.info
                        }

                        Item { Layout.fillWidth: true }

                        DankIcon {
                            name: "refresh"
                            size: 14
                            color: Theme.surfaceTextMedium
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: newsRoot.fetch()
                            }
                        }

                        DankIcon {
                            name: "settings"
                            size: 14
                            color: newsRoot.showSettings ? Theme.primary : Theme.surfaceTextMedium
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: newsRoot.showSettings = !newsRoot.showSettings
                            }
                        }
                    }

                    Rectangle {
                        visible: newsRoot.showSettings
                        Layout.fillWidth: true
                        Layout.preferredHeight: 70
                        radius: 8
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
                        border.color: Theme.outlineLight
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Row {
                                spacing: 6
                                StyledText { text: I18n.tr("Source:", "news source"); font.pixelSize: 9; color: Theme.surfaceTextMedium }

                                RadioButton { id: rbZhihu; text: I18n.tr("Zhihu Daily", "news zhihu radio"); font.pixelSize: 9; checked: newsRoot.selSource === "zhihu"; onClicked: { newsRoot.selSource = "zhihu"; newsRoot.saveConfig(); newsRoot.fetch(); } }
                                RadioButton { id: rbBaidu; text: I18n.tr("Baidu", "news baidu radio"); font.pixelSize: 9; checked: newsRoot.selSource === "baidu"; onClicked: { newsRoot.selSource = "baidu"; newsRoot.saveConfig(); newsRoot.fetch(); } }
                                RadioButton { id: rbHN; text: "HN"; font.pixelSize: 9; checked: newsRoot.selSource === "hn"; onClicked: { newsRoot.selSource = "hn"; newsRoot.saveConfig(); newsRoot.fetch(); } }
                            }

                            Row {
                                spacing: 4
                                StyledText { text: I18n.tr("Keywords:", "news keywords"); font.pixelSize: 9; color: Theme.surfaceTextMedium }
                                TextField {
                                    id: kwInput
                                    width: Math.max(120, newsRoot.width * 0.5)
                                    leftPadding: 6; rightPadding: 6; topPadding: 2; bottomPadding: 2
                                    font.pixelSize: 10
                                    text: newsRoot.keywords
                                    placeholderText: I18n.tr("comma separated, -exclude", "news kw hint")
                                    onEditingFinished: { newsRoot.keywords = text; newsRoot.saveConfig(); newsRoot.fetch(); }
                                }
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 1
                        model: newsRoot.entries.length > 0 ? newsRoot.entries : [{ "title": I18n.tr("Loading...", "news loading"), "url": "" }]

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: Math.max(18, Math.min(24, newsRoot.height / newsRoot.maxItems + 2))
                            radius: 4
                            color: newsMouse.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.5) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4; anchors.rightMargin: 4
                                spacing: 4

                                StyledText {
                                    text: (index + 1) + "."
                                    font.pixelSize: 9
                                    color: Theme.surfaceVariantText
                                }

                                StyledText {
                                    text: (typeof modelData === "string") ? modelData : (modelData.title || "")
                                    font.pixelSize: 9
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: newsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (typeof modelData === "object" && modelData.url) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (typeof modelData === "object" && modelData.url) {
                                        Qt.openUrlExternally(modelData.url);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= TILES =================
            SysTile {
                id: timeTile
                tileId: "time"
                tileTitle: I18n.tr("Time", "tile time")
                tileIcon: "schedule"
                defaultCol: 0
                defaultRow: 0
                colSpan: 4
                rowSpan: 3

                AsciiClock {
                    anchors.fill: parent
                    anchors.topMargin: 4
                }
            }

            SysTile {
                id: cpuTile
                tileId: "cpu"
                tileTitle: "CPU"
                tileIcon: "memory"
                defaultCol: 4
                defaultRow: 0
                colSpan: 2
                rowSpan: 3

                SparkCard {
                    anchors.fill: parent
                    value: DgopService.cpuUsage.toFixed(1) + "%"
                    subtitle: (DgopService.cpuTemperature > 0 ? DgopService.cpuTemperature.toFixed(0) + "°C" : "") + (DgopService.cpuFrequency > 0 ? "  " + (DgopService.cpuFrequency / 1000).toFixed(2) + " GHz" : "") + (DgopService.cpuCores > 1 ? "  " + DgopService.cpuCores + "c" : "")
                    accentColor: Theme.primary
                    history: DgopService.cpuHistory
                    maxValue: 100
                    extraInfo: DgopService.cpuTemperature > 80 ? "high" : ""
                    extraInfoColor: DgopService.cpuTemperature > 80 ? Theme.error : Theme.surfaceVariantText
                }
            }

            SysTile {
                id: githubTile
                tileId: "github"
                tileTitle: "GitHub"
                tileIcon: "code"
                defaultCol: 6
                defaultRow: 0
                colSpan: 3
                rowSpan: 3

                GitHubGraph {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: mascotTile
                tileId: "mascot"
                tileTitle: I18n.tr("Mascot", "tile mascot")
                tileIcon: "pets"
                defaultCol: 0
                defaultRow: 3
                colSpan: 4
                rowSpan: 3

                MascotContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: networkTile
                tileId: "network"
                tileTitle: I18n.tr("Network", "tile network")
                tileIcon: "wifi"
                defaultCol: 4
                defaultRow: 9
                colSpan: 3
                rowSpan: 2

                SparkCard {
                    anchors.fill: parent
                    value: "↓ " + root.formatBytes(DgopService.networkRxRate) + "  ↑ " + root.formatBytes(DgopService.networkTxRate)
                    subtitle: DgopService.networkInterfaces?.length > 0 ? DgopService.networkInterfaces[0] : ""
                    accentColor: Theme.info
                    history: DgopService.networkHistory?.rx || []
                    history2: DgopService.networkHistory?.tx || []
                    maxValue: 0
                    showSecondary: true
                }
            }

            SysTile {
                id: memoryTile
                tileId: "memory"
                tileTitle: I18n.tr("Memory", "tile memory")
                tileIcon: "sd_card"
                defaultCol: 7
                defaultRow: 9
                colSpan: 3
                rowSpan: 2

                SparkCard {
                    anchors.fill: parent
                    value: DgopService.memoryUsage.toFixed(1) + "%"
                    subtitle: DgopService.formatSystemMemory(DgopService.usedMemoryKB) + " / " + DgopService.formatSystemMemory(DgopService.totalMemoryKB)
                    accentColor: Theme.warning
                    history: DgopService.memoryHistory
                    maxValue: 100
                    extraInfo: DgopService.totalSwapKB > 0 ? (DgopService.usedSwapKB > 0 ? "swap " + Math.round(DgopService.usedSwapKB / DgopService.totalSwapKB * 100) + "%" : "swap 0%") : ""
                }
            }

            SysTile {
                id: playerTile
                tileId: "player"
                tileTitle: I18n.tr("Player", "tile player")
                tileIcon: "music_note"
                defaultCol: 0
                defaultRow: 9
                colSpan: 4
                rowSpan: 2

                MediaSection {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: diskTile
                tileId: "disk"
                tileTitle: I18n.tr("Disk", "tile disk")
                tileIcon: "hard_drive"
                defaultCol: 10
                defaultRow: 9
                colSpan: 2
                rowSpan: 2

                readonly property var rootMount: {
                    const mounts = DgopService.diskMounts || [];
                    return mounts.find(m => m.mount === "/") || mounts[0] || null;
                }

                readonly property real diskPercent: {
                    if (!diskTile.rootMount || !diskTile.rootMount.percent)
                        return 0;
                    return parseFloat(diskTile.rootMount.percent.replace("%", "")) || 0;
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: I18n.tr("Root", "disk root label") + (diskTile.rootMount ? " (" + diskTile.rootMount.mount + ")" : "")
                            font.pixelSize: 9
                            color: Theme.surfaceTextMedium
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: diskTile.rootMount ? (diskTile.rootMount.used + " / " + diskTile.rootMount.size) : "--"
                            font.pixelSize: 9
                            font.family: SettingsData.monoFontFamily
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: diskTile.diskPercent.toFixed(0) + "%"
                            font.pixelSize: 10
                            font.family: SettingsData.monoFontFamily
                            font.weight: Font.Bold
                            color: diskTile.diskPercent > 85 ? Theme.error : (diskTile.diskPercent > 70 ? Theme.warning : Theme.primary)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 7
                        radius: 3.5
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)

                        Rectangle {
                            width: parent.width * (diskTile.diskPercent / 100)
                            height: parent.height
                            radius: 3.5
                            color: diskTile.diskPercent > 85 ? Theme.error : (diskTile.diskPercent > 70 ? Theme.warning : Theme.primary)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Row {
                            spacing: 5

                            DankIcon {
                                name: "download"
                                size: 12
                                color: Theme.info
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.formatBytes(DgopService.diskReadRate)
                                font.pixelSize: 10
                                font.family: SettingsData.monoFontFamily
                                color: Theme.surfaceText
                            }
                        }

                        Row {
                            spacing: 5

                            DankIcon {
                                name: "upload"
                                size: 12
                                color: Theme.warning
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.formatBytes(DgopService.diskWriteRate)
                                font.pixelSize: 10
                                font.family: SettingsData.monoFontFamily
                                color: Theme.surfaceText
                            }
                        }
                    }
                }
            }

            SysTile {
                id: audioTile
                tileId: "audio"
                tileTitle: I18n.tr("Sound", "tile sound")
                tileIcon: "volume_up"
                defaultCol: 5
                defaultRow: 11
                colSpan: 2
                rowSpan: 2

                AudioContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: cavaTile
                tileId: "cava"
                tileTitle: "Cava"
                tileIcon: "graphic_eq"
                defaultCol: 0
                defaultRow: 11
                colSpan: 5
                rowSpan: 2

                CavaBars {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: gpuTile
                tileId: "gpu"
                tileTitle: "GPU"
                tileIcon: "videocard"
                defaultCol: 7
                defaultRow: 11
                colSpan: 2
                rowSpan: 2

                GpuContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: pomoTile
                tileId: "pomodoro"
                tileTitle: I18n.tr("Pomodoro", "tile pomodoro")
                tileIcon: "timer"
                defaultCol: 9
                defaultRow: 0
                colSpan: 2
                rowSpan: 3

                PomodoroContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: sysInfoTile
                tileId: "sysinfo"
                tileTitle: I18n.tr("System Info", "tile sysinfo")
                tileIcon: "computer"
                defaultCol: 4
                defaultRow: 6
                colSpan: 3
                rowSpan: 3

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 3

                    InfoRow {
                        label: I18n.tr("System", "info system")
                        value: DgopService.distribution || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Kernel", "info kernel")
                        value: DgopService.kernelVersion || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Host", "info host")
                        value: DgopService.hostname || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Arch", "info arch")
                        value: DgopService.architecture || "--"
                    }
                    InfoRow {
                        label: "CPU"
                        value: DgopService.cpuModel || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Cores", "info cores")
                        value: DgopService.cpuCores > 0 ? String(DgopService.cpuCores) : "--"
                    }
                    InfoRow {
                        label: I18n.tr("Uptime", "info uptime")
                        value: DgopService.shortUptime || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Load", "info load")
                        value: DgopService.loadAverage || "--"
                    }
                    InfoRow {
                        label: I18n.tr("Processes", "info processes")
                        value: DgopService.processCount > 0 ? String(DgopService.processCount) : "--"
                    }
                }
            }

            SysTile {
                id: procTile
                tileId: "procs"
                tileTitle: I18n.tr("Running Processes", "tile processes")
                tileIcon: "view_list"
                defaultCol: 7
                defaultRow: 6
                colSpan: 3
                rowSpan: 3

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: I18n.tr("Top by CPU", "process sort label")
                            font.pixelSize: 9
                            color: Theme.surfaceVariantText
                            visible: root.searchText.length === 0
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        DankTextField {
                            Layout.preferredWidth: Math.max(120, Math.min(200, procTile.width * 0.3))
                            Layout.preferredHeight: Math.round(Theme.fontSizeMedium * 2.6)
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
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: DankScrollbar {
                            policy: ScrollBar.AsNeeded
                        }

                        model: root.filteredProcesses

                        delegate: Rectangle {
                            width: processList.width
                            height: Math.max(20, Math.min(26, processList.height / 9))
                            radius: 4
                            color: mouseArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 8

                                StyledText {
                                    text: modelData.pid
                                    font.pixelSize: 9
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceVariantText
                                    Layout.preferredWidth: 40
                                }

                                StyledText {
                                    text: modelData.command || "--"
                                    font.pixelSize: 9
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: (modelData.cpu || 0).toFixed(1) + "%"
                                    font.pixelSize: 9
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.info
                                    Layout.preferredWidth: 48
                                    horizontalAlignment: Text.AlignRight
                                }

                                StyledText {
                                    text: DgopService.formatSystemMemory(modelData.memoryKB || 0)
                                    font.pixelSize: 9
                                    font.family: SettingsData.monoFontFamily
                                    color: Theme.surfaceTextMedium
                                    Layout.preferredWidth: 62
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

            SysTile {
                id: calendarTile
                tileId: "calendar"
                tileTitle: I18n.tr("Calendar", "tile calendar")
                tileIcon: "calendar_month"
                defaultCol: 0
                defaultRow: 6
                colSpan: 4
                rowSpan: 3

                CalendarGrid {
                    anchors.fill: parent
                }
            }

            // ========== NEW TILES ==========
            SysTile {
                id: weatherTile
                tileId: "weather"
                tileTitle: I18n.tr("Weather", "tile weather")
                tileIcon: "cloud"
                defaultCol: 10
                defaultRow: 6
                colSpan: 2
                rowSpan: 3

                WeatherContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: cmatrixTile
                tileId: "cmatrix"
                tileTitle: I18n.tr("Matrix Rain", "tile matrix")
                tileIcon: "grid_on"
                defaultCol: 7
                defaultRow: 3
                colSpan: 2
                rowSpan: 3

                MatrixRainContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: rainbowcatTile
                tileId: "rainbowcat"
                tileTitle: I18n.tr("Nyan Cat", "tile nyan")
                tileIcon: "pets"
                defaultCol: 9
                defaultRow: 3
                colSpan: 2
                rowSpan: 3

                RainbowCatContent {
                    anchors.fill: parent
                }
            }

            SysTile {
                id: newsTile
                tileId: "news"
                tileTitle: I18n.tr("News", "tile news")
                tileIcon: "rss_feed"
                defaultCol: 4
                defaultRow: 3
                colSpan: 3
                rowSpan: 3

                NewsContent {
                    anchors.fill: parent
                }
            }
        }
    }

    // reset layout button
    Rectangle {
        anchors.top: root.top
        anchors.right: root.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 76
        height: 26
        radius: 13
        color: resetArea.containsMouse ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.color: Theme.outlineLight
        border.width: 1
        z: 200

        StyledText {
            anchors.centerIn: parent
            text: I18n.tr("Reset layout", "reset layout button")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
        }

        MouseArea {
            id: resetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.resetLayout()
        }
    }

    WindowBlur {
        targetWindow: root
        blurEnabled: Theme.blurForegroundLayers
        blurX: 0
        blurY: 0
        blurWidth: root.width
        blurHeight: root.height
        blurRadius: Theme.cornerRadius * 2
    }
}
