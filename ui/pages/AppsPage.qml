import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.controls

Page {
    id: page
    readonly property var sp: Backend.st.spotify
    readonly property bool ready: sp.spicetify !== "" && sp.installed && sp.kind !== "flatpak"
    readonly property bool caelestia: sp.theme === "caelestia"
    // The Spotify app in an area (Super+M), if there is one
    readonly property var music: {
        for (const [a, area] of Backend.cfg.areas.entries())
            for (const [s, space] of area.spaces.entries())
                for (const [i, app] of space.apps.entries())
                    if (/spotify/i.test(app.class)) return { a, s, i, app, area: area.name };
        return null;
    }
    readonly property bool live: !!music && music.app.command === sp.watch
    readonly property var extNames: ({
        "autoSkipExplicit.js": "Skip explicit songs", "autoSkipVideo.js": "Skip videos", "bookmark.js": "Bookmarks",
        "fullAppDisplay.js": "Full screen view", "keyboardShortcut.js": "Keyboard shortcuts", "loopyLoop.js": "Loop part of a song",
        "popupLyrics.js": "Lyrics in a window", "shuffle+.js": "Better shuffle", "trashbin.js": "Trash bin for songs and artists",
        "webnowplaying.js": "WebNowPlaying" })
    property bool working: false
    function act(data: var, ok: string): void {
        working = true;
        Backend.busy = true;
        Backend.call("spotify", data, r => {
            working = false;
            Backend.busy = false;
            Backend.say(r.ok ? I18n.tr(ok) : I18n.tr(r.error ?? ""), !r.ok);
            Backend.refresh(true);
        });
    }
    function copy(cmd: string): void {
        Quickshell.clipboardText = cmd;
        Backend.say(I18n.tr("Command copied: paste it in a terminal"), false);
    }

    title: I18n.tr("Default apps")
    intro: I18n.tr("Used for links and files, and for Caelestia's own shortcuts.")

    Repeater {
        id: rep
        model: [
            { id: "browser", icon: "language", name: "Web browser" },
            { id: "terminal", icon: "terminal", name: "Terminal" },
            { id: "editor", icon: "edit_note", name: "Text editor" },
            { id: "files", icon: "folder", name: "File manager" },
            { id: "images", icon: "image", name: "Images" },
            { id: "video", icon: "movie", name: "Video" },
            { id: "music", icon: "music_note", name: "Music" },
            { id: "pdf", icon: "picture_as_pdf", name: "PDF" },
            { id: "mail", icon: "mail", name: "Mail" }
        ]

        SelectTile {
            required property var modelData
            required property int index

            first: index === 0
            last: index === rep.count - 1
            icon: modelData.icon
            label: I18n.tr(modelData.name)
            sub: current === "" ? now : ""
            current: Backend.cfg.apps[modelData.id]
            readonly property string now: Backend.appsById[Backend.st.defaults[modelData.id]]?.name ?? ""
            items: [{ value: "", label: I18n.tr("Leave as it is"), sub: now }].concat((Backend.st.roles[modelData.id] ?? []).map(i => ({ value: i, label: Backend.appsById[i]?.name ?? i, sub: Backend.appsById[i]?.command })))
            onPicked: v => Backend.mutate(c => c.apps[modelData.id] = v)
        }
    }

    Head { text: "Spotify" }
    Tile {
        first: true
        last: page.ready
        visible: !page.sp.installed || !page.sp.spicetify || page.sp.kind === "flatpak"
        icon: "music_note"
        label: page.sp.kind === "flatpak" ? I18n.tr("Spotify from Flatpak is not supported yet")
             : !page.sp.spicetify ? I18n.tr("spicetify is not installed") : I18n.tr("Spotify was not found")
        sub: page.sp.kind === "flatpak" ? I18n.tr("Install spotify-launcher instead to use these options.")
           : !page.sp.spicetify ? I18n.tr("spicetify customises Spotify: colours, extensions. Copy the command and run it in a terminal.")
           : I18n.tr("Install spotify-launcher, open it once, then come back.")
        Btn {
            visible: page.sp.kind !== "flatpak"
            icon: "content_copy"
            text: I18n.tr("Copy command")
            onClicked: page.copy(!page.sp.spicetify ? "paru -S spicetify-cli" : "sudo pacman -S spotify-launcher")
        }
        Btn { icon: "open_in_new"; kind: "text"; onClicked: Ui.openUrl("https://spicetify.app/docs/getting-started") }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.ready
        spacing: Theme.gap
        Tile {
            first: true
            icon: page.sp.applied ? "check_circle" : "error"
            label: page.sp.applied ? I18n.tr("spicetify is active") : I18n.tr("spicetify is not applied")
            sub: (page.sp.applied ? "" : I18n.tr("Spotify updates remove it: apply it again.") + " ") + `spicetify ${page.sp.version} · ${page.sp.kind}`
            Btn { text: I18n.tr("Apply"); kind: page.sp.applied ? "tonal" : "filled"; enabled: !Backend.busy; onClicked: page.act({ action: "apply" }, "Applied to Spotify") }
            Btn { text: I18n.tr("Restore"); kind: "text"; visible: page.sp.applied; enabled: !Backend.busy; onClicked: page.act({ action: "restore" }, "Spotify is back to normal") }
        }
        ToggleTile {
            icon: "palette"
            label: I18n.tr("Spotify follows Caelestia's colours")
            sub: page.caelestia ? I18n.tr("Uses the theme Caelestia updates with your wallpaper") : page.sp.theme ? I18n.tr("Now: %1. Turning it off puts it back.").replace("%1", page.sp.theme) : ""
            checked: page.caelestia
            enabled: !Backend.busy
            onToggled: v => page.act({ action: "colours", on: v }, v ? "Spotify now uses Caelestia's colours" : "Previous theme restored")
        }
        ToggleTile {
            visible: !!page.music
            dim: !page.caelestia
            icon: "bolt"
            label: I18n.tr("Colours change live")
            sub: I18n.tr("Starts Spotify from %1 with spicetify watching the theme: no restart when the wallpaper changes. Saved with Apply.").replace("%1", page.music?.area ?? "")
            checked: page.live
            onToggled: v => Backend.mutate(c => c.areas[page.music.a].spaces[page.music.s].apps[page.music.i].command = v ? page.sp.watch : (Backend.st.apps.find(a => /spotify/i.test(a.id))?.command ?? "spotify"))
        }
        Head { text: I18n.tr("Spotify extensions") }
        Repeater {
            id: exts
            model: page.sp.extensions
            ToggleTile {
                required property var modelData
                required property int index
                first: index === 0
                last: index === exts.count - 1
                icon: "extension"
                label: I18n.tr(page.extNames[modelData.name] ?? modelData.name.replace(/\.js$/, ""))
                sub: modelData.name
                checked: modelData.on
                enabled: !Backend.busy
                onToggled: v => page.act({ action: "extension", name: modelData.name, on: v }, "Applied to Spotify")
            }
        }
        Note {
            text: I18n.tr("These options act right away and restart Spotify. spicetify modifies the Spotify app, which Spotify's terms do not allow: use it knowing that.")
        }
    }
    OrreryLoader { Layout.alignment: Qt.AlignHCenter; size: 64; visible: page.working }
}
