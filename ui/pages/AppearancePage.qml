import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var col: Backend.cfg.colours
    // Caelestia's key, name, icon, what it changes
    readonly property var apps: [
        ["enableHypr", "Window borders", "border_style", "Hyprland"], ["enableTerm", "Terminals", "terminal", "Colours of open terminals"],
        ["enableGtk", "GTK apps", "widgets", "Files, settings and most apps"], ["enableQt", "Qt apps", "view_quilt", "KDE and Qt apps"],
        ["enableDiscord", "Discord", "forum", "Vesktop, Equicord, Vencord, BetterDiscord, legcord"], ["enableSpicetify", "Spotify", "music_note", "With spicetify, see Default apps"],
        ["enableChromium", "Chromium browsers", "language", "Chromium, Brave and similar"], ["enableZed", "Zed", "code", "The Zed editor"],
        ["enableFuzzel", "Fuzzel", "search", "App launcher"], ["enableBtop", "btop", "monitoring", "System monitor"],
        ["enableHtop", "htop", "monitoring", "System monitor"], ["enableNvtop", "nvtop", "memory", "GPU monitor"],
        ["enableCava", "cava", "graphic_eq", "Audio visualiser"], ["enableWarp", "Warp", "terminal", "The Warp terminal"],
        ["enablePandora", "Pandora", "radio", "Pandora launcher"]]
    function icons(now: string): var {
        const l = [{ value: "", label: I18n.tr("Caelestia's choice"), sub: "Papirus" }].concat(Backend.st.colours.icons.map(n => ({ value: n, label: n })));
        return now && !Backend.st.colours.icons.includes(now) ? l.concat([{ value: now, label: now, sub: I18n.tr("Not installed") }]) : l;
    }

    title: I18n.tr("Appearance")
    intro: I18n.tr("How Orrery looks, saved immediately, and which apps follow Caelestia's colours.")

    Rectangle {
        id: hero
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        implicitHeight: 150
        radius: Theme.rLg
        color: Theme.primary
        clip: true
        opacity: enter.p
        transform: Translate { y: (1 - enter.p) * 34 }
        Behavior on color { CAnim {} }
        Behavior on radius { Anim {} }
        Enter { id: enter }
        // A small orrery, turning at the chosen animation speed
        Item {
            id: sky
            anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
            width: 130
            height: 130
            // Turns on the render thread (no script per frame), and only while it can be seen
            readonly property bool moving: Ui.awake && page.contentY < hero.height
            Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: Theme.fgPrimary }
            Repeater {
                model: [[26, 8, 5], [42, 11, 2.4], [60, 7, 1]]
                Item {
                    id: orbit
                    required property var modelData
                    anchors.fill: parent
                    Rectangle { anchors.centerIn: parent; width: orbit.modelData[0] * 2; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.alpha(Theme.fgPrimary, 0.3) }
                    Item {
                        id: arm
                        anchors.fill: parent
                        Rectangle {
                            width: orbit.modelData[1] * 2
                            height: width
                            radius: width / 2
                            color: Theme.fgPrimary
                            x: sky.width / 2 + orbit.modelData[0] - width / 2
                            y: sky.height / 2 - height / 2
                        }
                        RotationAnimator on rotation {
                            running: true
                            paused: !sky.moving     // resumes where it stopped
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 14000 / orbit.modelData[2] * Theme.animScale
                        }
                    }
                }
            }
        }
        Column {
            anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
            spacing: 4
            Txt { text: "Orrery"; size: 34; weight: Font.Bold; color: Theme.fgPrimary }
            Txt { text: I18n.tr("Extra settings for Caelestia"); color: Theme.fgPrimary }
            Txt { text: I18n.tr("by %1").replace("%1", Ui.author); color: Qt.alpha(Theme.fgPrimary, 0.75); size: 12 }
        }
    }

    Head { text: I18n.tr("Transparency"); Layout.topMargin: 4 }
    ToggleTile {
        first: true
        icon: "sync"
        label: I18n.tr("Follow Caelestia")
        sub: I18n.tr("Uses the transparency and animation speed of the shell")
        checked: Theme.prefs.follow
        onToggled: v => Theme.setPref("follow", v)
    }
    ToggleTile {
        icon: "opacity"
        label: I18n.tr("Transparency")
        sub: I18n.tr("Base %1, layers %2").replace("%1", Theme.baseAlpha).replace("%2", Theme.layerAlpha)
        dim: Theme.prefs.follow
        checked: Theme.transparent
        onToggled: v => Theme.setPrefs({ follow: false, transparent: v, base: Theme.baseAlpha, layers: Theme.layerAlpha, speed: Theme.animScale })
    }
    SliderTile { dim: Theme.prefs.follow || !Theme.transparent; icon: "blur_on"; label: I18n.tr("Background opacity"); from: 0.3; to: 1; step: 0.05; value: Theme.baseAlpha; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: v, layers: Theme.layerAlpha, speed: Theme.animScale }) }
    SliderTile { last: true; dim: Theme.prefs.follow || !Theme.transparent; icon: "layers"; label: I18n.tr("Layer opacity"); from: 0.1; to: 1; step: 0.05; value: Theme.layerAlpha; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: Theme.baseAlpha, layers: v, speed: Theme.animScale }) }

    Head { text: I18n.tr("Motion and shape") }
    SliderTile { first: true; icon: "animation"; dim: Theme.prefs.follow; label: I18n.tr("Animation duration"); sub: I18n.tr("Lower is faster"); from: 0.25; to: 2; step: 0.05; suffix: "×"; value: Theme.animScale; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: Theme.baseAlpha, layers: Theme.layerAlpha, speed: v }) }
    SliderTile { last: true; icon: "rounded_corner"; label: I18n.tr("Rounding"); from: 0; to: 1.5; step: 0.1; suffix: "×"; value: Theme.prefs.rounding; onMoved: v => Theme.setPref("rounding", v) }

    Head { text: I18n.tr("Language") }
    SelectTile {
        first: true
        last: true
        icon: "translate"
        label: I18n.tr("Language")
        items: [{ value: "auto", label: I18n.tr("System") }, { value: "en", label: "English" }, { value: "it", label: "Italiano" }]
        current: Theme.prefs.language
        onPicked: v => Theme.setPref("language", v)
    }

    Head { text: I18n.tr("Caelestia's colours in your apps") }
    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.bottomMargin: 6
        wrapMode: Text.WordWrap
        size: 12
        color: Theme.fgVariant
        text: I18n.tr("When the wallpaper or the scheme changes, Caelestia recolours these apps too. With Apply they take the colours at once.")
    }
    Note {
        visible: !page.col
        warn: true
        icon: "error"
        text: I18n.tr("Caelestia's cli.json cannot be read: fix it first, Orrery will not overwrite it.")
    }
    Repeater {
        id: themed
        model: page.col ? page.apps : []
        ToggleTile {
            required property var modelData
            required property int index
            first: index === 0
            icon: modelData[2]
            label: I18n.tr(modelData[1])
            sub: I18n.tr(modelData[3])
            checked: page.col[modelData[0]]
            onToggled: v => Backend.mutate(c => c.colours[modelData[0]] = v)
        }
    }
    SelectTile {
        visible: !!page.col
        icon: "dark_mode"
        label: I18n.tr("Icons with the dark theme")
        items: page.icons(page.col?.iconThemeDark ?? "")
        current: page.col?.iconThemeDark ?? ""
        onPicked: v => Backend.mutate(c => c.colours.iconThemeDark = v)
    }
    SelectTile {
        visible: !!page.col
        last: true
        icon: "light_mode"
        label: I18n.tr("Icons with the light theme")
        items: page.icons(page.col?.iconThemeLight ?? "")
        current: page.col?.iconThemeLight ?? ""
        onPicked: v => Backend.mutate(c => c.colours.iconThemeLight = v)
    }
}
