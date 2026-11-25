import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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
}
