import QtQuick
import QtQuick.Layouts
import qs.core

// Modal list with search
Item {
    id: root
    property string title
    property var items: []
    property var current
    property var done
    property bool open: false
    property string query
    property bool cascade: false
    property Item before: null // gets the focus back on close
    readonly property var shown: items.filter(i => !query || `${i.label} ${i.sub ?? ""}`.toLowerCase().includes(query.toLowerCase()))

    function show(t: string, list: var, cur: var, cb: var): void {
        title = t; items = list; current = cur; done = cb; query = ""; search.text = "";
        before = Nav.current;
        cascade = true;
        open = true;
        view.positionViewAtBeginning();
        search.forceActiveFocus();
        view.currentIndex = Math.max(0, list.findIndex(i => i.value === cur));
        view.positionViewAtIndex(view.currentIndex, ListView.Contain);
        cascadeEnd.restart();
    }
    function close(): void {
        open = false;
        if (before) before.forceActiveFocus(Qt.OtherFocusReason);
    }
    function choose(v: var): void { close(); done(v); }

    readonly property bool navSkip: true
    anchors.fill: parent
    visible: open || scrim.opacity > 0 // an invisible item cannot take the focus
    Timer { id: cascadeEnd; interval: 300; onTriggered: root.cascade = false }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.alpha("black", 0.5)
        opacity: root.open ? 1 : 0
        Behavior on opacity { Anim { kind: "fxSlow" } }
    }
    MouseArea { anchors.fill: parent; enabled: root.open; hoverEnabled: true; onClicked: root.close(); onWheel: {} }

    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(480, parent.width - 60)
        height: Math.min(parent.height - 80, 130 + view.contentHeight)
        y: (parent.height - height) / 2 + (root.open ? 0 : 60)
        radius: root.open ? Theme.rLg : 60
        color: Theme.container
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.86
        Behavior on y { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on scale { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on radius { Anim { kind: "default" } }
        Behavior on opacity { Anim { kind: "fx" } }
        Behavior on height { enabled: root.open && !root.cascade; Anim { kind: "decel" } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 18 }
            spacing: 12
            Txt { text: root.title; size: 18; weight: Font.Medium; Layout.leftMargin: 6 }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 21
                color: Theme.containerHighest
                Ico { id: lens; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "search"; size: 20; color: search.activeFocus ? Theme.primary : Theme.fgVariant }
                TextInput {
                    id: search
                    anchors { left: lens.right; right: parent.right; leftMargin: 8; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.fgPrimary
                    font.family: Theme.font
                    font.pixelSize: 14
                    onTextChanged: { root.query = text; view.currentIndex = 0; }
                    Keys.onEscapePressed: root.close()
                    Keys.onTabPressed: view.incrementCurrentIndex()
                    Keys.onBacktabPressed: view.decrementCurrentIndex()
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_PageDown) view.currentIndex = Math.min(view.count - 1, view.currentIndex + 6);
                        else if (e.key === Qt.Key_PageUp) view.currentIndex = Math.max(0, view.currentIndex - 6);
                        else return;
                        e.accepted = true;
                    }
                    Keys.onDownPressed: view.incrementCurrentIndex()
                    Keys.onUpPressed: view.decrementCurrentIndex()
                    onAccepted: if (root.shown.length) root.choose(root.shown[Math.max(0, view.currentIndex)].value)
                    Txt { visible: !search.text; text: I18n.tr("Search"); color: Theme.outline }
                }
            }
            ListView {
                id: view
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.gap
                model: root.shown
                highlightMoveDuration: 200
                Scroller { parent: view; target: view }
                delegate: Rectangle {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool sel: modelData.value === root.current
                    property real p: 1
                    width: view.width
                    implicitHeight: 54
                    opacity: p
                    transform: Translate { y: (1 - item.p) * 24 }
                    color: sel ? Theme.secondaryContainer : ListView.isCurrentItem && search.activeFocus ? Theme.containerHighest : Theme.containerHigh
                    topLeftRadius: sel || index === 0 ? Theme.rMd : Theme.rXs
                    topRightRadius: topLeftRadius
                    bottomLeftRadius: sel || index === view.count - 1 ? Theme.rMd : Theme.rXs
                    bottomRightRadius: bottomLeftRadius
                    Behavior on color { CAnim {} }
                    Component.onCompleted: if (root.cascade) { p = 0; pause.duration = Math.min(12, index) * 24 * Theme.animScale; come.start(); }
                    SequentialAnimation {
                        id: come
                        PauseAnimation { id: pause }
                        Anim { target: item; property: "p"; to: 1; kind: "default" }
                    }
                    ColumnLayout {
                        anchors { left: parent.left; right: tick.left; verticalCenter: parent.verticalCenter; leftMargin: 18 }
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: item.modelData.label }
                        Txt { Layout.fillWidth: true; visible: !!item.modelData.sub; text: item.modelData.sub ?? ""; size: 11; color: Theme.fgVariant }
                    }
                    Ico { id: tick; anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter } visible: item.sel; text: "check"; size: 20; color: Theme.primary }
                    Hover { onClicked: root.choose(item.modelData.value) }
                }
            }
        }
    }
}
