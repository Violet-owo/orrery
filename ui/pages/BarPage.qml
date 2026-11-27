import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var sh: Backend.cfg.shell
    readonly property var info: Backend.st.shell
    readonly property var names: ({
        logo: ["Logo", "deployed_code"], workspaces: ["Workspaces", "grid_view"], spacer: ["Space", "expand"],
        activeWindow: ["Active window", "web_asset"], tray: ["System tray", "apps"], clock: ["Clock", "schedule"],
        statusIcons: ["Status icons", "wifi"], power: ["Power button", "power_settings_new"] })
    readonly property var delays: [1000, 1500, 2000, 3000, 4000, 5000]

    function move(i: int, by: int): void {
        Backend.mutate(c => {
            const e = c.shell.bar.entries;
            e.splice(i + by, 0, e.splice(i, 1)[0]);
        });
    }
    // Caelestia hides the bar on a screen whose name is in the list; a ^…$ entry is a pattern written by hand
    function shown(name: string): bool { return !page.sh.bar.excludedScreens.includes(name); }
    function setShown(name: string, v: bool): void {
        Backend.mutate(c => {
            const l = c.shell.bar.excludedScreens.filter(x => x !== name);
            c.shell.bar.excludedScreens = v ? l : l.concat([name]);
        });
    }
    readonly property var screens: {
        const live = (page.info?.monitors ?? []).map(m => ({ name: m.name, label: m.description || m.name, sub: m.description ? m.name : "", connected: true }));
        const gone = (page.sh?.bar.excludedScreens ?? []).filter(n => !live.some(m => m.name === n))
            .map(n => ({ name: n, label: n, sub: /^\^.*\$$/.test(n) ? I18n.tr("Rule written by hand") : I18n.tr("Not connected"), connected: false }));
        return live.concat(gone);
    }
    function seconds(ms: int): string { return `${(ms / 1000).toLocaleString(Qt.locale(), "f", ms % 1000 ? 1 : 0)} s`; }

    title: I18n.tr("Bar")
    intro: I18n.tr("What the bar shows and where, and the indicators for volume and brightness. Changes show up live.")

    Note {
        visible: !page.sh
        warn: true
        icon: "error"
        text: I18n.tr("Caelestia's shell.json cannot be read: fix it first, Orrery will not overwrite it.")
    }
    Loader {
        Layout.fillWidth: true
        active: !!page.sh
        visible: active
        sourceComponent: ColumnLayout {
            id: body
            readonly property var s: page.sh
            spacing: Theme.gap

            Head { text: I18n.tr("Blocks, from the top"); Layout.topMargin: 0 }
            Repeater {
                id: rep
                model: body.s.bar.entries.length
                Tile {
                    id: entry
                    required property int index
                    readonly property var e: body.s.bar.entries[index]
                    readonly property var known: page.names[e?.id] ?? [e?.id ?? "", "extension"]
                    first: index === 0
                    growKey: `bar-${index}`
                    icon: known[1]
                    iconFill: e?.enabled ? 1 : 0
                    dim: !e?.enabled
                    label: I18n.tr(known[0])
                    sub: e?.id === "spacer" ? I18n.tr("Pushes the blocks apart") : ""
                    clickable: true
                    onClicked: Backend.mutate(c => c.shell.bar.entries[entry.index].enabled = !entry.e.enabled)
                    onDelete: e?.id === "spacer" ? () => entry.leave(() => Backend.mutate(c => c.shell.bar.entries.splice(entry.index, 1))) : null
                    Btn { icon: "arrow_upward"; kind: "text"; enabled: entry.index > 0; onClicked: page.move(entry.index, -1) }
                    Btn { icon: "arrow_downward"; kind: "text"; enabled: entry.index < rep.count - 1; onClicked: page.move(entry.index, 1) }
                    Btn {
                        icon: "close"
                        kind: "text"
                        visible: entry.e?.id === "spacer"
                        onClicked: entry.leave(() => Backend.mutate(c => c.shell.bar.entries.splice(entry.index, 1)))
                    }
                    Toggle { checked: !!entry.e?.enabled; held: entry.held }
                }
            }
            Tile {
                last: true
                visible: rep.count < 30
                icon: "add"
                label: I18n.tr("Add a space")
                clickable: true
                onClicked: {
                    Ui.markAdded(`bar-${rep.count}`);
                    Backend.mutate(c => c.shell.bar.entries.push({ id: "spacer", enabled: true }));
                }
            }
            Note {
                visible: !body.s.bar.entries.some(e => e.enabled && e.id === "power")
                icon: "power_settings_new"
                text: I18n.tr("Without the power button, the menu to shut down and log out still opens with Ctrl+Alt+Delete.")
            }

            Head { text: I18n.tr("Screens") }
            Repeater {
                model: page.screens.length
                ToggleTile {
                    required property int index
                    readonly property var m: page.screens[index]
                    first: index === 0
                    last: index === page.screens.length - 1
                    icon: m.connected ? "monitor" : "desktop_access_disabled"
                    label: m.label
                    sub: m.sub
                    checked: page.shown(m.name)
                    onToggled: v => page.setShown(m.name, v)
                }
            }
            Note {
                visible: page.screens.length > 0 && page.screens.filter(m => m.connected).every(m => !page.shown(m.name))
                warn: true
                icon: "visibility_off"
                text: I18n.tr("The bar is hidden on every screen.")
            }

            Head { text: I18n.tr("Volume and brightness indicators") }
            ToggleTile {
                first: true
                icon: "tune"
                label: I18n.tr("Show the indicators")
                sub: I18n.tr("When you change volume or brightness")
                checked: body.s.osd.enabled
                onToggled: v => Backend.mutate(c => c.shell.osd.enabled = v)
            }
            ToggleTile {
                dim: !body.s.osd.enabled
                icon: "brightness_6"
                label: I18n.tr("Brightness")
                checked: body.s.osd.enableBrightness
                onToggled: v => Backend.mutate(c => c.shell.osd.enableBrightness = v)
            }
            ToggleTile {
                dim: !body.s.osd.enabled
                icon: "mic"
                label: I18n.tr("Microphone")
                checked: body.s.osd.enableMicrophone
                onToggled: v => Backend.mutate(c => c.shell.osd.enableMicrophone = v)
            }
            SelectTile {
                last: true
                dim: !body.s.osd.enabled
                icon: "timer"
                label: I18n.tr("Stays on screen for")
                items: (page.delays.includes(body.s.osd.hideDelay) ? page.delays : page.delays.concat([body.s.osd.hideDelay]).sort((a, b) => a - b))
                    .map(v => ({ value: v, label: page.seconds(v) }))
                current: body.s.osd.hideDelay
                onPicked: v => Backend.mutate(c => c.shell.osd.hideDelay = v)
            }

            Head { text: I18n.tr("Panels") }
            Tile {
                first: true
                icon: "partly_cloudy_day"
                label: I18n.tr("Weather city")
                sub: body.s.panels.weather ? "" : I18n.tr("Empty: found from your connection")
                Field {
                    implicitWidth: 240
                    placeholder: I18n.tr("For example: London")
                    value: body.s.panels.weather
                    onCommit: v => Backend.mutate(c => c.shell.panels.weather = v.trim())
                }
            }
            ToggleTile {
                icon: "touch_app"
                label: I18n.tr("Clicking a notification runs its action")
                sub: I18n.tr("For example opens the chat of a message")
                checked: body.s.panels.notifClick
                onToggled: v => Backend.mutate(c => c.shell.panels.notifClick = v)
            }
            SelectTile {
                icon: "fullscreen"
                label: I18n.tr("Notifications over full screen apps stay for")
                readonly property var steps: [1000, 2000, 3000, 5000, 8000, 10000]
                items: (steps.includes(body.s.panels.notifFullscreen) ? steps : steps.concat([body.s.panels.notifFullscreen]).sort((a, b) => a - b))
                    .map(v => ({ value: v, label: page.seconds(v) }))
                current: body.s.panels.notifFullscreen
                onPicked: v => Backend.mutate(c => c.shell.panels.notifFullscreen = v)
            }
            SelectTile {
                last: true
                icon: "power_settings_new"
                label: I18n.tr("Third button of the shut down menu")
                sub: !Backend.st.power.hibernate && body.s.panels.sessionButton === "hibernate" ? I18n.tr("This computer cannot hibernate: that button does nothing") : ""
                items: [{ value: "hibernate", label: I18n.tr("Hibernate") }, { value: "suspend", label: I18n.tr("Suspend") }, { value: "lock", label: I18n.tr("Lock") }]
                    .concat(body.s.panels.sessionButton === "custom" ? [{ value: "custom", label: I18n.tr("Your own command") }] : [])
                current: body.s.panels.sessionButton
                onPicked: v => Backend.mutate(c => c.shell.panels.sessionButton = v)
            }

            Tile {
                Layout.topMargin: 12
                first: true
                last: true
                icon: "restart_alt"
                label: I18n.tr("Caelestia's defaults")
                sub: I18n.tr("Puts the bar, the indicators and the panels back as they come")
                Btn {
                    text: I18n.tr("Restore")
                    enabled: !Backend.busy
                    onClicked: Backend.mutate(c => {
                        c.shell.bar = JSON.parse(JSON.stringify(page.info.defaults.bar));
                        c.shell.osd = JSON.parse(JSON.stringify(page.info.defaults.osd));
                        c.shell.panels = JSON.parse(JSON.stringify(page.info.defaults.panels));
                    })
                }
            }
            Note {
                text: I18n.tr("The bar's look, status icons and workspaces are in Caelestia's own settings.")
            }
        }
    }
}
