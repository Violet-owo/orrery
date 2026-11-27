import QtQuick
import qs.core

// Grid of pictures. Still images are decoded small and kept in Qt's cache; animations play only where it helps:
// all of them for GIPHY (animateAll), only the one under the mouse or selected for your files.
GridView {
    id: grid
    property bool playing: true
    property bool animateAll: false
    signal chosen(var item)
    signal leaveTop
    signal close

    clip: true
    cellWidth: width / Math.max(1, Math.floor(width / 150))
    cellHeight: cellWidth
    cacheBuffer: cellHeight * 2
    keyNavigationEnabled: true
    boundsBehavior: Flickable.StopAtBounds
    Keys.onReturnPressed: if (currentItem) currentItem.choose()
    Keys.onEscapePressed: close()
    Keys.onUpPressed: e => { if (currentIndex < Math.floor(width / cellWidth)) leaveTop(); else e.accepted = false; }

    Scroller { parent: grid; target: grid }

    delegate: Item {
        id: cell
        required property int index
        required property string pid
        required property string path
        required property string title
        required property string preview
        required property bool moving
        required property int transparent
        readonly property bool bad: transparent === 0
        readonly property bool current: grid.currentIndex === index && grid.activeFocus
        // Rows kept ready just outside the view (cacheBuffer) stay still: only what you see moves
        readonly property bool onScreen: y + height > grid.contentY && y < grid.contentY + grid.height
        readonly property bool animate: moving && grid.playing && onScreen && (grid.animateAll || hover.containsMouse || current)
        function choose(): void { if (!bad) grid.chosen({ id: pid, path, transparent }); }
        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            id: card
            anchors { fill: parent; margins: 5 }
            radius: hover.pressed ? Theme.rXs : Theme.rMd
            topLeftRadius: radius; topRightRadius: radius; bottomLeftRadius: radius; bottomRightRadius: radius
            color: cell.current ? Theme.containerHighest : Theme.containerHigh
            border.width: cell.current ? 2 : 0
            border.color: Theme.primary
            opacity: cell.bad ? 0.45 : 1
            Behavior on radius { Anim { kind: "fast" } }

            // First frame, small: cheap for big wallpapers. Not used for GIPHY (it would download twice)
            Image {
                id: still
                anchors { fill: parent; margins: 10 }
                visible: !grid.animateAll && !(anim.item?.status === AnimatedImage.Ready)
                source: grid.animateAll ? "" : cell.preview
                sourceSize: Qt.size(280, 280)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
            }
            Loader {
                id: anim
                anchors { fill: parent; margins: 10 }
                // GIPHY: the animation is the only picture, so it stays loaded and pauses; files: loaded only while needed
                active: grid.animateAll || cell.animate
                sourceComponent: AnimatedImage {
                    source: cell.preview
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: cell.animate
                }
            }
            OrreryLoader {
                anchors.centerIn: parent
                size: Math.min(56, card.width * 0.4)
                visible: cell.preview === "" || (grid.animateAll ? (anim.item?.status ?? AnimatedImage.Loading) : still.status) === Image.Loading
            }
            Ico {
                anchors.centerIn: parent
                visible: (grid.animateAll ? anim.item?.status : still.status) === Image.Error
                text: "broken_image"
                color: Theme.outline
            }
            Rectangle {
                visible: cell.bad
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                width: badge.implicitWidth + 16
                height: 24
                radius: 12
                color: Theme.errorContainer
                Txt { id: badge; anchors.centerIn: parent; text: I18n.tr("Has a background"); size: 11; color: Theme.fgError }
            }
            Hover {
                id: hover
                enabled: !cell.bad
                onClicked: { grid.currentIndex = cell.index; cell.choose(); }
            }
        }
    }
}
