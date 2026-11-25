import QtQuick
import qs.core

// Shortcut editor. Typed by hand because Hyprland swallows its own shortcuts before any window sees them.
Tile {
    id: root
    property string value
    signal commit(string value)

    readonly property var parts: value.split(" + ").filter(p => p)
    readonly property var mods: parts.filter(p => ["SUPER", "CTRL", "ALT", "SHIFT"].includes(p))
    readonly property string key: parts.filter(p => !mods.includes(p))[0] ?? ""

    function build(m: var, k: string): void {
        k = k.trim();
        if (k.length === 1)
            k = k.toUpperCase();
        commit(k ? ["CTRL", "SUPER", "SHIFT", "ALT"].filter(x => m.includes(x)).concat([k]).join(" + ") : "");
    }

    Repeater {
        model: ["SUPER", "CTRL", "ALT", "SHIFT"]
        Rectangle {
            required property string modelData
            readonly property bool on: root.mods.includes(modelData)
            implicitWidth: t.implicitWidth + 22
            implicitHeight: 34
            radius: kh.pressed ? 6 : on ? 17 : 9
            topLeftRadius: radius; topRightRadius: radius; bottomLeftRadius: radius; bottomRightRadius: radius
            scale: kh.pressed ? 0.94 : 1
            Behavior on scale { Anim { kind: "fast" } }
            color: on ? Theme.primary : Theme.field
            Behavior on radius { Anim { kind: "fast" } }
            Behavior on color { CAnim {} }
            Txt { id: t; anchors.centerIn: parent; text: parent.modelData; size: 12; weight: Font.Medium; color: parent.on ? Theme.fgPrimary : Theme.fgVariant }
            Hover { id: kh; onClicked: root.build(parent.on ? root.mods.filter(m => m !== parent.modelData) : root.mods.concat([parent.modelData]), root.key) }
        }
    }
    Field { implicitWidth: 92; mono: true; value: root.key; placeholder: "D"; onCommit: v => root.build(root.mods, v) }
}
