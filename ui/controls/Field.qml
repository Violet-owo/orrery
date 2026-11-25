import QtQuick
import qs.core

Rectangle {
    id: root
    property string value
    property string placeholder
    property bool mono
    signal commit(string value)

    implicitWidth: 260
    implicitHeight: 40
    radius: input.activeFocus ? 20 : 12
    color: hover.hovered || input.activeFocus ? Qt.alpha(Theme.field, Math.min(1, Theme.field.a + 0.2)) : Theme.field
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.primary

    Behavior on radius { Anim { kind: "fast" } }
    Behavior on color { CAnim {} }
    HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

    TextInput {
        id: input
        readonly property bool navigable: true
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        text: root.value
        color: Theme.fg
        selectionColor: Theme.primary
        selectedTextColor: Theme.fgPrimary
        font.family: root.mono ? Theme.mono : Theme.font
        font.pixelSize: 14
        selectByMouse: true
        activeFocusOnTab: true
        onEditingFinished: if (text !== root.value) root.commit(text)
        Keys.onEscapePressed: e => { text = root.value; e.accepted = false; }
        cursorDelegate: Rectangle {
            width: 2
            radius: 1
            color: Theme.primary
            visible: input.activeFocus
            SequentialAnimation on opacity {
                running: input.activeFocus
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 120 }
                PauseAnimation { duration: 450 }
                NumberAnimation { to: 0; duration: 180 }
                PauseAnimation { duration: 250 }
            }
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            text: root.placeholder
            color: Theme.outline
        }
    }
    onValueChanged: if (!input.activeFocus) input.text = value
}
