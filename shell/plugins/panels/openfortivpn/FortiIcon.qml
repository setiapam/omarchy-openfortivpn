import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool active: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Text {
    anchors.centerIn: parent
    text: root.active ? "\uf3ed" : "\uf3c1"
    color: root.color
    font.family: Style.font.family
    font.pixelSize: root.iconSize
  }
}
