import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "murphi.openfortivpn"

    property string vpnStatus: "disconnected"
    property string vpnHost: ""
    property int uptimeSeconds: 0

    readonly property color connectedColor: "#22c55e"
    readonly property color disconnectedColor: Qt.darker(barForeground, 1.55)
    readonly property color connectingColor: "#f59e0b"
    readonly property color barForeground: bar ? bar.foreground : Color.foreground

    visible: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Process {
        id: statusProc
        command: ["bash", "-c", "~/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-status"]
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    var json = JSON.parse(data)
                    root.vpnStatus = json.status || "disconnected"
                    root.vpnHost = json.host || ""
                    if (json.uptimeSeconds !== null && json.uptimeSeconds !== undefined) {
                        root.uptimeSeconds = json.uptimeSeconds
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: connectProc
        command: ["bash", "-c", "~/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-up"]
        onExited: function(exitCode) {
            statusTimer.restart()
        }
    }

    Process {
        id: disconnectProc
        command: ["bash", "-c", "~/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-down"]
        onExited: function(exitCode) {
            root.vpnStatus = "disconnected"
            statusTimer.restart()
        }
    }

    Timer {
        id: statusTimer
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProc.running) statusProc.running = true
        }
    }

    function toggleVpn() {
        if (root.vpnStatus === "connected") {
            if (!disconnectProc.running) disconnectProc.running = true
        } else if (root.vpnStatus === "disconnected") {
            root.vpnStatus = "connecting"
            if (!connectProc.running) connectProc.running = true
        }
    }

    function formatUptime(seconds) {
        if (seconds <= 0) return ""
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    BarIconButton {
        id: row
        anchors.fill: parent
        bar: root.bar
        text: root.vpnStatus === "connected" ? "\uf3ed" : "\uf3c1"
        slotSize: Style.bar.statusSlot
        textColor: root.vpnStatus === "connected" ? root.connectedColor
                 : root.vpnStatus === "connecting" ? root.connectingColor
                 : root.barForeground
        onTapped: root.toggleVpn()

        SequentialAnimation on opacity {
            running: root.vpnStatus === "connecting"
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
    }
}
