import QtQuick
import qs.core

// Focus ring, only while the keyboard is in use
Rectangle {
    id: root
    property bool on
    property real corner: 0
    anchors.fill: parent
    anchors.margins: on ? -3 : 4
    z: 20
    color: "transparent"
    radius: corner + 3
    border.width: 3
    border.color: Theme.primary
    opacity: on ? 1 : 0
    visible: opacity > 0
    Behavior on anchors.margins { Anim { kind: "fast" } }
    Behavior on opacity { Anim { kind: "fx" } }
}
