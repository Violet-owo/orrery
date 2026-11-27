import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.controls

Page {
    id: page
    property var checks: []
    readonly property var names: ({
        quickshell: "Quickshell works with the installed Qt", noctaliaqs: "No incompatible Quickshell fork", hyprland: "Hyprland configuration has no errors",
        shell: "Caelestia is running", hook: "Orrery is active", conflicts: "No conflicts with hand-made configuration", spotify: "Spotify still has spicetify" })
    function run(): void { Backend.call("check", null, r => checks = r.checks ?? []); }

    title: I18n.tr("Health")
    Component.onCompleted: run()

    Head { text: I18n.tr("Checks"); Layout.topMargin: 0 }
    Repeater {
        model: page.checks.length
        Tile {
            id: checkTile
            required property int index
            readonly property var k: page.checks[index] ?? ({})
            first: index === 0
            last: index === page.checks.length - 1
            icon: k.ok ? "check_circle" : "error"
            label: I18n.tr(page.names[k.id] ?? k.id ?? "")
            sub: k.ok ? "" : [k.note, I18n.tr(k.detail ?? ""), k.fix].filter(x => x).join("\n")
            Btn {
                visible: !checkTile.k.ok && !!checkTile.k.fix
                icon: "content_copy"
                text: I18n.tr("Copy command")
                onClicked: { Quickshell.clipboardText = checkTile.k.fix; Backend.say(I18n.tr("Command copied: paste it in a terminal"), false); }
            }
            Txt { text: checkTile.k.ok ? "OK" : I18n.tr("Check"); color: checkTile.k.ok ? Theme.success : Theme.error; weight: Font.Medium }
        }
    }
    Btn { cascade: true; Layout.topMargin: 8; Layout.alignment: Qt.AlignRight; icon: "refresh"; text: I18n.tr("Check again"); onClicked: page.run() }

    Head { text: I18n.tr("Updates") }
    Tile {
        id: upd
        readonly property var u: Backend.update
        readonly property var latest: u?.latest ?? null
        readonly property string state: Backend.updating ? "updating" : Backend.checking && !u?.checked ? "checking"
            : u?.checked ? u.state : Backend.updateError ? "error" : "unknown"
        first: true
        icon: state === "newer" ? "upgrade" : state === "older" ? "history" : state === "same" ? "verified"
            : state === "error" ? "cloud_off" : "update"
        iconFill: state === "newer" ? 1 : 0
        label: ({
            updating: I18n.tr("Updating Orrery…"),
            checking: I18n.tr("Checking for updates…"),
            newer: I18n.tr("Orrery %1 is available").replace("%1", latest?.version ?? ""),
            older: I18n.tr("Stable %1 is older than this beta").replace("%1", latest?.version ?? ""),
            same: I18n.tr("Orrery is up to date"),
            none: I18n.tr("No release found for this channel"),
            error: I18n.tr("Cannot check for updates"),
            unknown: I18n.tr("Not checked yet")
        })[state] ?? ""
        sub: state === "updating" ? I18n.tr("pacman is installing the new version: Orrery restarts by itself")
            : state === "error" ? I18n.tr(Backend.updateError)
            : state === "older" ? I18n.tr("Installs it to go back to the stable channel")
            : state === "newer" ? [latest?.beta ? I18n.tr("Beta") : I18n.tr("Stable"), latest?.date].filter(x => x).join(" · ")
            : u?.checked ? I18n.tr("Checked at %1").replace("%1", new Date(u.time * 1000).toLocaleTimeString(Qt.locale(), "HH:mm")) : ""
        Btn {
            visible: !!upd.latest && (upd.state === "newer" || upd.state === "older")
            icon: "open_in_new"
            text: I18n.tr("What's new")
            onClicked: Ui.openUrl(upd.latest.url)
        }
        Btn {
            visible: !!upd.u?.canInstall
            kind: "filled"
            loading: Backend.updating
            icon: "download"
            text: upd.state === "older" ? I18n.tr("Install") : I18n.tr("Update")
            enabled: !Backend.busy && !Backend.dirty
            onClicked: Backend.installUpdate()
        }
        Btn {
            visible: !upd.u?.canInstall && !!upd.u?.command && (upd.state === "newer" || upd.state === "older")
            icon: "content_copy"
            text: I18n.tr("Copy command")
            onClicked: { Quickshell.clipboardText = upd.u.command; Backend.say(I18n.tr("Command copied: paste it in a terminal"), false); }
        }
        Btn {
            icon: "refresh"
            text: I18n.tr("Check")
            enabled: !Backend.checking && !Backend.updating
            onClicked: Backend.checkUpdates(true)
        }
    }
    SelectTile {
        icon: "alt_route"
        label: I18n.tr("Channel")
        sub: I18n.tr("Stable is tested longer, beta gets new features and fixes first")
        items: [{ value: "stable", label: I18n.tr("Stable"), sub: I18n.tr("The main branch, tested longer"), icon: "verified" },
                { value: "beta", label: I18n.tr("Beta"), sub: I18n.tr("New features and fixes first, less tested"), icon: "science" }]
        current: Backend.update?.channel ?? (Ui.version.includes("beta") ? "beta" : "stable")
        onPicked: v => {
            Theme.setPref("channel", v);
            Backend.update = Object.assign({}, Backend.update ?? {}, { channel: v, checked: false });
            recheck.restart();
        }
        Timer { id: recheck; interval: 300; onTriggered: Backend.checkUpdates(true) } // after the choice is saved
    }
    ToggleTile {
        last: true
        icon: "schedule"
        label: I18n.tr("Check for updates at start")
        sub: I18n.tr("At most once a day, asks GitHub for the newest release. Nothing is installed without you")
        checked: Theme.prefs.autoUpdate ?? true
        onToggled: v => Theme.setPref("autoUpdate", v)
    }
    Note {
        visible: Backend.dirty && !!upd.u?.canInstall
        text: I18n.tr("Apply or discard your changes before updating.")
    }
    Note {
        visible: upd.u?.mode === "source" && (upd.state === "newer" || upd.state === "older")
        text: I18n.tr("Orrery runs from its source folder: update it with git, the button copies the command.")
    }
    Note {
        visible: !!upd.u?.betaRepo && upd.u?.channel === "stable"
        warn: true
        icon: "error"
        text: I18n.tr("/etc/pacman.conf still has the [orrery-beta] repository: pacman -Syu installs betas from it. Remove those lines to stay on stable.")
    }

    Head { text: I18n.tr("Orrery") }
    Tile { first: true; icon: "undo"; label: I18n.tr("Undo the last apply"); sub: I18n.tr("Restores the files as they were before"); Btn { text: I18n.tr("Undo"); enabled: Backend.st.canUndo && !Backend.busy; onClicked: Backend.simple("undo", I18n.tr("Restored")) } }
    Tile { last: true; icon: "extension_off"; label: I18n.tr("Turn Orrery off"); sub: I18n.tr("Removes it from the Hyprland configuration and keeps your choices"); Btn { text: I18n.tr("Turn off"); enabled: Backend.st.active && !Backend.busy; onClicked: Backend.simple("disable", I18n.tr("Turned off")) } }

    Head { text: I18n.tr("About") }
    Tile {
        first: true
        icon: "person"
        iconFill: 1
        label: I18n.tr("Developed by")
        sub: Ui.portfolio.replace("https://", "").replace(/\/$/, "")
        clickable: true
        onClicked: Ui.openUrl(Ui.portfolio)
        Txt { text: Ui.author; color: Theme.primary; weight: Font.Medium }
        Ico { text: "open_in_new"; size: 18; color: Theme.fgVariant }
    }
    Tile {
        icon: "code"
        label: I18n.tr("Source code")
        sub: Ui.source.replace("https://", "")
        clickable: true
        onClicked: Ui.openUrl(Ui.source)
        Txt { text: "GPL-3.0"; color: Theme.primary; weight: Font.Medium }
        Ico { text: "open_in_new"; size: 18; color: Theme.fgVariant }
    }
    Tile { last: true; icon: "info"; label: I18n.tr("Version"); sub: I18n.tr("Unofficial: not made by the Caelestia project"); Txt { text: Ui.version; color: Theme.primary; weight: Font.Medium } }
}
