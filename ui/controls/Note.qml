import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root
    property string text
    property string icon: "info"
    property bool warn
    Layout.fillWidth: true
    Layout.topMargin: 10
    implicitHeight: t.implicitHeight + 28
    radius: Theme.rMd
    opacity: enter.p
    transform: Translate { y: (1 - enter.p) * 34 }
    Behavior on color { CAnim {} }
    Enter { id: enter }
    color: warn ? Theme.errorContainer : Theme.tertiaryContainer
    Ico { id: i; anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter } text: root.icon; color: t.color }
    Txt {
        id: t
        anchors { left: i.right; right: parent.right; leftMargin: 14; rightMargin: 18; verticalCenter: parent.verticalCenter }
        text: root.text
        size: 13
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        color: root.warn ? Theme.fgError : Theme.fgTertiary
    }
}
