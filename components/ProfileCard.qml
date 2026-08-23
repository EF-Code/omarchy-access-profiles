import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: root

  property var profile: ({})
  property bool selected: false
  property color foreground: Color.foreground
  signal clicked()

  implicitWidth: Style.space(180)
  implicitHeight: Style.space(68)
  radius: Style.cornerRadius
  color: selected ? Qt.alpha(Color.accent, 0.22) : Qt.alpha(foreground, 0.06)
  border.width: selected ? 2 : 1
  border.color: selected ? Color.accent : Qt.alpha(foreground, 0.22)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(3)

    Text {
      Layout.fillWidth: true
      text: String(root.profile.name || "Profile")
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      Layout.fillWidth: true
      text: String(root.profile.description || "")
      color: Qt.alpha(root.foreground, 0.7)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
