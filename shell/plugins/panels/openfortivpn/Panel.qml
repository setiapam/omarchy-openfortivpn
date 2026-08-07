import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "murphi.openfortivpn"
  ipcTarget: "murphi.openfortivpn"
  manageIpc: false

  property string focusSection: "header"
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  
  readonly property color barIconColor: vpn.uiActive ? (bar ? "#22c55e" : "#22c55e") : Qt.darker(foreground, 1.55)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    vpn.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: vpn
  }
  
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { vpn.refresh(); return "ok" }
    function toggleVpn(): string { vpn.toggle(); return "ok" }
  }

  property var configDialog: null

  function openConfig() {
    if (configDialog) {
      configDialog.show()
      configDialog.raise()
      configDialog.requestActivate()
      return
    }
    var comp = Qt.createComponent("ConfigDialog.qml")
    if (comp.status === Component.Ready) {
      configDialog = comp.createObject(null, { pluginDir: "~/.config/omarchy/plugins/murphi.openfortivpn" })
      configDialog.show()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: vpn.uiActive ? "🔒" : "🔓"
    foreground: root.barIconColor
    
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) vpn.toggle()
      else if (buttonCode === Qt.MiddleButton) vpn.refresh()
      else root.toggle()
    }
    
    SequentialAnimation on opacity {
      running: vpn.status === "connecting" || vpn.status === "disconnecting"
      loops: Animation.Infinite
      NumberAnimation { to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy > 0 && root.focusSection === "header") root.focusSection = "config"
        else if (dy < 0 && root.focusSection === "config") root.focusSection = "header"
      }
      onActivateRequested: {
        if (root.cursorActive) {
          if (root.focusSection === "header") vpn.toggle()
          else if (root.focusSection === "config") { root.openConfig(); root.close() }
        }
      }
      onCloseRequested: root.close()

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            readonly property bool ringVisible: root.cursorActive && root.focusSection === "header"
            function focusHero() { root.cursorActive = true; root.focusSection = "header" }

            PanelHero {
              id: hero
              width: parent.width
              title: vpn.host !== "" ? vpn.host : "OpenFortiVPN"
              meta: vpn.uiActive ? "VPN Connected" : "VPN Disconnected"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: vpn.uiActive ? 1.0 : 0.5
              
              iconComponent: Component {
                OpticalGlyph {
                  text: vpn.uiActive ? "🔒" : "🔓"
                  fontSize: Style.font.display
                  color: vpn.uiActive ? "#22c55e" : root.dim
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  checked: vpn.uiActive
                  busy: vpn.busy || vpn.status === "connecting"
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: vpn.toggle()
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            
            CursorSurface {
              width: parent.width
              implicitHeight: configRow.implicitHeight + Style.spacing.rowPaddingX
              hasCursor: root.cursorActive && root.focusSection === "config"
              foreground: root.foreground
              
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.cursorActive = true; root.focusSection = "config" }
                onClicked: { root.openConfig(); root.close() }
              }
              
              RowLayout {
                id: configRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(10)

                Text {
                  text: "\uf013"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.icon
                  Layout.alignment: Qt.AlignVCenter
                }
                
                Text {
                  Layout.fillWidth: true
                  text: "Settings..."
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
              }
            }
          }
        }
      }
    }
  }
}
