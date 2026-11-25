import QtQuick
import qs.core

Tile {
    id: root
    property real value
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix
    readonly property real shownValue: drag.pressed ? drag.live : value
    signal moved(real value)

    Item {
        id: bar
        implicitWidth: 240
        implicitHeight: 40
        readonly property bool navigable: true
        function nudge(by: real): void {
            const v = Math.round(Math.max(root.from, Math.min(root.to, root.value + by)) * 1000) / 1000;
            if (v !== root.value)
                root.moved(v);
        }
        activeFocusOnTab: true
        Keys.onLeftPressed: nudge(-root.step)
        Keys.onRightPressed: nudge(root.step)
        Keys.onPressed: e => {
            if (e.modifiers & Qt.ControlModifier)
                return;
            if (e.key === Qt.Key_Home) root.moved(root.from);
            else if (e.key === Qt.Key_End) root.moved(root.to);
            else return;
            e.accepted = true;
        }
        Ring { on: bar.activeFocus && Nav.keys; corner: 12 }
        property real pos: (Math.min(root.to, Math.max(root.from, root.shownValue)) - root.from) / (root.to - root.from)
        property real gap: drag.pressed ? 4 : 6
        Behavior on pos { Anim { kind: drag.pressed ? "fx" : "default" } }
        Behavior on gap { Anim { kind: "fast" } }

        // M3 slider: active and inactive tracks part around the handle
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, handle.x - bar.gap)
            height: drag.pressed ? 18 : 16
            topLeftRadius: 8; bottomLeftRadius: 8; topRightRadius: 3; bottomRightRadius: 3
            color: Theme.primary
            Behavior on height { Anim { kind: "fast" } }
            Behavior on color { CAnim {} }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: handle.x + handle.width + bar.gap
            width: Math.max(0, parent.width - x)
            height: drag.pressed ? 18 : 16
            topRightRadius: 8; bottomRightRadius: 8; topLeftRadius: 3; bottomLeftRadius: 3
            color: Theme.secondaryContainer
            Behavior on height { Anim { kind: "fast" } }
            Behavior on color { CAnim {} }
        }
        Rectangle {
            id: handle
            width: drag.pressed ? 3 : 5
            height: drag.pressed ? 40 : drag.containsMouse ? 36 : 32
            radius: 3
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * bar.pos))
            Behavior on width { Anim { kind: "fast" } }
            Behavior on height { Anim { kind: "fast" } }
        }
        Rectangle {
            readonly property real grow: drag.pressed ? 1 : 0
            x: handle.x + handle.width / 2 - width / 2
            y: -height + 2 - 6 * scale
            width: bubble.implicitWidth + 22
            height: 30
            radius: 15
            color: Theme.fg
            transformOrigin: Item.Bottom
            scale: grow
            opacity: grow
            visible: opacity > 0
            z: 5
            Behavior on scale { Anim { kind: "fast" } }
            Behavior on opacity { Anim { kind: "fx" } }
            Txt { id: bubble; anchors.centerIn: parent; text: root.shownValue + root.suffix; color: Theme.surface; weight: Font.Medium; size: 13 }
        }
        MouseArea {
            id: drag
            property real live
            function at(x: real): real {
                const v = root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from);
                return Math.round(Math.round(v / root.step) * root.step * 1000) / 1000;
            }
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: e => { Nav.keys = false; bar.forceActiveFocus(Qt.MouseFocusReason); live = at(e.x); }
            onPositionChanged: e => { if (pressed) live = at(e.x); }
            onReleased: root.moved(live)
        }
    }
    Txt {
        text: root.shownValue + root.suffix
        horizontalAlignment: Text.AlignRight
        width: 56
        color: Theme.primary
        weight: Font.Medium
    }
}
