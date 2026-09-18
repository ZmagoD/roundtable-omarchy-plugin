import QtQuick
import qs.Commons
import qs.Ui

// A table with four seats around it, drawn rather than shipped as an SVG:
// bar slots are small enough that hinting and effect rendering decide how a
// vector file lands, and this has to stay readable at eleven pixels.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property color badgeColor: Color.urgent
  property bool muted: false
  property bool waiting: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real seat: Math.max(2, iconSize * 0.19)
  readonly property real orbit: iconSize * 0.37
  readonly property real dimming: muted ? 0.45 : 1.0

  Rectangle {
    anchors.centerIn: parent
    width: root.iconSize * 0.46
    height: width
    radius: width / 2
    color: "transparent"
    border.width: Math.max(1, root.iconSize * 0.1)
    border.color: root.color
    opacity: root.dimming
  }

  Repeater {
    model: 4

    Rectangle {
      required property int index

      width: root.seat
      height: root.seat
      radius: width / 2
      color: root.color
      opacity: root.dimming
      x: root.width / 2 - width / 2 + Math.cos(index * Math.PI / 2 + Math.PI / 4) * root.orbit
      y: root.height / 2 - height / 2 + Math.sin(index * Math.PI / 2 + Math.PI / 4) * root.orbit
    }
  }

  BorderSurface {
    visible: root.waiting
    width: Math.max(7, parent.width * 0.42)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Color.popups.background, 1)
  }
}
