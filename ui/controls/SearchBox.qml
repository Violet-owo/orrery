import QtQuick
import qs.core

Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    signal down
    signal accepted

    implicitHeight: 56
    radius: 28
    color: input.activeFocus ? Theme.field : Qt.alpha(Theme.surface, 0.55)
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.primary : Theme.outlineVariant
    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }

    Ico {
        id: lens
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
        text: "search"
        color: input.activeFocus ? Theme.primary : Theme.fgVariant
        scale: input.activeFocus ? 1.1 : 1
        Behavior on scale { Anim { kind: "fast" } }
    }
    TextInput {
        id: input
        anchors { left: lens.right; right: clear.left; leftMargin: 12; rightMargin: 6; verticalCenter: parent.verticalCenter }
        color: Theme.fg
        selectionColor: Theme.primary
        selectedTextColor: Theme.fgPrimary
        font.family: Theme.font
        font.pixelSize: 16
        clip: true
        activeFocusOnTab: true
        Keys.onDownPressed: root.down()
        Keys.onEscapePressed: e => { if (text) text = ""; else e.accepted = false; }
        onAccepted: root.accepted()
        Txt { visible: !input.text; text: I18n.tr("Search settings"); size: 16; color: Theme.fgVariant }
    }
    Btn {
        id: clear
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        icon: "close"
        kind: "text"
        visible: input.text !== ""
        onClicked: { input.text = ""; input.forceActiveFocus(); }
    }
    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onPressed: input.forceActiveFocus() }
}
