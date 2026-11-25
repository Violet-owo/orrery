import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var bl: Backend.st.system.backlight
    property int level: bl.max

    title: I18n.tr("Startup")
    intro: I18n.tr("These options change the system, so they ask for your password and apply immediately.")

    Head { text: I18n.tr("Keyboard backlight"); Layout.topMargin: 0 }
    Tile {
        first: true
        last: !page.bl.present
        icon: page.bl.unit ? "backlight_high" : "backlight_low"
        label: page.bl.present ? (page.bl.unit ? I18n.tr("Turned on at startup") : I18n.tr("Not managed")) : I18n.tr("No keyboard backlight found")
        sub: page.bl.unit
    }
    SliderTile {
        visible: page.bl.present
        icon: "light_mode"
        label: I18n.tr("Level")
        from: 1; to: Math.max(2, page.bl.max); value: page.level
        onMoved: v => page.level = v
    }
    Tile {
        visible: page.bl.present
        last: true
        icon: "power_settings_new"
        label: I18n.tr("Turn on at startup")
        Btn { text: I18n.tr("Remove"); visible: page.bl.unit === "orrery-kbd-backlight.service"; enabled: Backend.st.system.helper && !Backend.busy; onClicked: Backend.helper(["backlight", "0"], I18n.tr("Removed")) }
        Btn { text: I18n.tr("Set"); kind: "filled"; enabled: Backend.st.system.helper && !Backend.busy; onClicked: Backend.helper(["backlight", String(page.level)], I18n.tr("Applied")) }
    }
    Note {
        visible: !Backend.st.system.helper
        icon: "lock"
        text: I18n.tr("Install the Orrery package to enable this: the system helper is missing.")
    }
    Note {
        visible: page.bl.unit !== "" && page.bl.unit !== "orrery-kbd-backlight.service"
        text: I18n.tr("Another service already handles the backlight.")
    }
}
