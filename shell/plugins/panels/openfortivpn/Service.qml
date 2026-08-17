import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property string status: "disconnected"
  property string host: ""
  property int uptimeSeconds: 0
  property bool saml: false
  property bool webviewAvailable: false
  property string configError: ""

  readonly property bool active: status === "connected" || status === "connecting"
  readonly property bool running: status === "connected"
  property bool busy: statusProc.running || upProc.running || downProc.running
  
  // optimistic state
  property int _desired: -1
  readonly property bool uiActive: _desired === -1 ? active : (_desired === 1)

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function toggle() {
    if (uiActive) down()
    else up()
  }

  function up() {
    if (upProc.running) return
    _desired = 1
    upProc.running = true
  }

  function down() {
    if (downProc.running) return
    _desired = 0
    downProc.running = true
  }

  Process {
    id: statusProc
    command: ["bash", "-c", "~/.config/omarchy/plugins/setiapam.openfortivpn/bin/omarchy-openfortivpn-status"]
    stdout: SplitParser {
      onRead: function(data) {
        try {
          var json = JSON.parse(data)
          root.status = json.status || "disconnected"
          root.host = json.host || ""
          if (json.uptimeSeconds !== null && json.uptimeSeconds !== undefined) {
             root.uptimeSeconds = json.uptimeSeconds
          }
          root.saml = json.saml || false
          root.webviewAvailable = json.webviewAvailable || false
          if (_desired !== -1 && root.active === (_desired === 1)) {
             _desired = -1
          }
        } catch (e) {}
      }
    }
    onExited: function() {
       if (root.status === "disconnected" && _desired === 0) _desired = -1
    }
  }

  Process {
    id: upProc
    command: ["bash", "-c", "~/.config/omarchy/plugins/setiapam.openfortivpn/bin/omarchy-openfortivpn-up"]
    onExited: function() { root.refresh(); _desired = -1 }
  }

  Process {
    id: downProc
    command: ["bash", "-c", "~/.config/omarchy/plugins/setiapam.openfortivpn/bin/omarchy-openfortivpn-down"]
    onExited: function() { root.refresh(); _desired = -1 }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: autostartProc
    command: ["bash", "-c", "if [[ -f ~/.config/openfortivpn/.saml_autostart ]]; then echo 'autostart'; fi"]
    stdout: SplitParser {
      onRead: function(data) {
        if (data.trim() === 'autostart') {
          root.up()
        }
      }
    }
  }

  Component.onCompleted: {
    autostartProc.running = true
  }
}
