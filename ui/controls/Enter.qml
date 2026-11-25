import QtQuick
import qs.core

// Cascade entrance: attach to an item as `transform: Translate {}` through Tile/Head/Note.
// p goes 0 -> 1, later for items further down the page. Runs only while a page is opening.
Item {
    id: root
    property Item target: parent
    property real p: 1
    property bool active: true
    visible: false

    Component.onCompleted: {
        if (!active || !Ui.entering)
            return;
        p = 0;
        laidOut.start();
    }
    // Wait for the layout, then go top to bottom
    Timer {
        id: laidOut
        interval: 20
        onTriggered: {
            const y = Math.max(0, root.target.mapToItem(null, 0, 0).y);
            wait.duration = (80 + Math.min(16, y / 62) * 26) * Theme.animScale;
            seq.start();
        }
    }
    SequentialAnimation {
        id: seq
        PauseAnimation { id: wait }
        Anim { target: root; property: "p"; to: 1; kind: "default" }
    }
}
