import QtQuick

Item {
  id: root

  property string label: ""
  property bool checked: false
  property string fontFamily: ""
  property color textColor: "#ffffff"
  property color accentColor: "#ffffff"

  signal toggled(bool checked)

  implicitHeight: 40

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: 12
  }

  Rectangle {
    id: pill
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 34
    height: 20
    radius: 10
    color: root.checked
      ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.9)
      : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.16)

    Behavior on color {
      ColorAnimation { duration: 160 }
    }

    Rectangle {
      width: 14
      height: 14
      radius: 7
      y: 3
      x: root.checked ? pill.width - width - 3 : 3
      color: root.checked ? root.accentColor : root.textColor

      Behavior on x {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }
}
