import QtQuick
Rectangle {
    id: key
    property string label: ""
    property string icon: ""
    property bool selected: false
    property string accessibleLabel: label
    signal clicked()
    implicitWidth: content.width + 24
    implicitHeight: 34
    radius: 9
    color: selected ? Theme.accent : area.containsMouse ? Theme.hover : Theme.raised
    Behavior on color { ColorAnimation { duration: Motion.transitionMs; easing.type:Easing.BezierSpline; easing.bezierCurve:Motion.transitionCurve } }
    border.color: selected ? Theme.accent : Theme.border
    Accessible.role: Accessible.Button
    Accessible.name: accessibleLabel
    Accessible.onPressAction: clicked()
    Row {
        id:content;anchors.centerIn:parent;spacing:6
        Icon {visible:key.icon!=="";name:key.icon;width:visible?16:0;height:16;anchors.verticalCenter:parent.verticalCenter;ink:key.selected?Theme.accentInk:Theme.ink}
        Text {visible:key.label!=="";text:key.label;color:key.selected?Theme.accentInk:Theme.ink;font.pixelSize:12;anchors.verticalCenter:parent.verticalCenter}
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: key.clicked() }
}
