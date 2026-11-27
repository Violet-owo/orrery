import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root
    property string text
    property string icon
    property string kind: "tonal" // filled | tonal | text | danger
    property real iconRotation: 0
    property bool windowButton
    property bool cascade // set on buttons that stand on their own in a page
    property bool loading // working: Orrery's logo turns in place of the icon, clicks are ignored
    signal clicked

    readonly property color fg: kind === "filled" ? Theme.fgPrimary : kind === "danger" ? Theme.fgError : kind === "text" ? Theme.primary : Theme.fgSecondary

    implicitWidth: text ? content.implicitWidth + 32 : 40
    implicitHeight: 40
    radius: hover.pressed ? 10 : 20
    topLeftRadius: radius
    topRightRadius: radius
    bottomLeftRadius: radius
    bottomRightRadius: radius
    property real shade: enabled || loading ? 1 : 0.45
    opacity: shade * enter.p
    transform: Translate { y: (1 - enter.p) * 34 }
    Enter { id: enter; active: root.cascade }
    scale: hover.pressed ? 0.95 : 1
    color: kind === "filled" ? Theme.primary : kind === "danger" ? Theme.errorContainer : kind === "text" ? "transparent" : Theme.secondaryContainer

    Behavior on radius { Anim { kind: "fast" } }
    Behavior on scale { Anim { kind: "fast" } }
    Behavior on shade { Anim { kind: "fx" } }
    Behavior on implicitWidth { Anim { kind: "default" } }
    Behavior on color { CAnim {} }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 8
        OrreryLoader {
            visible: root.loading
            size: 24
            tint: root.fg
            ring: Qt.alpha(root.fg, 0.4)
        }
        Ico {
            visible: root.icon !== "" && !root.loading
            text: root.icon
            size: 20
            fill: hover.containsMouse ? 1 : 0
            color: root.fg
            rotation: root.iconRotation
            Behavior on rotation { Anim { kind: "default" } }
        }
        Txt { visible: root.text !== ""; text: root.text; color: root.fg; weight: Font.Medium }
    }
    Hover { id: hover; enabled: !root.loading; tint: root.fg; windowButton: root.windowButton; onClicked: root.clicked() }
}
