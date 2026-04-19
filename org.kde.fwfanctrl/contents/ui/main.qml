import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Qt5Compat.GraphicalEffects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── State ──────────────────────────────────────────────────────────────
    property string currentProfile: "unknown"
    property var availableProfiles: []
    property bool loading: true
    property string errorMessage: ""
    property var statusInfo: null
    property var profileInfo: null
    property bool serviceActive: true

    // ── Refresh interval: driven by user configuration ────────────────────
    property int refreshInterval: Plasmoid.configuration.pollingInterval * 1000

    // ── Tint color for error / paused states (error takes priority) ──────
    property color iconTint: {
        if (root.errorMessage !== "") return Kirigami.Theme.negativeTextColor
        if (!root.serviceActive) return Kirigami.Theme.neutralTextColor
        return "transparent"
    }

    // ── Tooltip & icon (must live on the root PlasmoidItem) ───────────────
    Plasmoid.icon: Qt.resolvedUrl("../icons/framework.svg")
    toolTipMainText: "Framework Fan Control"
    toolTipSubText: root.loading
        ? "Loading…"
        : root.errorMessage !== ""
            ? "Error: " + root.errorMessage
            : "Profile: " + root.currentProfile + (root.statusInfo ? "\nFan speed: " + root.statusInfo.speed + "%" : "")

    // ── Compact (tray icon) representation ────────────────────────────────
    compactRepresentation: Item {
        id: compactRoot

        implicitWidth:  Kirigami.Units.iconSizes.small
        implicitHeight: Kirigami.Units.iconSizes.small

        Kirigami.Icon {
                id: compactIcon
                source: Qt.resolvedUrl("../icons/framework.svg")
                anchors.centerIn: parent
                width:  Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                layer.enabled: root.iconTint !== "transparent"
            }

        ColorOverlay {
            anchors.fill: compactIcon
            source: compactIcon
            color: root.iconTint
            visible: root.iconTint !== "transparent"
        }

        // Left-click opens the popup; right-click is handled automatically
        // by contextualActions below.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.expanded = !root.expanded
        }
    }

    // ── Full (popup) representation ───────────────────────────────────────
    fullRepresentation: PlasmaExtras.Representation {
        id: fullRep

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    id: headerIcon
                    source: Qt.resolvedUrl("../icons/framework.svg")
                    width:  Kirigami.Units.iconSizes.medium
                    height: Kirigami.Units.iconSizes.medium
                    layer.enabled: root.iconTint !== "transparent"
                }

                ColorOverlay {
                    anchors.fill: headerIcon
                    source: headerIcon
                    color: root.iconTint
                    visible: root.iconTint !== "transparent"
                }

                PlasmaExtras.Heading {
                    text: root.loading ? "Loading…" : "Active profile: " + root.currentProfile
                    level: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.BusyIndicator {
                    visible: root.loading
                    width:  Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: {
                        root.loading = true
                        root.errorMessage = ""
                        refreshAll()
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: "Refresh"
                }

                PlasmaComponents.ToolButton {
                    icon.name: "edit-undo"
                    enabled: !root.loading
                    onClicked: {
                        root.loading = true
                        root.errorMessage = ""
                        executable.exec("fw-fanctrl reset")
                        if (Plasmoid.configuration.autoClose) {
                            root.expanded = false
                        }
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: "Reset to default profile"
                }
            }
        }

        contentItem: Item {
            implicitWidth: Kirigami.Units.gridUnit * 16
            implicitHeight: contentCol.implicitHeight + Kirigami.Units.largeSpacing * 2

            ColumnLayout {
                id: contentCol
                anchors {
                    left:   parent.left
                    right:  parent.right
                    top:    parent.top
                    margins: Kirigami.Units.largeSpacing
                }
                spacing: Kirigami.Units.smallSpacing

                // Error banner
                PlasmaComponents.Label {
                    visible: root.errorMessage !== ""
                    text: "⚠ " + root.errorMessage
                    color: Kirigami.Theme.negativeTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Tab bar
                PlasmaComponents.TabBar {
                    id: tabBar
                    Layout.fillWidth: true

                    PlasmaComponents.TabButton {
                        text: "Fan Profiles"
                    }
                    PlasmaComponents.TabButton {
                        text: "Profile Details"
                    }
                    PlasmaComponents.TabButton {
                        text: "Status"
                    }
                }

                // Tab content
                StackLayout {
                    Layout.fillWidth: true
                    currentIndex: tabBar.currentIndex

                    // ── Tab 0: Available Profiles ─────────────────────────
                    ColumnLayout {
                        spacing: 0

                        PlasmaComponents.Label {
                            visible: root.availableProfiles.length === 0 && !root.loading
                            text: "No profiles found."
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: root.availableProfiles

                            delegate: PlasmaComponents.ItemDelegate {
                                Layout.fillWidth: true
                                text: modelData
                                icon.name: modelData === root.currentProfile ? "dialog-ok-apply" : ""
                                highlighted: modelData === root.currentProfile
                                enabled: !root.loading

                                onClicked: {
                                    if (modelData !== root.currentProfile) {
                                        applyProfile(modelData)
                                        if (Plasmoid.configuration.autoClose) {
                                            root.expanded = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Tab 1: Profile Details ────────────────────────────
                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            visible: root.profileInfo === null && !root.loading
                            text: "No profile details available."
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }

                        GridLayout {
                            visible: root.profileInfo !== null
                            columns: 2
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: Kirigami.Units.smallSpacing
                            Layout.fillWidth: true

                            PlasmaComponents.Label { text: "Profile"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.currentProfile }

                            PlasmaComponents.Label { text: "Update frequency"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.profileInfo ? root.profileInfo.fanSpeedUpdateFrequency + " s" : "" }

                            PlasmaComponents.Label { text: "Moving avg interval"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.profileInfo ? root.profileInfo.movingAverageInterval + " s" : "" }
                        }

                        // ── Speed curve chart ─────────────────────────────
                        Canvas {
                            id: speedCurveCanvas
                            visible: root.profileInfo !== null && root.profileInfo.speedCurve !== undefined
                            Layout.fillWidth: true
                            height: Kirigami.Units.gridUnit * 9

                            // ── Shared layout/range properties ────────────
                            property real padL: 42
                            property real padR: 10
                            property real padT: 10
                            property real padB: 28
                            property real chartMaxTemp: 60

                            // Coordinate helpers shared with MouseArea
                            function px(temp)  { return padL + (temp  / chartMaxTemp) * (width  - padL - padR) }
                            function py(speed) { return padT + (1 - speed / 100)      * (height - padT - padB) }

                            // Repaint whenever profileInfo changes
                            Connections {
                                target: root
                                function onProfileInfoChanged() {
                                    if (root.profileInfo && root.profileInfo.speedCurve) {
                                        var maxT = 60
                                        var curve = root.profileInfo.speedCurve
                                        for (var i = 0; i < curve.length; i++) {
                                            if (curve[i].temp > maxT) maxT = curve[i].temp
                                        }
                                        speedCurveCanvas.chartMaxTemp = maxT
                                    }
                                    speedCurveCanvas.requestPaint()
                                }
                            }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)

                                if (!root.profileInfo || !root.profileInfo.speedCurve) return
                                var curve = root.profileInfo.speedCurve
                                if (curve.length < 2) return

                                var cw = width  - padL - padR
                                var ch = height - padT - padB

                                // ── Color helpers (theme-aware) ──────────
                                var textCol  = Kirigami.Theme.textColor
                                var gridCol  = Qt.rgba(
                                    Kirigami.Theme.textColor.r,
                                    Kirigami.Theme.textColor.g,
                                    Kirigami.Theme.textColor.b, 0.15)
                                var lineCol  = Kirigami.Theme.highlightColor
                                var fillCol  = Qt.rgba(
                                    Kirigami.Theme.highlightColor.r,
                                    Kirigami.Theme.highlightColor.g,
                                    Kirigami.Theme.highlightColor.b, 0.25)

                                // ── Grid lines (25 / 50 / 75 / 100 %) ────
                                ctx.strokeStyle = gridCol
                                ctx.lineWidth = 1
                                ;[25, 50, 75, 100].forEach(function(pct) {
                                    var y = py(pct)
                                    ctx.beginPath()
                                    ctx.moveTo(padL, y)
                                    ctx.lineTo(padL + cw, y)
                                    ctx.stroke()
                                })

                                // ── Axes ──────────────────────────────────
                                ctx.strokeStyle = textCol
                                ctx.lineWidth = 1
                                ctx.beginPath()
                                ctx.moveTo(padL, padT)
                                ctx.lineTo(padL, padT + ch)
                                ctx.lineTo(padL + cw, padT + ch)
                                ctx.stroke()

                                // ── Filled area ───────────────────────────
                                ctx.fillStyle = fillCol
                                ctx.beginPath()
                                ctx.moveTo(px(curve[0].temp), py(curve[0].speed))
                                for (var i = 1; i < curve.length; i++) {
                                    ctx.lineTo(px(curve[i].temp), py(curve[i].speed))
                                }
                                ctx.lineTo(px(curve[curve.length - 1].temp), padT + ch)
                                ctx.lineTo(px(curve[0].temp), padT + ch)
                                ctx.closePath()
                                ctx.fill()

                                // ── Line ──────────────────────────────────
                                ctx.strokeStyle = lineCol
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                ctx.moveTo(px(curve[0].temp), py(curve[0].speed))
                                for (var i = 1; i < curve.length; i++) {
                                    ctx.lineTo(px(curve[i].temp), py(curve[i].speed))
                                }
                                ctx.stroke()

                                // ── Data point dots ───────────────────────
                                ctx.fillStyle = lineCol
                                for (var i = 0; i < curve.length; i++) {
                                    ctx.beginPath()
                                    ctx.arc(px(curve[i].temp), py(curve[i].speed), 3, 0, Math.PI * 2)
                                    ctx.fill()
                                }

                                // ── Y-axis labels (0, 50, 100 %) ─────────
                                ctx.fillStyle = textCol
                                ctx.font = "10px sans-serif"
                                ctx.textAlign = "right"
                                ctx.textBaseline = "middle"
                                ;[[0, "0%"], [50, "50%"], [100, "100%"]].forEach(function(pair) {
                                    ctx.fillText(pair[1], padL - 4, py(pair[0]))
                                })

                                // ── X-axis labels (6 evenly spaced points) ──
                                ctx.textAlign = "center"
                                ctx.textBaseline = "top"
                                var numXLabels = 6
                                for (var j = 0; j <= numXLabels; j++) {
                                    var t = Math.round(chartMaxTemp * j / numXLabels)
                                    ctx.fillText(t + "°", px(t), padT + ch + 4)
                                }
                            }

                            // ── Hover tooltip ─────────────────────────────
                            MouseArea {
                                id: chartMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton

                                property int hoveredIndex: -1

                                onPositionChanged: function(mouse) {
                                    if (!root.profileInfo || !root.profileInfo.speedCurve) {
                                        hoveredIndex = -1
                                        return
                                    }
                                    var curve = root.profileInfo.speedCurve
                                    var best = -1
                                    var bestDist = 12 * 12  // snap radius in pixels²
                                    for (var i = 0; i < curve.length; i++) {
                                        var dx = mouse.x - speedCurveCanvas.px(curve[i].temp)
                                        var dy = mouse.y - speedCurveCanvas.py(curve[i].speed)
                                        var dist = dx * dx + dy * dy
                                        if (dist < bestDist) {
                                            bestDist = dist
                                            best = i
                                        }
                                    }
                                    hoveredIndex = best
                                }

                                onExited: hoveredIndex = -1

                                QQC2.ToolTip {
                                    visible: chartMouseArea.hoveredIndex >= 0
                                    x: chartMouseArea.hoveredIndex >= 0
                                        ? speedCurveCanvas.px(root.profileInfo.speedCurve[chartMouseArea.hoveredIndex].temp) - width / 2
                                        : 0
                                    y: chartMouseArea.hoveredIndex >= 0
                                        ? speedCurveCanvas.py(root.profileInfo.speedCurve[chartMouseArea.hoveredIndex].speed) - height - 6
                                        : 0
                                    text: {
                                        if (chartMouseArea.hoveredIndex < 0) return ""
                                        var pt = root.profileInfo.speedCurve[chartMouseArea.hoveredIndex]
                                        return pt.temp + " °C  —  " + pt.speed + "%"
                                    }
                                }
                            }
                        }
                    }

                    // ── Tab 2: Status ─────────────────────────────────────
                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents.Label {
                            visible: root.statusInfo === null && !root.loading
                            text: "No status available."
                            color: Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }

                        GridLayout {
                            visible: root.statusInfo !== null
                            columns: 2
                            columnSpacing: Kirigami.Units.largeSpacing
                            rowSpacing: Kirigami.Units.smallSpacing
                            Layout.fillWidth: true

                            PlasmaComponents.Label { text: "Fan speed"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? root.statusInfo.speed + "%" : "" }

                            PlasmaComponents.Label { text: "Temperature"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? root.statusInfo.temperature + " °C" : "" }

                            PlasmaComponents.Label { text: "Moving average"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? root.statusInfo.movingAverageTemperature + " °C" : "" }

                            PlasmaComponents.Label { text: "Effective temp"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? root.statusInfo.effectiveTemperature + " °C" : "" }

                            PlasmaComponents.Label { text: "Service active"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? (root.statusInfo.active ? "Yes" : "No") : "" }

                            PlasmaComponents.Label { text: "Is default"; color: Kirigami.Theme.disabledTextColor }
                            PlasmaComponents.Label { text: root.statusInfo ? (root.statusInfo.default ? "Yes" : "No") : "" }
                        }
                    }
                }
            }
        }
    }

    // ── Context-menu actions (right-click on tray icon) ───────────────────
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Refresh"
            icon.name: "view-refresh"
            onTriggered: {
                root.loading = true
                root.errorMessage = ""
                refreshAll()
            }
        },
        PlasmaCore.Action {
            text: "Reload Configuration"
            icon.name: "document-revert"
            onTriggered: executable.exec("fw-fanctrl reload")
        },
        PlasmaCore.Action {
            text: "Pause Service"
            icon.name: "media-playback-pause"
            onTriggered: executable.exec("fw-fanctrl pause")
        },
        PlasmaCore.Action {
            text: "Resume Service"
            icon.name: "media-playback-start"
            onTriggered: executable.exec("fw-fanctrl resume")
        }
    ]

    // The profile actions are added dynamically once the profile list loads.
    // See updateContextMenu() below.

    // ── Executable data source ────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var stdout = (data["stdout"] || "").trim()
            var stderr = (data["stderr"] || "").trim()
            var exitCode = data["exit code"] !== undefined ? data["exit code"] : 0

            executable.disconnectSource(sourceName)

            if (sourceName.indexOf("print list") !== -1) {
                handleListOutput(stdout, stderr, exitCode)
            } else if (sourceName.indexOf("JSON print\"") !== -1
                       || sourceName.slice(-5) === "print") {
                handleStatusOutput(stdout, stderr, exitCode)
            } else if (sourceName.indexOf("fw-fanctrl pause") !== -1
                       || sourceName.indexOf("fw-fanctrl resume") !== -1) {
                executable.exec("fw-fanctrl --output-format JSON print")
            } else if (sourceName.indexOf("fw-fanctrl use ") !== -1) {
                handleUseOutput(sourceName, stdout, stderr, exitCode)
            } else if (sourceName.indexOf("fw-fanctrl reset") !== -1) {
                handleUseOutput(sourceName, stdout, stderr, exitCode)
                executable.exec("fw-fanctrl --output-format JSON print")
            }
        }

        function exec(cmd) {
            connectSource(cmd)
        }
    }

    // ── Command handlers ──────────────────────────────────────────────────

    function handleListOutput(stdout, stderr, exitCode) {
        if (exitCode !== 0 || stdout === "") {
            root.errorMessage = stderr !== "" ? stderr : "fw-fanctrl print list failed (exit " + exitCode + ")"
            root.loading = false
            return
        }

        // fw-fanctrl --output-format JSON print list returns e.g.
        // {"strategies": ["balanced", "lazy", "agressive", "medium", "pause"]}
        try {
            var result = JSON.parse(stdout)
            if (!result.strategies || !Array.isArray(result.strategies)) {
                root.errorMessage = "fw-fanctrl print list: unexpected format (missing 'strategies' array)"
                root.loading = false
                return
            }
            root.availableProfiles = result.strategies
        root.errorMessage = ""
        } catch (e) {
            root.errorMessage = "fw-fanctrl print list: JSON parse error: " + e.message
            root.loading = false
            return
        }
        updateContextMenu()
        root.loading = false
    }

    function handleUseOutput(sourceName, stdout, stderr, exitCode) {
        if (exitCode !== 0) {
            root.errorMessage = stderr !== ""
                ? stderr
                : "Failed to apply profile (exit " + exitCode + ")"
            root.loading = false
            return
        }
        // Re-query to confirm the active profile and update status
        executable.exec("fw-fanctrl --output-format JSON print")
    }

    function handleStatusOutput(stdout, stderr, exitCode) {
        if (exitCode !== 0 || stdout === "") {
            root.errorMessage = stderr !== "" ? stderr : "fw-fanctrl print failed (exit " + exitCode + ")"
            root.loading = false
            return
        }
        try {
            var result = JSON.parse(stdout)
            if (typeof result.strategy === "string") {
                root.currentProfile = result.strategy
            }
            root.serviceActive = result.active === true
            root.errorMessage = ""
            root.statusInfo = {
                speed:                    result.speed,
                temperature:              result.temperature,
                movingAverageTemperature: result.movingAverageTemperature,
                effectiveTemperature:     result.effectiveTemperature,
                active:                   result.active,
                "default":                result["default"]
            }
            try {
                var strategies = result.configuration.data.strategies
                if (strategies && strategies[result.strategy]) {
                    root.profileInfo = strategies[result.strategy]
                }
            } catch (pe) {
                root.profileInfo = null
            }
        } catch (e) {
            root.errorMessage = "fw-fanctrl print: JSON parse error: " + e.message
        }
        root.loading = false
        updateContextMenu()
    }

    // ── Context menu updater ──────────────────────────────────────────────
    // Plasma 6 does not allow truly dynamic actions lists from QML easily,
    // so we expose the profile switching through the full popup instead.
    // The context menu gets static Refresh + header + a note to open popup.
    function updateContextMenu() {
        // No-op: dynamic context-menu actions in Plasma 6 require C++ or
        // a scripting approach; profile selection is in the full popup.
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    function applyProfile(profile) {
        root.loading = true
        root.errorMessage = ""
        // 'use' just performs the action; no --output-format needed
        executable.exec("fw-fanctrl use " + profile)
    }

    function refreshAll() {
        executable.exec("fw-fanctrl --output-format JSON print list")
        executable.exec("fw-fanctrl --output-format JSON print")
    }

    // ── Polling timer ─────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: {
            // Silent refresh (don't set loading=true so UI doesn't flicker)
            executable.exec("fw-fanctrl --output-format JSON print")
        }
    }

    // ── Initialise on component ready ─────────────────────────────────────
    Component.onCompleted: {
        refreshAll()
    }
}
