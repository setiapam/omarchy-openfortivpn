import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

Window {
    id: configWindow
    title: "OpenFortiVPN Settings"
    width: 480
    height: 560
    minimumWidth: 440
    minimumHeight: 520
    color: "#1e1e2e"

    signal configSaved()

    property string pluginDir: ""

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

    Component.onCompleted: {
        loadConfig()
    }

    Process {
        id: readProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    let data = JSON.parse(text)
                    configWindow.host = data.host || ""
                    configWindow.port = data.port || "443"
                    configWindow.isSaml = data.saml || false
                    configWindow.username = data.username || ""
                    configWindow.password = data.password || ""
                    configWindow.realm = data.realm || ""
                    configWindow.trustedCert = data.trustedCert || ""
                } catch (e) {
                    console.warn("OpenFortiVPN: Failed to parse config JSON:", e)
                }
            }
        }
    }

    Process {
        id: saveProc
        onExited: {
            notifyProc.running = true
            configWindow.configSaved()
            configWindow.close()
        }
    }

    Process {
        id: notifyProc
        command: ["notify-send", "-a", "OpenFortiVPN", "-i", "network-vpn", "Configuration Saved", "VPN configuration updated successfully."]
    }

    Process {
        id: tempWriteProc
        onExited: {
            startCertFetch()
        }
    }

    Process {
        id: fetchCertProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                configWindow.isFetchingCert = false
                try {
                    let res = JSON.parse(text)
                    if (res.status === "success" && res.digest) {
                        configWindow.trustedCert = res.digest
                        configWindow.certStatusMsg = "✓ Certificate digest retrieved!"
                    } else {
                        configWindow.certStatusMsg = res.message || "Failed to fetch certificate."
                    }
                } catch (e) {
                    configWindow.certStatusMsg = "Failed to parse certificate hash output."
                }
            }
        }
    }

    function loadConfig() {
        readProc.command = ["bash", "-c", pluginDir + "/bin/omarchy-openfortivpn-config read-all"]
        readProc.running = true
    }

    function saveConfig() {
        saveProc.command = [
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
        saveProc.running = true
    }

    function fetchCertHash() {
        if (!hostInput.text.trim()) {
            certStatusMsg = "Please enter Gateway Host first!"
            return
        }

        tempWriteProc.command = [
            pluginDir + "/bin/omarchy-openfortivpn-config",
            "write-all",
            hostInput.text.trim(),
            portInput.text.trim(),
            "", "", "", "false", ""
        ]
        tempWriteProc.running = true
    }

    function startCertFetch() {
        isFetchingCert = true
        certStatusMsg = "Probing gateway for certificate..."

        fetchCertProc.command = [
            pluginDir + "/bin/omarchy-openfortivpn-config",
            "fetch-cert"
        ]
        fetchCertProc.running = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Title Header
        RowLayout {
            spacing: 10
            Text {
                text: "🛡️"
                font.pixelSize: 22
            }
            Text {
                text: "FortiVPN Configuration"
                color: "#cdd6f4"
                font.pixelSize: 18
                font.bold: true
                font.family: "Inter"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#313244"
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 14

                // Gateway Host & Port
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Gateway Host"; color: "#a6adc8"; font.pixelSize: 12 }
                        TextField {
                            id: hostInput
                            Layout.fillWidth: true
                            text: configWindow.host
                            placeholderText: "vpn.company.com"
                            color: "#cdd6f4"
                            background: Rectangle { color: "#181825"; radius: 6; border.color: hostInput.activeFocus ? "#89b4fa" : "#313244" }
                        }
                    }

                    ColumnLayout {
                        width: 90
                        spacing: 4
                        Text { text: "Port"; color: "#a6adc8"; font.pixelSize: 12 }
                        TextField {
                            id: portInput
                            Layout.fillWidth: true
                            text: configWindow.port
                            placeholderText: "443"
                            color: "#cdd6f4"
                            background: Rectangle { color: "#181825"; radius: 6; border.color: portInput.activeFocus ? "#89b4fa" : "#313244" }
                        }
                    }
                }

                // SAML Authentication Switch
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    color: "#181825"
                    radius: 8
                    border.color: "#313244"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10

                        ColumnLayout {
                            spacing: 2
                            Text { text: "SAML / SSO Authentication"; color: "#cdd6f4"; font.pixelSize: 13; font.bold: true }
                            Text { text: "Browser login (Azure AD, Okta, etc.)"; color: "#a6adc8"; font.pixelSize: 11 }
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: samlSwitch
                            checked: configWindow.isSaml
                        }
                    }
                }

                // Password Auth Fields (Hidden if SAML is enabled)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: !samlSwitch.checked

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Username"; color: "#a6adc8"; font.pixelSize: 12 }
                        TextField {
                            id: userInput
                            Layout.fillWidth: true
                            text: configWindow.username
                            color: "#cdd6f4"
                            background: Rectangle { color: "#181825"; radius: 6; border.color: userInput.activeFocus ? "#89b4fa" : "#313244" }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Password"; color: "#a6adc8"; font.pixelSize: 12 }
                        TextField {
                            id: passInput
                            Layout.fillWidth: true
                            text: configWindow.password
                            echoMode: TextInput.Password
                            color: "#cdd6f4"
                            background: Rectangle { color: "#181825"; radius: 6; border.color: passInput.activeFocus ? "#89b4fa" : "#313244" }
                        }
                    }
                }

                // Custom Realm
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Realm (Optional)"; color: "#a6adc8"; font.pixelSize: 12 }
                    TextField {
                        id: realmInput
                        Layout.fillWidth: true
                        text: configWindow.realm
                        placeholderText: "e.g. custom-realm"
                        color: "#cdd6f4"
                        background: Rectangle { color: "#181825"; radius: 6; border.color: realmInput.activeFocus ? "#89b4fa" : "#313244" }
                    }
                }

                // Trusted Certificate Fingerprint
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Trusted Certificate Hash (SHA256)"; color: "#a6adc8"; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: configWindow.isFetchingCert ? "Fetching..." : "Fetch Cert"
                            enabled: !configWindow.isFetchingCert
                            onClicked: fetchCertHash()
                            background: Rectangle {
                                color: parent.down ? "#45475a" : "#313244"
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "#89b4fa"
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    TextField {
                        id: certInput
                        Layout.fillWidth: true
                        text: configWindow.trustedCert
                        placeholderText: "64-character SHA256 hash"
                        color: "#cdd6f4"
                        font.pixelSize: 11
                        background: Rectangle { color: "#181825"; radius: 6; border.color: certInput.activeFocus ? "#89b4fa" : "#313244" }
                    }

                    Text {
                        text: configWindow.certStatusMsg
                        color: configWindow.certStatusMsg.startsWith("✓") ? "#a6e3a1" : "#f38ba8"
                        font.pixelSize: 11
                        visible: configWindow.certStatusMsg !== ""
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#313244"
        }

        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Item { Layout.fillWidth: true }

            Button {
                text: "Cancel"
                onClicked: configWindow.close()
                background: Rectangle { color: "#313244"; radius: 6 }
                contentItem: Text { text: "Cancel"; color: "#cdd6f4"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
            }

            Button {
                text: "Save Configuration"
                onClicked: saveConfig()
                background: Rectangle { color: "#89b4fa"; radius: 6 }
                contentItem: Text { text: "Save Configuration"; color: "#11111b"; font.pixelSize: 13; font.bold: true; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }
}
