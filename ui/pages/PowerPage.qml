import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var pw: Backend.cfg.power
    readonly property var info: Backend.st.power
    readonly property bool laptop: info.battery
    readonly property var steps: [60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 10800, 14400]

    function time(s: int): string {
        if (!s)
            return I18n.tr("Never");
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return [h ? `${h} h` : "", m ? `${m} min` : "", r ? `${r} s` : ""].filter(x => x).join(" ");
    }
    // A value written by hand stays in the list
    function choices(now: int): var {
        return (now && !steps.includes(now) ? steps.concat([now]).sort((a, b) => a - b) : steps)
            .map(s => ({ value: s, label: time(s) })).concat([{ value: 0, label: I18n.tr("Never") }]);
    }
    function set(k: string, v: var): void { Backend.mutate(c => c.power[k] = v); }
    readonly property var bat: Backend.cfg.shell?.battery ?? null
    function percent(now: int, steps: var): var {
        const l = steps ?? [5, 10, 15, 20, 25, 30, 40, 50];
        return (l.includes(now) || now < 1 ? l : l.concat([now]).sort((a, b) => a - b)).map(v => ({ value: v, label: `${v}%` }));
    }
    // A new warning uses Caelestia's own texts, so they come translated
    function addWarning(): void {
        const used = bat.warnLevels.map(w => w.level), level = [15, 25, 30, 40, 50, 20, 10, 5].find(v => !used.includes(v)) ?? 30;
        Ui.markAdded(`warn-${bat.warnLevels.length}`);
        Backend.mutate(c => c.shell.battery.warnLevels.push({ level, title: "Low battery", message: "You might want to plug in a charger", icon: "battery_android_frame_2" }));
    }
    // Caelestia cannot say "only while charging": the time on battery is never the longer one
    function setBattery(v: int): void {
        Backend.mutate(c => {
            c.power.battery = v;
            if (!laptop || (c.power.ac && (!v || v > c.power.ac)))
                c.power.ac = v;
        });
    }
    function setAc(v: int): void {
        Backend.mutate(c => {
            c.power.ac = v;
            if (v && (!c.power.battery || c.power.battery > v))
                c.power.battery = v;
        });
    }

    title: I18n.tr("Power")
    intro: I18n.tr("What happens when you are away. Nothing is written until you change something.")

    Note {
        visible: !page.pw
        warn: true
        icon: "error"
        text: I18n.tr("Caelestia's shell.json cannot be read: fix it first, Orrery will not overwrite it.")
    }
    Loader {
        Layout.fillWidth: true
        active: !!page.pw
        visible: active
        sourceComponent: ColumnLayout {
            readonly property var p: page.pw ?? page.info.defaults
            spacing: Theme.gap

            Head { text: I18n.tr("After inactivity"); Layout.topMargin: 0 }
            SelectTile {
                first: true
                icon: "lock"
                label: I18n.tr("Lock")
                items: page.choices(parent.p.lock)
                current: parent.p.lock
                onPicked: v => page.set("lock", v)
            }
            SelectTile {
                icon: "desktop_access_disabled"
                label: I18n.tr("Turn the screen off")
                items: page.choices(parent.p.screen)
                current: parent.p.screen
                onPicked: v => page.set("screen", v)
            }
            SelectTile {
                last: !page.laptop
                icon: "bedtime"
                label: page.laptop ? I18n.tr("Suspend on battery") : I18n.tr("Suspend")
                items: page.choices(parent.p.battery)
                current: parent.p.battery
                onPicked: v => page.setBattery(v)
            }
            SelectTile {
                visible: page.laptop
                last: true
                dim: parent.p.charging
                icon: "battery_charging_full"
                label: I18n.tr("Suspend while charging")
                sub: I18n.tr("Never sooner than on battery: the other time follows if needed")
                items: page.choices(parent.p.ac)
                current: parent.p.ac
                onPicked: v => page.setAc(v)
            }
            Note {
                visible: !parent.p.lockBefore && parent.p.battery > 0 && (!parent.p.lock || parent.p.lock > parent.p.battery)
                icon: "lock_open"
                warn: true
                text: I18n.tr("The computer would suspend unlocked: anyone waking it can use it.")
            }

            Head { visible: page.laptop && !!page.bat; text: I18n.tr("Low battery") }
            Repeater {
                id: warns
                model: page.laptop && page.bat ? page.bat.warnLevels.length : 0
                SelectTile {
                    id: warn
                    required property int index
                    readonly property var w: page.bat.warnLevels[index]
                    first: index === 0
                    growKey: `warn-${index}`
                    icon: w?.icon || "battery_alert"
                    label: I18n.tr("Warning at")
                    sub: w?.critical ? I18n.tr("Shown as urgent") : ""
                    items: page.percent(w?.level ?? 20)
                    current: w?.level
                    onPicked: v => Backend.mutate(c => c.shell.battery.warnLevels[warn.index].level = v)
                    onDelete: () => warn.leave(() => Backend.mutate(c => c.shell.battery.warnLevels.splice(warn.index, 1)))
                    Btn { icon: "close"; kind: "text"; onClicked: warn.leave(() => Backend.mutate(c => c.shell.battery.warnLevels.splice(warn.index, 1))) }
                }
            }
            Tile {
                visible: page.laptop && !!page.bat && warns.count < 8
                first: warns.count === 0
                icon: "add_alert"
                label: I18n.tr("Add a warning")
                clickable: true
                onClicked: page.addWarning()
            }
            SelectTile {
                visible: page.laptop && !!page.bat
                last: true
                icon: "battery_android_alert"
                label: I18n.tr("Hibernate when the battery is almost empty")
                sub: I18n.tr("Caelestia warns you, then hibernates 5 seconds later")
                items: page.percent(page.bat?.criticalLevel ?? 3, [2, 3, 5, 8, 10]).concat([{ value: -1, label: I18n.tr("Never") }])
                current: page.bat?.criticalLevel
                onPicked: v => Backend.mutate(c => c.shell.battery.criticalLevel = v)
            }
            Note {
                visible: page.laptop && !!page.bat && page.bat.criticalLevel > 0 && !page.info.hibernate
                warn: true
                icon: "battery_alert"
                text: I18n.tr("This computer cannot hibernate: at that level Caelestia's attempt fails and it keeps running until the battery is empty. Set up hibernation, or plug in when warned.")
            }

            Head { text: I18n.tr("Behaviour") }
            ToggleTile {
                first: true
                icon: "lock_clock"
                label: I18n.tr("Lock before suspending")
                checked: parent.p.lockBefore
                onToggled: v => page.set("lockBefore", v)
            }
            ToggleTile {
                icon: "music_note"
                label: I18n.tr("Stay awake while something plays")
                sub: I18n.tr("Music and video: no lock, no screen off, no suspend")
                checked: parent.p.audio
                onToggled: v => page.set("audio", v)
            }
            ToggleTile {
                visible: page.laptop
                icon: "power"
                label: I18n.tr("Stay awake while charging")
                sub: I18n.tr("No lock, no screen off, no suspend until you unplug")
                checked: parent.p.charging
                onToggled: v => page.set("charging", v)
            }
            ToggleTile {
                visible: page.info.hibernate
                icon: "save"
                label: I18n.tr("Hibernate after a while asleep")
                sub: I18n.tr("Suspends first, then saves to disk and turns off")
                checked: parent.p.action === "hibernate"
                onToggled: v => page.set("action", v ? "hibernate" : "suspend")
            }
            Tile {
                last: true
                icon: "restart_alt"
                label: I18n.tr("Caelestia's defaults")
                sub: I18n.tr("Puts these options back; your own rows in shell.json stay")
                Btn { text: I18n.tr("Restore"); enabled: !Backend.busy; onClicked: Backend.mutate(c => {
                    c.power = JSON.parse(JSON.stringify(page.info.defaults));
                    if (c.shell)
                        c.shell.battery = JSON.parse(JSON.stringify(Backend.st.shell.defaults.battery));
                }) }
            }
            Note {
                text: I18n.tr("Apps that ask to stay awake are respected, and so is Keep awake in Caelestia's utilities. The lid and the power button are handled by the system.")
            }
        }
    }
}
