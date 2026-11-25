import QtQuick
import QtQuick.Layouts
import qs.core

// Keyboard guide (F1)
Item {
    id: root
    property bool open: false
    readonly property var rows: [
        ["↑ ↓ ← →", "Move between options"], ["Enter / Space", "Open, press or toggle"], ["← →", "Change a slider (Home / End for the limits)"],
        ["Esc", "Back: close, leave the field, go to the menu"], ["Ctrl + F  /", "Search settings"], ["Ctrl + 1…8", "Open a page"], ["Ctrl + Tab", "Next page"],
        ["Alt + ← →", "Previous / next area"], ["Page ↑ ↓", "Scroll"], ["Ctrl + S", "Apply"], ["Ctrl + Z / Ctrl + Shift + Z", "Undo / redo an edit"],
        ["Delete", "Remove the selected app or layout"], ["Ctrl + Q", "Close Orrery"], ["F1", "This guide"]]

    readonly property bool navSkip: true
    anchors.fill: parent
    visible: scrim.opacity > 0

    Rectangle { id: scrim; anchors.fill: parent; color: Qt.alpha("black", 0.5); opacity: root.open ? 1 : 0; Behavior on opacity { Anim { kind: "fxSlow" } } }
    MouseArea { anchors.fill: parent; enabled: root.open; hoverEnabled: true; onClicked: root.open = false; onWheel: {} }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 + (root.open ? 0 : 60)
        width: Math.min(620, parent.width - 60)
        height: col.implicitHeight + 48
        radius: root.open ? Theme.rLg : 60
        color: Theme.container
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.86
        Behavior on y { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on scale { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on radius { Anim {} }
        Behavior on opacity { Anim { kind: "fx" } }
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 24 }
            spacing: 3
            Txt { text: I18n.tr("Keyboard guide"); size: 20; weight: Font.DemiBold; Layout.bottomMargin: 10 }
            Repeater {
                model: root.rows
                Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 38
                    color: Theme.containerHigh
                    topLeftRadius: index === 0 ? Theme.rMd : Theme.rXs
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: index === root.rows.length - 1 ? Theme.rMd : Theme.rXs
                    bottomRightRadius: bottomLeftRadius
                    Txt { anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter } text: parent.modelData[0]; color: Theme.primary; weight: Font.Medium; size: 13 }
                    Txt { anchors { left: parent.left; leftMargin: 230; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: I18n.tr(parent.modelData[1]); size: 13 }
                }
            }
        }
    }
}
