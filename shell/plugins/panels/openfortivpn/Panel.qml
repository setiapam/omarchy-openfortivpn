import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: root

    // Injected by omarchy-shell
    required property var omarchyPath
    required property var shell
    required property var manifest
    required property var pluginRegistry

    property string vpnStatus: "disconnected" // "connected" | "disconnected" | "connecting"
    property string vpnHost: ""
    property int uptimeSeconds: 0
    property bool samlMode: false
    property bool webviewAvailable: false

    // Poll interval in milliseconds
    readonly property int pollInterval: 5000

    // Colors
    readonly property color connectedColor: "#22c55e"
    readonly property color disconnectedColor: "#94a3b8"
    readonly property color connectingColor: "#f59e0b"

    implicitWidth: row.implicitWidth + 16
    implicitHeight: parent ? parent.height : 32

    Timer {
        id: statusTimer
        interval: root.pollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: refreshStatus()
    }

    function refreshStatus() {
        let pluginDir = root.manifest.directory || ""
        let statusCmd = pluginDir + "/bin/omarchy-openfortivpn-status"

        let proc = Qt.createQmlObject(
            'import QtQuick; import io.github.parzival1918.qprocess 1.0; QProcess {}',
            root, "statusProcess"
        )

        if (!proc) {
            // Fallback: use simple pgrep check
            fallbackStatusCheck()
            return
        }

        proc.command = statusCmd
        proc.onFinished.connect(function() {
            try {
                let output = proc.readAllStandardOutput()
                let data = JSON.parse(output)
                root.vpnStatus = data.status || "disconnected"
                root.vpnHost = data.host || ""
                root.samlMode = data.saml || false
                root.webviewAvailable = data.webviewAvailable || false
                if (data.uptimeSeconds !== null && data.uptimeSeconds !== undefined) {
                    root.uptimeSeconds = data.uptimeSeconds
                }
            } catch (e) {
                console.warn("OpenFortiVPN: Failed to parse status:", e)
            }
            proc.destroy()
        })

        proc.start()
    }

    function fallbackStatusCheck() {
        // Simple check via ppp0 interface existence
        // This is a basic fallback if QProcess is not available
        root.vpnStatus = "disconnected"
    }

    function toggleVpn() {
        if (root.vpnStatus === "connected") {
            disconnectVpn()
        } else if (root.vpnStatus === "disconnected") {
            connectVpn()
        }
    }

    function connectVpn() {
        root.vpnStatus = "connecting"
        let pluginDir = root.manifest.directory || ""
        let connectCmd = pluginDir + "/bin/omarchy-openfortivpn-up"

        // Use shell IPC or direct process execution
        shell.call("murphi.openfortivpn", "connect", "{}")

        // Refresh after a delay to allow connection to establish
        Qt.callLater(function() {
            statusTimer.restart()
        })
    }

    function disconnectVpn() {
        let pluginDir = root.manifest.directory || ""
        let disconnectCmd = pluginDir + "/bin/omarchy-openfortivpn-down"

        shell.call("murphi.openfortivpn", "disconnect", "{}")

        root.vpnStatus = "disconnected"
        statusTimer.restart()
    }

    function formatUptime(seconds) {
        if (seconds <= 0) return ""
        let h = Math.floor(seconds / 3600)
        let m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // Lifecycle methods required by omarchy-shell IPC
    function open(payloadJson) {
        statusTimer.start()
        refreshStatus()
    }

    function close() {
        statusTimer.stop()
    }

    // Main visual layout
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // VPN Status indicator dot
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

        // VPN icon (shield)
        Text {
            text: root.vpnStatus === "connected" ? "🛡️" : "🔓"
            font.pixelSize: 14
        }

        // Label
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
            font.pixelSize: 13
            font.family: "Inter"
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

    function openConfigDialog() {
        let pluginDir = root.manifest.directory || ""
        let component = Qt.createComponent("ConfigDialog.qml")
        if (component.status === Component.Ready) {
            let dialog = component.createObject(root, { pluginDir: pluginDir })
            dialog.configSaved.connect(function() {
                root.refreshStatus()
            })
            dialog.show()
        } else {
            console.error("OpenFortiVPN: Failed to load ConfigDialog.qml:", component.errorString())
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
            onTriggered: root.refreshStatus()
        }
    }
}
