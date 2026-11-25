import QtQuick
import qs.core

// Used when Caelestia.Blobs cannot be loaded
Item {
    id: root
    property real leftBorder
    property real notchWidth
    property real notchHeight
    Rectangle { width: root.leftBorder; height: parent.height; color: Theme.frame }
    Rectangle { x: root.leftBorder; width: parent.width - x; height: 10; color: Theme.frame }
    Rectangle { x: root.leftBorder; y: parent.height - 10; width: parent.width - x; height: 10; color: Theme.frame }
    Rectangle { x: parent.width - 10; y: 10; width: 10; height: parent.height - 20; color: Theme.frame }
    Rectangle { x: parent.width - root.notchWidth; y: 10; width: root.notchWidth - 10; height: root.notchHeight - 10; bottomLeftRadius: Theme.rMd; color: Theme.frame }
}
