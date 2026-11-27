import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.controls

Page {
    id: page
    readonly property var w: Backend.st.walls
    readonly property string folder: dir.value || w.suggested || ""
    readonly property bool mismatch: w.dir !== w.suggested && !w.exists

    function send(cmd: string, data: var, ok: var): void {
        Backend.busy = true;
        Backend.call(cmd, data, r => {
            Backend.busy = false;
            Backend.say(r.ok ? ok(r) : r.error, !r.ok);
            Backend.refresh(true);
        });
    }

    readonly property var gifs: Backend.cfg.shell?.gifs ?? null
    readonly property var desk: Backend.cfg.shell?.desktop ?? null
    readonly property var slots: [
        { id: "media", name: "Media", sub: "Dashboard, moves to the music", animated: true },
        { id: "session", name: "Shut down menu", sub: "Between the buttons", animated: true },
        { id: "notifs", name: "No notifications", sub: "Sidebar, as a silhouette", animated: false },
        { id: "lock", name: "Lock screen", sub: "No notifications, as a silhouette", animated: false }]
    function picUrl(slot: string): string {
        const v = gifs?.[slot] ?? "";
        if (!v) return "";
        const p = v === Backend.st.shell.defaults.gifs[slot] ? Backend.st.pics.defaults[slot] : Backend.st.pics.thumbs?.[v] ?? v.replace(/^(~|\$HOME|\$\{HOME\})(?=\/|$)/, Quickshell.env("HOME"));
        return p ? `file://${p}` : "";
    }

    title: I18n.tr("Wallpapers")
    intro: I18n.tr("Creates the wallpaper folder, tells Caelestia where it is and refreshes its list: no restart needed.")

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        spacing: 12
        Repeater {
            model: [{ id: "dawn", name: "Light", icon: "light_mode" }, { id: "night", name: "Dark", icon: "dark_mode" }]
            Rectangle {
                id: card
                required property var modelData
                required property int index
                property bool hot: hover.containsMouse || (hover.activeFocus && Nav.keys)
                Layout.fillWidth: true
                implicitHeight: width * 9 / 16
                radius: hover.pressed ? Theme.rXs : hot ? Theme.rMd : Theme.rLg
                topLeftRadius: radius; topRightRadius: radius; bottomLeftRadius: radius; bottomRightRadius: radius
                color: Theme.tile
                opacity: enter.p
                scale: hover.pressed ? 0.97 : 1
                transform: Translate { y: (1 - enter.p) * 34 }
                Behavior on radius { Anim {} }
                Behavior on scale { Anim { kind: "fast" } }
                Enter { id: enter }

                Image {
                    id: img
                    anchors.fill: parent
                    visible: false
                    source: page.w.previews ? `file://${page.w.previews[card.modelData.id]}` : ""
                    sourceSize.width: 800
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    scale: card.hot ? 1.05 : 1
                    layer.enabled: true
                }
                Rectangle { id: shape; anchors.fill: parent; radius: card.radius; visible: false; layer.enabled: true }
                MultiEffect {
                    anchors.fill: parent
                    source: img
                    maskEnabled: true
                    maskSource: shape
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                    opacity: img.status === Image.Ready ? 1 : 0
                    Behavior on opacity { Anim { kind: "fxSlow" } }
                }
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                    width: tag.implicitWidth + 28
                    height: 36
                    radius: 18
                    color: Theme.primary
                    RowLayout {
                        id: tag
                        anchors.centerIn: parent
                        spacing: 8
                        Ico { text: card.modelData.icon; size: 18; fill: 1; color: Theme.fgPrimary }
                        Txt { text: I18n.tr(card.modelData.name); color: Theme.fgPrimary; weight: Font.Medium }
                    }
                }
                Hover {
                    id: hover
                    tint: "white"
                    onClicked: {
                        if (Backend.busy)
                            return;
                        const use = () => page.send("use-wallpaper", { name: card.modelData.id }, () => I18n.tr("Wallpaper changed"));
                        if (page.w.installed)
                            return use();
                        Backend.busy = true;
                        Backend.call("wallpapers", { dir: page.folder }, r => {
                            Backend.busy = false;
                            if (!r.ok)
                                return Backend.say(r.error, true);
                            use();
                        });
                    }
                }
            }
        }
    }
    Txt { Layout.leftMargin: 8; Layout.bottomMargin: 10; text: I18n.tr("Choose one to set it, with its light or dark theme and matching colours."); size: 12; color: Theme.fgVariant }

    Head { text: I18n.tr("Folder"); Layout.topMargin: 4 }
    Tile {
        first: true
        icon: page.w.exists ? "folder" : "folder_off"
        label: I18n.tr("Where Caelestia looks")
        sub: (page.w.dir ?? "") + (page.w.exists ? " · " + I18n.tr("%1 files").replace("%1", page.w.files) : " · " + I18n.tr("does not exist"))
    }
    Tile {
        icon: "drive_file_rename_outline"
        label: I18n.tr("Folder to use")
        Field { id: dir; mono: true; implicitWidth: 360; value: page.w.suggested ?? ""; onCommit: v => dir.value = v }
    }
    Tile {
        last: true
        icon: "auto_fix_high"
        label: I18n.tr("Set up the wallpapers")
        sub: I18n.tr("Creates the folder, adds the two wallpapers and refreshes Caelestia. Your images are not touched.")
        Btn {
            text: page.w.installed && page.w.seen ? I18n.tr("Refresh") : I18n.tr("Set up")
            kind: "filled"
            enabled: !Backend.busy
            onClicked: page.send("wallpapers", { dir: page.folder }, r => r.live ? I18n.tr("Done: Caelestia already sees them") : I18n.tr("Done. Caelestia is not running or did not answer"))
        }
    }
    Note {
        visible: page.mismatch
        icon: "lightbulb"
        text: I18n.tr("Caelestia looks in a folder that does not exist: on this system your pictures are in %1.").replace("%1", page.w.suggested ?? "")
    }

    // --- On the desktop: Caelestia's clock and audio bars over the wallpaper
    Head { text: I18n.tr("On the desktop"); visible: !!page.desk }
    Rectangle {
        id: preview
        visible: !!page.desk
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        implicitHeight: width * 9 / 16 * 0.62
        radius: Theme.rLg
        color: Theme.container
        clip: true
        Image {
            anchors.fill: parent
            source: Backend.st.pics.wallpaper ? `file://${Backend.st.pics.wallpaper}` : ""
            sourceSize.width: 900
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        // Bars like Caelestia's visualiser, still: a picture of where they go
        Row {
            visible: page.desk?.vis ?? false
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
            spacing: 3 * (page.desk?.visSpacing ?? 1)
            Repeater {
                model: 40
                Rectangle {
                    required property int index
                    width: (preview.width - 28) / 40 - 3 * (page.desk?.visSpacing ?? 1)
                    height: 12 + 40 * Math.abs(Math.sin(index * 0.55) * Math.cos(index * 0.17))
                    anchors.bottom: parent.bottom
                    radius: width / 2 * (page.desk?.visRounding ?? 1)
                    color: Qt.alpha(Theme.primary, 0.75)
                }
            }
        }
        Rectangle {
            id: clockBox
            visible: page.desk?.clock ?? false
            readonly property var at: (page.desk?.clockPosition ?? "bottom-right").split("-")
            x: at[1] === "left" ? 18 : at[1] === "center" ? (preview.width - width) / 2 : preview.width - width - 18
            y: at[0] === "top" ? 18 : at[0] === "middle" ? (preview.height - height) / 2 : preview.height - height - 18
            width: clockCol.implicitWidth + 28
            height: clockCol.implicitHeight + 18
            radius: Theme.rMd
            color: page.desk?.clockBg ? Qt.alpha(Theme.container, page.desk.clockBgOpacity) : "transparent"
            Behavior on x { Anim {} }
            Behavior on y { Anim {} }
            Column {
                id: clockCol
                anchors.centerIn: parent
                scale: page.desk?.clockScale ?? 1
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(new Date(), "hh:mm")
                    size: 34
                    weight: Font.Bold
                    color: page.desk?.clockInvert ? Theme.fg : Theme.primary
                    style: page.desk?.clockShadow ? Text.Raised : Text.Normal
                    styleColor: Qt.alpha("black", page.desk?.clockShadowOpacity ?? 0.7)
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(new Date(), "dddd d MMMM")
                    size: 12
                    color: page.desk?.clockInvert ? Theme.fgVariant : Theme.fg
                }
            }
        }
    }
    ToggleTile {
        first: true
        visible: !!page.desk
        icon: "schedule"
        label: I18n.tr("Clock on the desktop")
        checked: page.desk?.clock ?? false
        onToggled: v => Backend.mutate(c => c.shell.desktop.clock = v)
    }
    SelectTile {
        visible: !!page.desk
        dim: !page.desk?.clock
        icon: "open_with"
        label: I18n.tr("Position")
        items: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
            .map(v => ({ value: v, label: I18n.tr(v.split("-").map(w => w[0].toUpperCase() + w.slice(1)).join(" ")) }))
        current: page.desk?.clockPosition
        onPicked: v => Backend.mutate(c => c.shell.desktop.clockPosition = v)
    }
    SliderTile {
        visible: !!page.desk
        dim: !page.desk?.clock
        icon: "format_size"
        label: I18n.tr("Size")
        from: 0.5; to: 3; step: 0.1; suffix: "×"
        value: page.desk?.clockScale ?? 1
        onMoved: v => Backend.mutate(c => c.shell.desktop.clockScale = v)
    }
    ToggleTile {
        visible: !!page.desk
        dim: !page.desk?.clock
        icon: "invert_colors"
        label: I18n.tr("Inverted colours")
        checked: page.desk?.clockInvert ?? false
        onToggled: v => Backend.mutate(c => c.shell.desktop.clockInvert = v)
    }
    ToggleTile {
        visible: !!page.desk
        dim: !page.desk?.clock
        icon: "rectangle"
        label: I18n.tr("Background behind the clock")
        sub: I18n.tr("Blurred, like Caelestia's panels")
        checked: page.desk?.clockBg ?? false
        onToggled: v => Backend.mutate(c => c.shell.desktop.clockBg = v)
    }
    ToggleTile {
        visible: !!page.desk
        dim: !page.desk?.clock
        icon: "shadow"
        label: I18n.tr("Shadow")
        checked: page.desk?.clockShadow ?? true
        onToggled: v => Backend.mutate(c => c.shell.desktop.clockShadow = v)
    }
    ToggleTile {
        visible: !!page.desk
        icon: "graphic_eq"
        label: I18n.tr("Audio bars on the desktop")
        sub: I18n.tr("Move with the music playing")
        checked: page.desk?.vis ?? false
        onToggled: v => Backend.mutate(c => c.shell.desktop.vis = v)
    }
    ToggleTile {
        visible: !!page.desk
        dim: !page.desk?.vis
        icon: "visibility_off"
        label: I18n.tr("Hide them when nothing plays")
        checked: page.desk?.visAutoHide ?? true
        onToggled: v => Backend.mutate(c => c.shell.desktop.visAutoHide = v)
    }
    SliderTile {
        visible: !!page.desk
        dim: !page.desk?.vis
        icon: "rounded_corner"
        label: I18n.tr("Bar rounding")
        from: 0; to: 2; step: 0.1; suffix: "×"
        value: page.desk?.visRounding ?? 1
        onMoved: v => Backend.mutate(c => c.shell.desktop.visRounding = v)
    }
    SliderTile {
        visible: !!page.desk
        last: true
        dim: !page.desk?.vis
        icon: "space_bar"
        label: I18n.tr("Bar spacing")
        from: 0; to: 4; step: 0.1; suffix: "×"
        value: page.desk?.visSpacing ?? 1
        onMoved: v => Backend.mutate(c => c.shell.desktop.visSpacing = v)
    }

    Head { text: I18n.tr("GIFs and pictures") }
    Txt { Layout.leftMargin: 8; Layout.bottomMargin: 6; text: I18n.tr("What Caelestia shows in its panels. Choose one from your files or from GIPHY: it changes live once applied."); size: 12; color: Theme.fgVariant; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    Note {
        visible: !page.gifs
        warn: true
        icon: "error"
        text: I18n.tr("Caelestia's shell.json cannot be read: fix it first, Orrery will not overwrite it.")
    }
    GridLayout {
        Layout.fillWidth: true
        visible: !!page.gifs
        columns: width > 760 ? 4 : 2
        columnSpacing: 12
        rowSpacing: 12
        Repeater {
            model: page.slots
            Rectangle {
                id: slot
                required property var modelData
                readonly property bool changed: !!page.gifs && page.gifs[modelData.id] !== Backend.st.shell.defaults.gifs[modelData.id]
                property bool hot: pick.containsMouse || (pick.activeFocus && Nav.keys)
                Layout.fillWidth: true
                implicitHeight: 230
                radius: pick.pressed ? Theme.rXs : hot ? Theme.rMd : Theme.rLg
                topLeftRadius: radius; topRightRadius: radius; bottomLeftRadius: radius; bottomRightRadius: radius
                color: Theme.tile
                opacity: enterSlot.p
                transform: Translate { y: (1 - enterSlot.p) * 34 }
                Behavior on radius { Anim {} }
                Enter { id: enterSlot }

                Rectangle {
                    id: stage
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    height: 150
                    radius: Theme.rMd
                    color: Theme.container
                    AnimatedImage {
                        id: anim
                        anchors { fill: parent; margins: 14 }
                        visible: slot.modelData.animated
                        source: slot.modelData.animated ? page.picUrl(slot.modelData.id) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        playing: visible && Ui.awake
                        // Caelestia: media follows the beat (shown at 120 BPM), the menu has a fixed speed
                        speed: slot.modelData.id === "media" ? 120 / (page.gifs?.mediaSpeed || 300) : (page.gifs?.sessionSpeed ?? 0.7)
                    }
                    Image {
                        id: still
                        anchors { fill: parent; margins: 18 }
                        visible: false
                        source: slot.modelData.animated ? "" : page.picUrl(slot.modelData.id)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 400
                    }
                    MultiEffect {
                        anchors.fill: still
                        visible: !slot.modelData.animated
                        source: still
                        colorization: 1
                        colorizationColor: Theme.outline
                        brightness: 1
                    }
                    Ico {
                        anchors.centerIn: parent
                        visible: (slot.modelData.animated ? anim.status : still.status) === Image.Error
                        text: "broken_image"; color: Theme.error
                    }
                }
                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; top: stage.bottom; leftMargin: 18; rightMargin: 10; topMargin: 10 }
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt { Layout.fillWidth: true; text: I18n.tr(slot.modelData.name); size: 15; elide: Text.ElideRight }
                            Txt { Layout.fillWidth: true; text: I18n.tr(slot.modelData.sub); size: 12; color: Theme.fgVariant; elide: Text.ElideRight }
                        }
                    }
                }
                Hover {
                    id: pick
                    onClicked: Ui.gifPicker.show(I18n.tr(slot.modelData.name), path => Backend.mutate(c => c.shell.gifs[slot.modelData.id] = path))
                }
                Btn {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                    visible: slot.changed
                    icon: "restart_alt"
                    kind: "text"
                    onClicked: Backend.mutate(c => c.shell.gifs[slot.modelData.id] = Backend.st.shell.defaults.gifs[slot.modelData.id])
                }
            }
        }
    }
    SliderTile {
        first: true
        visible: !!page.gifs
        icon: "music_note"
        label: I18n.tr("Media speed")
        sub: I18n.tr("Follows the beat of the music, faster or slower than Caelestia's")
        from: 0.25; to: 3; step: 0.05; suffix: "×"
        value: page.gifs ? Math.round(300 / page.gifs.mediaSpeed * 20) / 20 : 1
        onMoved: v => Backend.mutate(c => c.shell.gifs.mediaSpeed = Math.round(300 / v))
    }
    SliderTile {
        visible: !!page.gifs
        icon: "speed"
        label: I18n.tr("Shut down menu speed")
        from: 0.1; to: 3; step: 0.05; suffix: "×"
        value: page.gifs?.sessionSpeed ?? 0.7
        onMoved: v => Backend.mutate(c => c.shell.gifs.sessionSpeed = Math.round(v * 100) / 100)
    }
    Tile {
        id: originals
        last: true
        visible: !!page.gifs
        readonly property bool saved: Object.values(Backend.st.pics.originals).some(v => v)
        icon: "inventory_2"
        label: I18n.tr("Caelestia's originals")
        sub: originals.saved ? I18n.tr("A copy is in Orrery's folder: it stays even if an update changes or removes them. Restore puts every picture and speed back.")
                   : I18n.tr("Saves a copy of Caelestia's own pictures in Orrery's folder, so you can always go back to them.")
        Btn {
            text: originals.saved ? I18n.tr("Copy again") : I18n.tr("Back up")
            kind: "tonal"
            enabled: !Backend.busy
            onClicked: page.send("pic-originals", {}, () => I18n.tr("Caelestia's pictures saved"))
        }
        Btn {
            text: I18n.tr("Restore")
            enabled: !Backend.busy
            onClicked: Backend.mutate(c => {
                const d = Backend.st.shell.defaults.gifs, p = Backend.st.pics;
                for (const k of ["media", "session", "notifs", "lock"])
                    c.shell.gifs[k] = p.defaultsOk[k] || !p.originals[k] ? d[k] : p.originals[k];
                c.shell.gifs.mediaSpeed = d.mediaSpeed;
                c.shell.gifs.sessionSpeed = d.sessionSpeed;
            })
        }
    }
}

