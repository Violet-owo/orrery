import QtQuick
import Caelestia.Blobs
import qs.core

// Same frame as Caelestia's settings: a border that flows around the window buttons.
Item {
    id: root
    property real leftBorder
    property real notchWidth
    property real notchHeight
    property color tone: Theme.frame
    Behavior on tone { CAnim {} }

    // Drawn opaque, then faded as one: overlapping translucent shapes would add up
    opacity: tone.a
    layer.enabled: tone.a < 1

    BlobGroup { id: group; smoothing: Theme.rMd; color: Qt.alpha(root.tone, 1) }
    BlobInvertedRect {
        anchors.fill: parent
        group: group
        radius: Theme.rMd
        borderLeft: root.leftBorder
        borderRight: 10
        borderTop: 10
        borderBottom: 10
    }
    BlobRect {
        anchors { right: parent.right; top: parent.top }
        group: group
        radius: Theme.rMd
        implicitWidth: root.notchWidth
        implicitHeight: root.notchHeight
    }
}
