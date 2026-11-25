import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    readonly property var areas: Backend.cfg.areas
    readonly property int sel: Math.max(0, Math.min(Ui.area, areas.length - 1))
    readonly property var a: areas[sel] ?? null
    readonly property var anims: [
        { value: "horizontal", label: I18n.tr("Horizontal") }, { value: "vertical", label: I18n.tr("Vertical") },
        { value: "fade", label: I18n.tr("Fade") }, { value: "none", label: I18n.tr("None") }]

    function edit(fn: var): void { Backend.mutate(c => fn(c.areas[sel])); }
    function uniqueId(): string {
        const used = [];
        for (const x of page.areas)
            for (const s of x.spaces)
                used.push(s.id);
        let n = 1;
        while (used.includes(`orrery-${n}`))
            n++;
        return `orrery-${n}`;
    }
    function addApp(space: int): void {
        const open = Backend.st.windows.map(w => ({ value: "w:" + w.class, label: w.title || w.class, sub: I18n.tr("Open window") + " · " + w.class }));
        const all = Backend.st.apps.filter(x => !x.hidden).map(x => ({ value: "a:" + x.id, label: x.name, sub: x.command }));
        Ui.pick(I18n.tr("Add an app"), open.concat(all), "", v => {
            let app;
            if (v.startsWith("w:")) {
                const cls = v.slice(2);
                const match = Backend.st.apps.find(x => x.class.toLowerCase() === cls.toLowerCase() || x.class.toLowerCase() === cls.split(".").pop().toLowerCase());
                app = { name: match?.name ?? cls, class: cls, command: match?.command ?? "", autostart: !!match };
            } else {
                const d = Backend.appsById[v.slice(2)];
                app = { name: d.name, class: d.class, command: d.command, autostart: true };
            }
            Ui.markAdded(`app-${space}-${page.a.spaces[space].apps.length}`);
            page.edit(x => x.spaces[space].apps.push(app));
        });
    }

    title: I18n.tr("Areas")
    intro: I18n.tr("Hidden workspaces that open over the desktop with a shortcut. Disabled areas keep Caelestia's own behaviour.")

    Flow {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        spacing: 6
        Repeater {
            model: page.areas.length
            Rectangle {
                required property int index
                readonly property bool on: index === page.sel
                readonly property var area: page.areas[index]
                width: lab.implicitWidth + (on ? 66 : 54)
                height: 44
                radius: ch.pressed ? 8 : on ? 22 : 12
                topLeftRadius: radius; topRightRadius: radius; bottomLeftRadius: radius; bottomRightRadius: radius
                color: on ? Theme.primary : Theme.navItem
                opacity: ce.p
                transform: Translate { y: (1 - ce.p) * 34 }
                Enter { id: ce }
                Behavior on width { Anim { kind: "default" } }
                Behavior on radius { Anim { kind: "fast" } }
                Behavior on color { CAnim {} }
                Rectangle { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 5; scale: parent.area?.enabled ? 1 : 0.7; Behavior on scale { Anim { kind: "slow" } } Behavior on color { CAnim {} } color: parent.area?.enabled ? (parent.on ? Theme.fgPrimary : Theme.success) : Qt.alpha(parent.on ? Theme.fgPrimary : Theme.outline, 0.5) }
                Txt { id: lab; x: 36; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(parent.area?.name ?? ""); weight: Font.Medium; color: parent.on ? Theme.fgPrimary : Theme.fg }
                Hover { id: ch; tint: parent.on ? Theme.fgPrimary : Theme.fg; onClicked: Ui.area = parent.index }
            }
        }
        Btn {
            cascade: true
            icon: "add"
            height: 44
            visible: page.areas.length < 12
            onClicked: {
                const id = page.uniqueId();
                Backend.mutate(c => c.areas.push({ name: I18n.tr("New area"), enabled: true, key: "", arrows: true, wrap: true, bringBack: true, openAnimation: "vertical", openSpeed: 4, switchAnimation: "horizontal", switchSpeed: 5, spaces: [{ id, apps: [] }] }));
                Ui.area = page.areas.length - 1;
            }
        }
    }

    // Changing area slides the content in from the side of the chosen chip
    property int shownArea: 0
    onSelChanged: {
        const dir = sel >= shownArea ? 1 : -1;
        shownArea = sel;
        if (Ui.entering)
            return;
        slideX.from = 60 * dir;
        slide.restart();
    }
    ParallelAnimation {
        id: slide
        Anim { id: slideX; target: shift; property: "x"; to: 0; kind: "default" }
        Anim { target: body; property: "opacity"; from: 0; to: 1; kind: "fxSlow" }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: page.a !== null
        spacing: Theme.gap
        transform: Translate { id: shift }

        ToggleTile {
            first: true
            icon: "dashboard_customize"
            label: I18n.tr("Customise this area")
            sub: page.a?.enabled ? "" : I18n.tr("Caelestia's default behaviour is active")
            checked: page.a?.enabled ?? false
            onToggled: v => page.edit(x => x.enabled = v)
        }
        Tile { icon: "label"; label: I18n.tr("Name"); Field { value: I18n.tr(page.a?.name ?? ""); onCommit: v => page.edit(x => x.name = v) } }
        KeyTile { last: true; icon: "keyboard_command_key"; label: I18n.tr("Shortcut"); value: page.a?.key ?? ""; onCommit: v => page.edit(x => x.key = v) }

        Head { text: I18n.tr("Workspaces and apps") }
        Repeater {
            model: page.a?.spaces.length ?? 0
            ColumnLayout {
                id: spaceCol
                required property int index
                readonly property var space: page.a?.spaces[index] ?? null
                readonly property int at: index
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: Theme.gap

                Tile {
                    first: true
                    growKey: `space-${spaceCol.at}`
                    icon: "select_window"
                    label: I18n.tr("Workspace %1").replace("%1", spaceCol.at + 1)
                    sub: "special:" + (spaceCol.space?.id ?? "")
                    Btn { icon: "arrow_upward"; kind: "text"; visible: spaceCol.at > 0; onClicked: page.edit(x => x.spaces.splice(spaceCol.at - 1, 0, x.spaces.splice(spaceCol.at, 1)[0])) }
                    Btn { icon: "delete"; kind: "text"; visible: (page.a?.spaces.length ?? 0) > 1; onClicked: page.edit(x => x.spaces.splice(spaceCol.at, 1)) }
                }
                Repeater {
                    model: spaceCol.space?.apps.length ?? 0
                    Rectangle {
                        id: appRow
                        required property int index
                        readonly property int n: index
                        readonly property var app: spaceCol.space?.apps[index] ?? null
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: inner.implicitHeight
                        color: "transparent"
                        ColumnLayout {
                            id: inner
                            anchors { left: parent.left; right: parent.right }
                            spacing: Theme.gap
                            Tile {
                                id: appTile
                                growKey: `app-${spaceCol.at}-${appRow.n}`
                                clickable: true
                                onClicked: appRow.expanded = !appRow.expanded
                                onDelete: () => { appRow.expanded = false; appTile.leave(() => page.edit(x => x.spaces[spaceCol.at].apps.splice(appRow.n, 1))); }
                                icon: "apps"
                                label: appRow.app?.name ?? ""
                                sub: (appRow.app?.class ?? "") + (appRow.app?.autostart && appRow.app?.command ? " · " + I18n.tr("opens automatically") : "")
                                Btn { icon: "arrow_forward"; kind: "text"; visible: (page.a?.spaces.length ?? 0) > 1; onClicked: page.edit(x => { const p = x.spaces[spaceCol.at].apps.splice(appRow.n, 1)[0]; x.spaces[(spaceCol.at + 1) % x.spaces.length].apps.push(p); }) }
                                Btn { icon: "expand_more"; iconRotation: appRow.expanded ? 180 : 0; kind: "text"; onClicked: appRow.expanded = !appRow.expanded }
                                Btn { icon: "close"; kind: "text"; onClicked: { appRow.expanded = false; appTile.leave(() => page.edit(x => x.spaces[spaceCol.at].apps.splice(appRow.n, 1))); } }
                            }
                            Reveal {
                            shown: appRow.expanded
                            ToggleTile { label: I18n.tr("Open automatically"); sub: I18n.tr("Starts the app when the area opens"); checked: appRow.app?.autostart ?? false; onToggled: v => page.edit(x => x.spaces[spaceCol.at].apps[appRow.n].autostart = v) }
                            Tile { label: I18n.tr("Command"); Field { mono: true; implicitWidth: 340; value: appRow.app?.command ?? ""; onCommit: v => page.edit(x => x.spaces[spaceCol.at].apps[appRow.n].command = v) } }
                            Tile { label: I18n.tr("Window class"); Field { mono: true; implicitWidth: 340; value: appRow.app?.class ?? ""; onCommit: v => page.edit(x => x.spaces[spaceCol.at].apps[appRow.n].class = v) } }
                            }
                        }
                    }
                }
                Tile { last: true; growKey: `space-${spaceCol.at}`; icon: "add"; label: I18n.tr("Add an app"); clickable: true; onClicked: page.addApp(spaceCol.at) }
            }
        }
        Btn {
            cascade: true
            Layout.alignment: Qt.AlignHCenter
            visible: (page.a?.spaces.length ?? 0) < 8
            icon: "add"
            text: I18n.tr("Add a workspace")
            onClicked: { const id = page.uniqueId(); Ui.markAdded(`space-${page.a.spaces.length}`); page.edit(x => x.spaces.push({ id, apps: [] })); }
        }

        Head { text: I18n.tr("Navigation") }
        ToggleTile { first: true; icon: "swap_horiz"; label: I18n.tr("Move between workspaces with the arrows"); sub: I18n.tr("Super+arrows change workspace, Super+Shift+arrows bring the window along"); checked: page.a?.arrows ?? false; onToggled: v => page.edit(x => x.arrows = v) }
        ToggleTile { icon: "all_inclusive"; label: I18n.tr("Wrap around"); sub: I18n.tr("After the last workspace go back to the first"); checked: page.a?.wrap ?? false; onToggled: v => page.edit(x => x.wrap = v) }
        ToggleTile { last: true; icon: "assignment_return"; label: I18n.tr("Bring apps back"); sub: I18n.tr("Opening the area collects its apps from other workspaces"); checked: page.a?.bringBack ?? false; onToggled: v => page.edit(x => x.bringBack = v) }

        Head { text: I18n.tr("Animations") }
        SelectTile { first: true; icon: "open_in_full"; label: I18n.tr("Opening"); items: page.anims; current: page.a?.openAnimation; onPicked: v => page.edit(x => x.openAnimation = v) }
        SliderTile { icon: "speed"; label: I18n.tr("Opening duration"); from: 1; to: 20; value: page.a?.openSpeed ?? 4; onMoved: v => page.edit(x => x.openSpeed = v) }
        SelectTile { icon: "animation"; label: I18n.tr("Changing workspace"); items: page.anims; current: page.a?.switchAnimation; onPicked: v => page.edit(x => x.switchAnimation = v) }
        SliderTile { last: true; icon: "speed"; label: I18n.tr("Changing duration"); from: 1; to: 20; value: page.a?.switchSpeed ?? 5; onMoved: v => page.edit(x => x.switchSpeed = v) }

        Btn { cascade: true; Layout.alignment: Qt.AlignRight; Layout.topMargin: 14; kind: "danger"; icon: "delete"; text: I18n.tr("Delete area"); onClicked: { const i = page.sel; Ui.area = Math.max(0, i - 1); Backend.mutate(c => c.areas.splice(i, 1)); } }
    }
}
