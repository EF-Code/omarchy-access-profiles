import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string message: ""
  property bool warning: false
  property color foreground: Color.foreground

  visible: message !== ""
  implicitHeight: visible ? bannerText.implicitHeight + Style.space(18) : 0
  radius: Style.cornerRadius
  color: warning ? Qt.alpha(Color.urgent, 0.16) : Qt.alpha(Color.accent, 0.14)
  border.width: 1
  border.color: warning ? Color.urgent : Color.accent

  Text {
    id: bannerText
    anchors.fill: parent
    anchors.margins: Style.space(9)
    text: root.message
    color: root.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    verticalAlignment: Text.AlignVCenter
  }
}
