import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "murphi.openfortivpn"

    property string vpnStatus: "disconnected" // "connected" | "disconnected" | "connecting"
    property string vpnHost: ""
    property int uptimeSeconds: 0
    property bool samlMode: false
    property bool webviewAvailable: false

    property var omarchyPath
    property var shell
    property var manifest
    property var pluginRegistry

    // Colors
    readonly property color connectedColor: "#22c55e"
    readonly property color disconnectedColor: "#94a3b8"
    readonly property color connectingColor: "#f59e0b"

    implicitWidth: row.implicitWidth + 12
    implicitHeight: parent ? parent.height : 30

    Process {
        id: statusProc
        command: ["/home/murphi/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-status"]
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    let json = JSON.parse(data)
                    root.vpnStatus = json.status || "disconnected"
                    root.vpnHost = json.host || ""
                    root.samlMode = json.saml || false
                    root.webviewAvailable = json.webviewAvailable || false
                    if (json.uptimeSeconds !== null && json.uptimeSeconds !== undefined) {
                        root.uptimeSeconds = json.uptimeSeconds
                    }
                } catch (e) {
                    console.warn("OpenFortiVPN status JSON parse error:", e)
                }
            }
        }
    }

    Process {
        id: connectProc
        command: ["/home/murphi/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-up"]
        onExited: function(exitCode) {
            statusTimer.restart()
        }
    }

    Process {
        id: disconnectProc
        command: ["/home/murphi/.config/omarchy/plugins/murphi.openfortivpn/bin/omarchy-openfortivpn-down"]
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
            disconnectVpn()
        } else {
            connectVpn()
        }
    }

    function connectVpn() {
        root.vpnStatus = "connecting"
        if (!connectProc.running) connectProc.running = true
    }

    function disconnectVpn() {
        if (!disconnectProc.running) disconnectProc.running = true
    }

    function formatUptime(seconds) {
        if (seconds <= 0) return ""
        let h = Math.floor(seconds / 3600)
        let m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function openConfigDialog() {
        let pluginDir = "/home/murphi/.config/omarchy/plugins/murphi.openfortivpn"
        let component = Qt.createComponent("ConfigDialog.qml")
        if (component.status === Component.Ready) {
            let dialog = component.createObject(root, { pluginDir: pluginDir })
            dialog.configSaved.connect(function() {
                if (!statusProc.running) statusProc.running = true
            })
            dialog.show()
        } else {
            console.error("OpenFortiVPN: Failed to load ConfigDialog.qml:", component.errorString())
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: {
                switch (root.vpnStatus) {
                    case "connected": return root.connectedColor
                    case "connecting": return root.connectingColor
                    default: return root.disconnectedColor
                }
            }

            SequentialAnimation on opacity {
                running: root.vpnStatus === "connecting"
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            }
        }

        Text {
            text: root.vpnStatus === "connected" ? "🛡️" : "🔓"
            font.pixelSize: 13
        }

        Text {
            text: {
                switch (root.vpnStatus) {
                    case "connected":
                        let label = "VPN"
                        if (root.vpnHost) label += " · " + root.vpnHost
                        let uptime = root.formatUptime(root.uptimeSeconds)
                        if (uptime) label += " · " + uptime
                        return label
                    case "connecting":
                        return "VPN Connecting..."
                    default:
                        return "VPN Off"
                }
            }
            color: root.vpnStatus === "connected" ? root.connectedColor : "#cbd5e1"
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            } else {
                root.toggleVpn()
            }
        }
    }

    Menu {
        id: contextMenu

        MenuItem {
            text: root.vpnStatus === "connected" ? "Disconnect VPN" : "Connect VPN"
            onTriggered: root.toggleVpn()
        }

        MenuSeparator {}

        MenuItem {
            text: "⚙️ VPN Settings..."
            onTriggered: root.openConfigDialog()
        }

        MenuItem {
            text: "SAML Mode: " + (root.samlMode ? "Enabled" : "Disabled")
            enabled: false
        }

        MenuItem {
            text: "Refresh Status"
            onTriggered: {
                if (!statusProc.running) statusProc.running = true
            }
        }
    }
}
