import QtQuick
import QtQuick.Shapes
import qs.core

Rectangle {
    id: root
    property bool checked
    property bool held

    implicitWidth: 52
    implicitHeight: 32
    radius: 16
    color: checked ? Theme.primary : Theme.field
    border.width: checked ? 0 : 2
    border.color: Theme.outline

    Behavior on color { CAnim {} }

    Rectangle {
        id: thumb
        property real d: root.held ? 28 : root.checked ? 24 : 16
        property real stretch: root.held ? 4 : 0
        width: d + stretch
        height: d
        radius: d / 2
        y: (parent.height - d) / 2
        x: root.checked ? parent.width - width - (parent.height - d) / 2 : (parent.height - d) / 2
        color: root.checked ? Theme.fgPrimary : Theme.outline

        Behavior on x { Anim { kind: "fast" } }
        Behavior on d { Anim { kind: "fast" } }
        Behavior on stretch { Anim { kind: "fast" } }
        Behavior on color { CAnim {} }

        // The check mark draws itself
        Shape {
            anchors.centerIn: parent
            width: 14
            height: 14
            opacity: root.checked ? 1 : 0
            preferredRendererType: Shape.CurveRenderer
            Behavior on opacity { Anim { kind: "fx" } }
            ShapePath {
                id: tick
                property real t: root.checked ? 1 : 0
                Behavior on t { Anim { kind: "decel" } }
                strokeColor: Theme.primary
                strokeWidth: 2.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 2
                startY: 7.5
                PathLine { x: 2 + 3.5 * Math.min(1, tick.t * 2); y: 7.5 + 3.5 * Math.min(1, tick.t * 2) }
                PathLine { x: 2 + 3.5 * Math.min(1, tick.t * 2) + 6.5 * Math.max(0, tick.t * 2 - 1); y: 7.5 + 3.5 * Math.min(1, tick.t * 2) - 7.5 * Math.max(0, tick.t * 2 - 1) }
            }
        }
    }
}
