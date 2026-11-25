import QtQuick
import QtQuick.Layouts
import qs.core

// Animated expand / collapse
Item {
    id: root
    property bool shown
    default property alias body: col.data

    Layout.fillWidth: true
    implicitHeight: shown ? col.implicitHeight : 0
    visible: implicitHeight > 0.5
    opacity: shown ? 1 : 0
    clip: true

    Behavior on implicitHeight { Anim { kind: root.shown ? "decel" : "fxSlow" } }
    Behavior on opacity { Anim { kind: "fxSlow" } }

    ColumnLayout {
        id: col
        width: root.width
        spacing: Theme.gap
    }
}
