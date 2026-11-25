import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var kb: Backend.cfg.keyboard
    function layoutName(l: var): string {
        const x = Backend.st.layouts.find(i => i.id === l?.layout);
        const v = x?.variants.find(i => i.id === l.variant);
        return v?.name ?? x?.name ?? l?.layout ?? "";
    }
    function chooseLayout(index: int): void {
        Ui.pick(I18n.tr("Layout"), Backend.st.layouts.map(l => ({ value: l.id, label: l.name, sub: l.id })), kb.layouts[index]?.layout, id => {
            const found = Backend.st.layouts.find(l => l.id === id);
            const set = variant => {
                if (index >= kb.layouts.length)
                    Ui.markAdded(`layout-${index}`);
                Backend.mutate(c => c.keyboard.layouts[index] = { layout: id, variant });
            };
            if (!found.variants.length)
                return set("");
            Ui.pick(I18n.tr("Variant"), [{ value: "", label: I18n.tr("Standard") }].concat(found.variants.map(v => ({ value: v.id, label: v.name, sub: v.id }))), "", set);
        });
    }

    title: I18n.tr("Keyboard")
    intro: I18n.tr("Layouts, the shortcut to switch between them, and key behaviour.")

    ToggleTile {
        first: true
        last: true
        icon: "keyboard"
        label: I18n.tr("Manage the keyboard with Orrery")
        sub: I18n.tr("When off, your current configuration is left untouched.")
        checked: page.kb.managed
        onToggled: v => Backend.mutate(c => c.keyboard.managed = v)
    }

    Head { text: I18n.tr("Layouts") }
    Repeater {
        id: rep
        model: page.kb.layouts.length
        Tile {
            id: tile
            required property int index
            first: index === 0
            growKey: `layout-${index}`
            dim: !page.kb.managed
            icon: index === 0 ? "looks_one" : "swap_horiz"
            label: page.layoutName(page.kb.layouts[index])
            sub: index === 0 ? I18n.tr("Used at startup") : ""
            clickable: true
            onDelete: rep.count > 1 ? () => tile.leave(() => Backend.mutate(c => c.keyboard.layouts.splice(tile.index, 1))) : null
            onClicked: page.chooseLayout(index)
            Btn { icon: "arrow_upward"; kind: "text"; visible: tile.index > 0; onClicked: Backend.mutate(c => c.keyboard.layouts.splice(tile.index - 1, 0, c.keyboard.layouts.splice(tile.index, 1)[0])) }
            Btn { icon: "close"; kind: "text"; visible: rep.count > 1; onClicked: tile.leave(() => Backend.mutate(c => c.keyboard.layouts.splice(tile.index, 1))) }
        }
    }
    Tile {
        last: true
        visible: rep.count < 4
        dim: !page.kb.managed
        icon: "add"
        label: I18n.tr("Add a layout")
        clickable: true
        onClicked: page.chooseLayout(page.kb.layouts.length)
    }

    Head { text: I18n.tr("Behaviour") }
    KeyTile {
        first: true
        dim: !page.kb.managed
        icon: "keyboard_command_key"
        label: I18n.tr("Switch layout")
        value: page.kb.switchKey
        onCommit: v => Backend.mutate(c => c.keyboard.switchKey = v)
    }
    ToggleTile {
        dim: !page.kb.managed
        icon: "pin"
        label: I18n.tr("Num Lock at startup")
        checked: page.kb.numlock
        onToggled: v => Backend.mutate(c => c.keyboard.numlock = v)
    }
    SliderTile {
        dim: !page.kb.managed
        icon: "speed"
        label: I18n.tr("Repeat rate")
        from: 1; to: 100; value: page.kb.repeatRate
        onMoved: v => Backend.mutate(c => c.keyboard.repeatRate = v)
    }
    SliderTile {
        last: true
        dim: !page.kb.managed
        icon: "timer"
        label: I18n.tr("Repeat delay")
        from: 100; to: 1000; step: 10; suffix: " ms"; value: page.kb.repeatDelay
        onMoved: v => Backend.mutate(c => c.keyboard.repeatDelay = v)
    }
    Note {
        text: I18n.tr("Caps Lock cannot be turned on at startup: Hyprland has no option for it. The lock screen uses the layout that is active when you lock.")
    }
}
