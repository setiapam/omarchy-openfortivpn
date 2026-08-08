import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

ColumnLayout {
    id: configPanel
    
    signal closeRequested()
    signal configSaved()

    property string pluginDir: ""
    
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.55)
    property string fontFamily: Style.font.family

    // Form Properties
    property string host: ""
    property string port: "443"
    property bool isSaml: false
    property string username: ""
    property string password: ""
    property string realm: ""
    property string trustedCert: ""
    property bool isFetchingCert: false
    property string certStatusMsg: ""

    spacing: Style.space(12)

    Component.onCompleted: loadConfig()

    Process {
        id: readProc
        command: ["bash", "-c", pluginDir + "/bin/omarchy-openfortivpn-config read-all"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    configPanel.host = data.host || ""
                    configPanel.port = data.port || "443"
                    configPanel.isSaml = data.saml || false
                    configPanel.username = data.username || ""
                    configPanel.password = data.password || ""
                    configPanel.realm = data.realm || ""
                    configPanel.trustedCert = data.trustedCert || ""
                } catch (e) {
                    console.warn("OpenFortiVPN: Failed to parse config JSON:", e)
                }
            }
        }
    }

    Process {
        id: saveProc
        command: [
            pluginDir + "/bin/omarchy-openfortivpn-config",
            "write-all",
            hostInput.text.trim(),
            portInput.text.trim(),
            userInput.text.trim(),
            passInput.text,
            realmInput.text.trim(),
            samlSwitch.checked ? "true" : "false",
            certInput.text.trim()
        ]
        onExited: {
            notifyProc.running = true
            configPanel.configSaved()
            configPanel.closeRequested()
        }
    }

    Process {
        id: notifyProc
        command: ["notify-send", "-a", "OpenFortiVPN", "-i", "network-vpn", "Configuration Saved", "VPN configuration updated successfully."]
    }

    Process {
        id: tempWriteProc
        command: [
            pluginDir + "/bin/omarchy-openfortivpn-config",
            "write-all",
            hostInput.text.trim(),
            portInput.text.trim(),
            "", "", "", "false", ""
        ]
        onExited: startCertFetch()
    }

    Process {
        id: fetchCertProc
        command: [pluginDir + "/bin/omarchy-openfortivpn-config", "fetch-cert"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                configPanel.isFetchingCert = false
                try {
                    let res = JSON.parse(text)
                    if (res.status === "success" && res.digest) {
                        configPanel.trustedCert = res.digest
                        configPanel.certStatusMsg = "✓ Certificate digest retrieved!"
                    } else {
                        configPanel.certStatusMsg = res.message || "Failed to fetch certificate."
                    }
                } catch (e) {
                    configPanel.certStatusMsg = "Failed to parse certificate hash output."
                }
            }
        }
    }

    function loadConfig() { readProc.running = true }
    function saveConfig() { saveProc.running = true }
    function fetchCertHash() {
        if (!hostInput.text.trim()) {
            certStatusMsg = "Please enter Gateway Host first!"
            return
        }
        tempWriteProc.running = true
    }
    function startCertFetch() {
        isFetchingCert = true
        certStatusMsg = "Probing gateway for certificate..."
        fetchCertProc.running = true
    }

    // A reusable styled TextField for the panel
    component FormField: TextField {
        id: field
        Layout.fillWidth: true
        color: configPanel.foreground
        font.family: configPanel.fontFamily
        font.pixelSize: Style.font.body
        implicitHeight: Style.space(32)
        leftPadding: Style.space(8)
        rightPadding: Style.space(8)
        background: Rectangle {
            color: "transparent"
            border.color: field.activeFocus ? configPanel.foreground : configPanel.dim
            border.width: 1
            radius: Math.round(Style.radius.panel * 0.6)
        }
    }

    PanelSectionHeader {
        Layout.fillWidth: true
        text: "GATEWAY"
        foreground: configPanel.foreground
        fontFamily: configPanel.fontFamily
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Text { text: "Host"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
            FormField { id: hostInput; text: configPanel.host; placeholderText: "vpn.company.com" }
        }

        ColumnLayout {
            width: Style.space(70)
            spacing: Style.space(4)
            Text { text: "Port"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
            FormField { id: portInput; text: configPanel.port; placeholderText: "443" }
        }
    }

    PanelSectionHeader {
        Layout.fillWidth: true
        text: "AUTHENTICATION"
        foreground: configPanel.foreground
        fontFamily: configPanel.fontFamily
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Use SAML / SSO"
            color: configPanel.foreground
            font.family: configPanel.fontFamily
            font.pixelSize: Style.font.body
            Layout.fillWidth: true
        }
        ToggleSwitch {
            id: samlSwitch
            checked: configPanel.isSaml
            foreground: configPanel.foreground
            onToggled: configPanel.isSaml = !configPanel.isSaml
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(12)
        visible: !samlSwitch.checked

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Text { text: "Username"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
            FormField { id: userInput; text: configPanel.username }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Text { text: "Password"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
            FormField { id: passInput; text: configPanel.password; echoMode: TextInput.Password }
        }
    }

    PanelSectionHeader {
        Layout.fillWidth: true
        text: "ADVANCED"
        foreground: configPanel.foreground
        fontFamily: configPanel.fontFamily
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        Text { text: "Realm (Optional)"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
        FormField { id: realmInput; text: configPanel.realm; placeholderText: "e.g. custom-realm" }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Trusted Certificate (SHA256)"; color: configPanel.dim; font.family: configPanel.fontFamily; font.pixelSize: 11 }
            Item { Layout.fillWidth: true }
            
            CursorSurface {
                implicitWidth: fetchText.implicitWidth + Style.space(16)
                implicitHeight: fetchText.implicitHeight + Style.space(8)
                foreground: configPanel.foreground
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.hasCursor = true
                    onExited: parent.hasCursor = false
                    onClicked: fetchCertHash()
                }
                Text {
                    id: fetchText
                    anchors.centerIn: parent
                    text: configPanel.isFetchingCert ? "Fetching..." : "Fetch"
                    color: configPanel.foreground
                    font.family: configPanel.fontFamily
                    font.pixelSize: 11
                }
            }
        }

        FormField { id: certInput; text: configPanel.trustedCert; placeholderText: "64-character SHA256 hash"; font.pixelSize: 11 }

        Text {
            text: configPanel.certStatusMsg
            color: configPanel.certStatusMsg.startsWith("✓") ? Color.ok : Color.urgent
            font.family: configPanel.fontFamily
            font.pixelSize: Style.font.sub
            visible: configPanel.certStatusMsg !== ""
        }
    }

    Item { Layout.fillWidth: true; implicitHeight: Style.space(8) }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        CursorSurface {
            Layout.fillWidth: true
            implicitHeight: Style.space(32)
            foreground: configPanel.foreground
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: parent.hasCursor = true
                onExited: parent.hasCursor = false
                onClicked: saveConfig()
            }
            Text {
                anchors.centerIn: parent
                text: "Save Configuration"
                color: configPanel.foreground
                font.family: configPanel.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
            }
        }
    }
}
