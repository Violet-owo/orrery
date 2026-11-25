import QtQuick
import QtQuick.Layouts
import qs.core

// A settings row. Consecutive tiles connect like Caelestia's own settings.
Rectangle {
    id: root

    property string label
    property string sub
    property string icon
    property real iconFill: 0
    property bool first
    property bool last
    property bool clickable
    property bool dim
    property string growKey // when equal to Ui.added the tile grows in
    default property alias trailing: slot.data
    property var onDelete: null
    signal clicked

    readonly property real full: Math.max(62, row.implicitHeight + 24)
    property real grow: 1
    property real shade: dim ? 0.5 : 1
    Behavior on shade { Anim { kind: "fxSlow" } }
    readonly property bool held: clickable && hover.pressed

    // Collapses, then calls done
    function leave(done: var): void {
        out.done = done;
        out.start();
    }

    Layout.fillWidth: true
    implicitHeight: full * grow
    clip: grow < 1
    color: Theme.tile
    opacity: shade * enter.p * Math.min(1, grow)
    transform: Translate { y: (1 - enter.p) * 34 }
    topLeftRadius: held ? Theme.rMd : first ? Theme.rLg : Theme.rXs
    topRightRadius: topLeftRadius
    bottomLeftRadius: held ? Theme.rMd : last ? Theme.rLg : Theme.rXs
    bottomRightRadius: bottomLeftRadius

    Behavior on color { CAnim {} }
    Behavior on topLeftRadius { Anim { kind: "fast" } }
    Behavior on bottomLeftRadius { Anim { kind: "fast" } }

    Component.onCompleted: {
        if (growKey !== "" && growKey === Ui.added) {
            grow = 0;
            into.start();
        }
    }
    Anim { id: into; target: root; property: "grow"; to: 1; kind: "default" }
    SequentialAnimation {
        id: out
        property var done
        Anim { target: root; property: "grow"; to: 0; kind: "fxSlow" }
        ScriptAction { script: { const f = out.done; root.grow = 1; f(); } }
    }
    Enter { id: enter }

    // Shown when reached from the search
    function pulse(): void { glow.restart(); }
    Rectangle {
        id: lit
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Theme.primary
        opacity: 0
    }
    SequentialAnimation {
        id: glow
        loops: 2
        Anim { target: lit; property: "opacity"; to: 0.3; kind: "fxSlow" }
        Anim { target: lit; property: "opacity"; to: 0; kind: "decel"; duration: 500 * Theme.animScale }
    }

    Hover {
        id: hover
        enabled: root.clickable
        visible: root.clickable
        onDelete: root.onDelete
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; leftMargin: 20; rightMargin: 18 }
        y: (root.full - height) / 2
        spacing: 16

        Ico {
            visible: root.icon !== ""
            text: root.icon
            fill: root.clickable && hover.containsMouse ? 1 : root.iconFill
            color: root.clickable && hover.containsMouse ? Theme.primary : Theme.fgVariant
            scale: root.held ? 0.85 : 1
            Behavior on scale { Anim { kind: "fast" } }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: root.label; size: 15 }
            Txt {
                Layout.fillWidth: true
                visible: root.sub !== ""
                text: root.sub
                size: 12
                color: Theme.fgVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }
        }
        RowLayout { id: slot; spacing: 8 }
    }
}
