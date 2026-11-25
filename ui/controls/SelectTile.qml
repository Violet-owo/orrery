import QtQuick
import qs.core

Tile {
    id: root
    property var items: []
    property var current
    property string placeholder
    readonly property string shownText: items.find(i => i.value === current)?.label ?? (placeholder || String(current ?? ""))
    signal picked(var value)

    clickable: true
    onClicked: Ui.pick(label, items, current, v => picked(v))
    onShownTextChanged: if (value.text !== "") swap.restart(); else value.text = shownText
    Component.onCompleted: value.text = shownText

    Txt {
        id: value
        color: Theme.primary
        weight: Font.Medium
        transform: Translate { id: shift }
        // The old value slides up and out, the new one comes from below
        SequentialAnimation {
            id: swap
            ParallelAnimation {
                Anim { target: value; property: "opacity"; to: 0; kind: "accel" }
                Anim { target: shift; property: "y"; to: -12; kind: "accel" }
            }
            ScriptAction { script: { value.text = root.shownText; shift.y = 14; } }
            ParallelAnimation {
                Anim { target: value; property: "opacity"; to: 1; kind: "fx" }
                Anim { target: shift; property: "y"; to: 0; kind: "fast" }
            }
        }
    }
    Ico { text: "unfold_more"; size: 20; color: Theme.fgVariant }
}
