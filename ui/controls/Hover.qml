import QtQuick
import QtQuick.Shapes
import qs.core

// State layer + ripple + click handling, following its parent's corners.
Item {
    id: root

    property alias containsMouse: mouse.containsMouse
    property alias pressed: mouse.pressed
    property color tint: Theme.fg
    readonly property bool navigable: true
    property bool windowButton
    property var onDelete: null // Delete key
    signal clicked

    readonly property real tl: parent?.topLeftRadius ?? 0
    readonly property real tr: parent?.topRightRadius ?? 0
    readonly property real bl: parent?.bottomLeftRadius ?? 0
    readonly property real br: parent?.bottomRightRadius ?? 0
    property real px
    property real py
    property real circle: 0
    readonly property real reach: Math.sqrt(Math.max(px, width - px) ** 2 + Math.max(py, height - py) ** 2) * 1.25

    function ripple(x: real, y: real): void {
        px = x;
        py = y;
        fade.stop();
        ink.opacity = 0.12;
        circle = 0;
        grow.restart();
    }

    anchors.fill: parent
    activeFocusOnTab: enabled
    Keys.onReturnPressed: { ripple(width / 2, height / 2); clicked(); }
    Keys.onEnterPressed: { ripple(width / 2, height / 2); clicked(); }
    Keys.onDeletePressed: e => { if (onDelete) onDelete(); else e.accepted = false; }
    Keys.onSpacePressed: { ripple(width / 2, height / 2); clicked(); }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.tl
        topRightRadius: root.tr
        bottomLeftRadius: root.bl
        bottomRightRadius: root.br
        color: root.tint
        opacity: !root.enabled ? 0 : root.activeFocus && Nav.keys ? 0.1 : mouse.containsMouse ? 0.08 : 0
        Behavior on opacity { Anim { kind: "fx" } }
    }

    Ring { on: root.activeFocus && Nav.keys; corner: Math.max(root.tl, root.bl) }

    Shape {
        id: ink
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.px
                centerY: root.py
                focalX: root.px
                focalY: root.py
                centerRadius: Math.max(1, root.circle)
                GradientStop { position: 0; color: root.tint }
                GradientStop { position: 0.85; color: root.tint }
                GradientStop { position: 1; color: Qt.alpha(root.tint, root.circle >= root.reach * 0.98 ? 1 : 0) }
            }
            PathRectangle {
                width: root.width
                height: root.height
                topLeftRadius: root.tl
                topRightRadius: root.tr
                bottomLeftRadius: root.bl
                bottomRightRadius: root.br
            }
        }
    }
    Anim {
        id: grow
        target: root
        property: "circle"
        to: root.reach
        kind: "decel"
        duration: 520 * Theme.animScale
        onFinished: if (!mouse.pressed) fade.restart()
    }
    Anim { id: fade; target: ink; property: "opacity"; to: 0; kind: "fxSlow" }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: e => {
            Nav.keys = false;
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.ripple(e.x, e.y);
        }
        onReleased: if (!grow.running) fade.restart()
        onCanceled: fade.restart()
        onClicked: root.clicked()
    }
}
