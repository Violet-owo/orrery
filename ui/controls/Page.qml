import QtQuick
import QtQuick.Layouts
import qs.core

// The title stays put; the options scroll below it and fade out, clear of the window buttons.
Item {
    id: root
    property string title
    property string intro
    default property alias body: col.data
    property alias contentY: flick.contentY
    readonly property real inset: Math.max(8, (width - 8 - col.width) / 2)

    function findTile(label: string, item: Item): Item {
        for (const c of (item ?? col).children) {
            if (!c.visible)
                continue;
            if (c.label === label && c.pulse)
                return c;
            const r = findTile(label, c);
            if (r)
                return r;
        }
        return null;
    }
    function glideTo(y: real): void {
        glide.to = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), y));
        glide.restart();
    }
    // Keeps the focused control in sight, away from the faded edges
    function reveal(item: Item): void {
        const y = item.mapToItem(flick.contentItem, 0, 0).y, now = glide.running ? glide.to : flick.contentY;
        if (y < 120)
            glideTo(0);
        else if (y < now + 60)
            glideTo(y - 100);
        else if (y + item.height > now + flick.height - 60)
            glideTo(y + item.height - flick.height + 100);
    }

    Txt {
        id: heading
        x: root.inset + 8
        width: Math.min(implicitWidth, root.width - x - 110) // room for the window buttons
        text: root.title
        size: 30
        weight: Font.DemiBold
        opacity: e1.p
        transform: Translate { x: (1 - e1.p) * -24 }
        Enter { id: e1 }
    }

    FadeFlick {
        id: flick
        anchors { fill: parent; topMargin: heading.height + 14 }
        contentHeight: col.implicitHeight + 40
        boundsBehavior: Flickable.DragAndOvershootBounds
        boundsMovement: Flickable.FollowBoundsBehavior
        maximumFlickVelocity: 5000
        flickDeceleration: 4500
        onDraggingChanged: if (dragging) glide.stop()

        // Smooth wheel scrolling
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse
            onWheel: e => root.glideTo((glide.running ? glide.to : flick.contentY) - e.angleDelta.y * 0.9)
        }
        Anim { id: glide; target: flick; property: "contentY"; kind: "decel" }

        ColumnLayout {
            id: col
            x: root.inset
            width: Math.min(820, root.width - 30)
            spacing: Theme.gap
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.bottomMargin: 14
                visible: root.intro !== ""
                text: root.intro
                color: Theme.fgVariant
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                opacity: e2.p
                transform: Translate { x: (1 - e2.p) * -24 }
                Enter { id: e2 }
            }
        }
    }

    // Scroll indicator
    Rectangle {
        anchors { right: parent.right; rightMargin: 2 }
        y: flick.y + flick.visibleArea.yPosition * flick.height + 6
        width: 5
        height: Math.max(30, flick.visibleArea.heightRatio * flick.height - 12)
        radius: 3
        color: Theme.outline
        opacity: flick.moving || glide.running ? 0.7 : 0
        visible: flick.visibleArea.heightRatio < 1
        Behavior on opacity { Anim { kind: "fxSlow" } }
    }
}
