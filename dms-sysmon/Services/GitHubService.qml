pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property var log: Log.scoped("GitHubService")

    property string username: ""
    property string token: ""
    property bool loading: false
    property string error: ""
    property bool hasCachedData: false
    property int totalContributions: 0
    property var weeks: []
    property var monthLabels: []
    property date lastUpdated

    readonly property string configPath: Paths.strip(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/DankMaterialShell/github.json"
    readonly property string cachePath: Paths.strip(StandardPaths.writableLocation(StandardPaths.CacheLocation)) + "/dankmaterialshell/github_contributions.json"

    readonly property bool configured: username.length > 0 && token.length > 0

    property int lastFetchTime: 0

    function saveCredentials(u, t) {
        username = u.trim();
        token = t.trim();
        configFile.setText(JSON.stringify({ "username": root.username, "token": root.token }, null, 2));
        root.refresh();
    }

    function clearCredentials() {
        username = "";
        token = "";
        weeks = [];
        monthLabels = [];
        totalContributions = 0;
        hasCachedData = false;
        error = "";
        configFile.setText("");
    }

    function refresh() {
        if (!root.configured) {
            return;
        }
        if (fetcher.running) {
            return;
        }
        const now = Date.now();
        if (now - root.lastFetchTime < 30000) {
            return;
        }
        root.lastFetchTime = now;

        const query = "query { user(login: \"" + root.username + "\") { contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount } } } } } }";
        fetcher.command = [
            "curl", "-sS", "--fail", "--connect-timeout", "5", "--max-time", "15",
            "-H", "Authorization: Bearer " + root.token,
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({ "query": query }),
            "https://api.github.com/graphql"
        ];
        root.loading = true;
        root.error = "";
        fetcher.running = true;
    }

    function parseResponse(raw) {
        root.loading = false;
        try {
            const json = JSON.parse(raw);
            if (json.errors && json.errors.length > 0) {
                root.error = json.errors[0].message || "GitHub API error";
                return;
            }
            const cal = json.data?.user?.contributionsCollection?.contributionCalendar;
            if (!cal) {
                root.error = "Unexpected GitHub response";
                return;
            }

            const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            const cols = [];
            const months = [];
            let lastDayMonth = -1;

            for (const week of cal.weeks) {
                const col = [];
                for (const day of week.contributionDays) {
                    col.push(day.contributionCount);
                }
                cols.push(col);

                const firstDay = new Date(week.contributionDays[0].date + "T00:00:00");
                const firstMonth = firstDay.getMonth();
                const lastDay = new Date(week.contributionDays[week.contributionDays.length - 1].date + "T00:00:00");
                const lastMonth = lastDay.getMonth();

                if (firstMonth !== lastMonth && lastDayMonth === firstMonth) {
                    months.push(monthNames[firstMonth]);
                    months.push(monthNames[lastMonth]);
                } else if (firstMonth !== lastMonth) {
                    months.push(monthNames[lastMonth]);
                } else if (lastDayMonth !== firstMonth) {
                    months.push(monthNames[firstMonth]);
                } else {
                    months.push("");
                }
                lastDayMonth = lastMonth;
            }

            root.weeks = cols;
            root.monthLabels = months;
            root.totalContributions = cal.totalContributions || 0;
            root.hasCachedData = true;
            root.lastUpdated = new Date();
            root.error = "";

            cacheFile.setText(JSON.stringify({
                "weeks": root.weeks,
                "monthLabels": root.monthLabels,
                "totalContributions": root.totalContributions,
                "lastUpdated": root.lastUpdated.toISOString()
            }, null, 2));
        } catch (e) {
            root.error = String(e.message || e);
        }
    }

    Process {
        id: fetcher
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                root.parseResponse(text);
            }
        }

        onExited: exitCode => {
            root.loading = false;
            if (exitCode !== 0 && !root.hasCachedData) {
                root.error = I18n.tr("Failed to reach GitHub API", "github fetch failure");
            }
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        blockLoading: false
        blockWrites: false

        onLoaded: {
            try {
                const cfg = JSON.parse(configFile.text());
                root.username = cfg.username || "";
                root.token = cfg.token || "";
            } catch (e) {
                // Empty or invalid config; treat as not configured
            }
        }
    }

    FileView {
        id: cacheFile
        path: root.cachePath
        blockLoading: false
        blockWrites: false

        onLoaded: {
            try {
                const cache = JSON.parse(cacheFile.text());
                root.weeks = cache.weeks || [];
                root.monthLabels = cache.monthLabels || [];
                root.totalContributions = cache.totalContributions || 0;
                root.hasCachedData = (cache.weeks && cache.weeks.length > 0) || false;
                root.lastUpdated = cache.lastUpdated ? new Date(cache.lastUpdated) : new Date();
            } catch (e) {
                // Corrupt cache; ignore
            }
        }
    }

    Timer {
        id: autoRefresh
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.refresh();
    }
}
