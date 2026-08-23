import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string status: "supported"
  property string label: ""
  property color foreground: Color.foreground

  implicitWidth: badgeText.implicitWidth + Style.space(16)
  implicitHeight: Math.max(Style.space(28), badgeText.implicitHeight + Style.space(8))
  radius: Style.cornerRadius
  color: root.status === "supported" || root.status === "ready"
    ? Qt.alpha(Color.accent, 0.18)
    : Qt.alpha(Color.urgent, 0.16)
  border.width: 1
  border.color: root.status === "supported" || root.status === "ready" ? Color.accent : Color.urgent

  Text {
    id: badgeText
    anchors.centerIn: parent
    text: root.label || (root.status === "supported" ? "Supported" : root.status)
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
