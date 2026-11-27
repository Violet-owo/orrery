import QtQuick
import qs.core

// A thin scroll bar for any Flickable (ListView, GridView, pages). Shows while scrolling or when the pointer is near,
// grows under the pointer, and can be dragged or clicked. Hidden when everything fits.
Item {
    id: root
    required property Flickable target
    readonly property real ratio: target.visibleArea.heightRatio
    readonly property bool needed: ratio < 0.999 && target.contentHeight > target.height + 1
    readonly property bool hot: area.containsMouse || area.pressed
    readonly property bool shown: needed && (hot || target.moving || wake.running)

    anchors { right: target.right; top: target.top; bottom: target.bottom; rightMargin: 2 }
    width: 14
    visible: needed
    z: 10

    // Stays a moment after scrolling stops
    Timer { id: wake; interval: 900 }
    Connections {
        target: root.target
        function onContentYChanged(): void { wake.restart(); }
    }

    Rectangle {
        id: thumb
        anchors.right: parent.right
        width: root.hot ? 8 : 4
        radius: width / 2
        height: Math.max(36, root.height * root.ratio)
        y: Math.max(0, Math.min(root.height - height, root.target.visibleArea.yPosition * root.height))
        color: root.hot ? Theme.primary : Theme.fgVariant
        opacity: root.shown ? (root.hot ? 0.9 : 0.55) : 0
        Behavior on width { Anim { kind: "fast" } }
        Behavior on opacity { Anim { kind: "fx" } }
        Behavior on color { CAnim {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        // The bar sits inside the list: without this the list takes the drag as a touch swipe and both move
        preventStealing: true
        property real grab: 0
        property bool wasInteractive: true
        function scrollTo(y: real): void {
            const top = Math.max(0, Math.min(1, (y - grab) / Math.max(1, root.height - thumb.height)));
            root.target.contentY = root.target.originY + top * Math.max(0, root.target.contentHeight - root.target.height);
        }
        onPressed: m => {
            wasInteractive = root.target.interactive;
            root.target.interactive = false;      // no flicking while the bar is held
            root.target.cancelFlick();
            // On the thumb: keep where it was taken. Elsewhere: jump there, centred
            grab = m.y >= thumb.y && m.y <= thumb.y + thumb.height ? m.y - thumb.y : thumb.height / 2;
            scrollTo(m.y);
        }
        onPositionChanged: m => { if (pressed) scrollTo(m.y); }
        onReleased: root.target.interactive = wasInteractive
        onCanceled: root.target.interactive = wasInteractive
        onWheel: w => w.accepted = false
    }
}
