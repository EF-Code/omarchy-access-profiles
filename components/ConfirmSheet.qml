import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string title: "Confirm"
  property string message: ""
  property color foreground: Color.foreground
  signal accepted()
  signal rejected()

  implicitHeight: content.implicitHeight + Style.space(20)
  radius: Style.cornerRadius
  color: Color.menu.background
  border.width: 1
  border.color: Color.menu.border

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(8)

    Text {
      Layout.fillWidth: true
      text: root.title
      color: root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      Layout.fillWidth: true
      text: root.message
      color: Qt.alpha(root.foreground, 0.8)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.alignment: Qt.AlignRight
      spacing: Style.space(8)

      Button {
        text: "Cancel"
        focusable: true
        onClicked: root.rejected()
      }
      Button {
        text: "Confirm"
        focusable: true
        onClicked: root.accepted()
      }
    }
  }
}
