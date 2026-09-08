import QtQuick
import QtQuick.Controls

Flickable {
    id: root
    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    clip: true
}
