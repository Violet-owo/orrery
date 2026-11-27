import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.controls

Page {
    id: page
    readonly property var login: Backend.st.system.login
    readonly property bool mine: login.command === "/usr/lib/orrery/orrery-greeter-session"
    readonly property bool packages: login.packages["cage"] && login.packages["quickshell-greetd"] && login.packages["caelestia-shell"] !== false
    readonly property var first: Backend.cfg.keyboard.layouts[0]
    property real loginScale: 1
    property bool digits: true
    property bool armed: false

    title: I18n.tr("Login")
    intro: I18n.tr("Use Caelestia's lock screen as the login screen. Colours, wallpaper and picture follow your theme.")

    Tile {
        first: true
        icon: page.mine ? "check_circle" : "login"
        label: page.mine ? I18n.tr("Login managed by Orrery") : I18n.tr("Not managed by Orrery")
        sub: page.login.greetd ? page.login.command : I18n.tr("greetd is not configured")
    }
    // Only one login manager runs at a time: Orrery's login needs greetd
    Tile {
        id: dmTile
        readonly property bool onGreetd: page.login.dm === "greetd"
        icon: onGreetd ? "how_to_reg" : "swap_horiz"
        label: page.login.dm ? I18n.tr("Login manager: %1").replace("%1", page.login.dm) : I18n.tr("No login manager found")
        sub: onGreetd ? (page.login.previousDm ? I18n.tr("Switched from %1 by Orrery.").replace("%1", page.login.previousDm) : "")
             : page.login.greetdInstalled ? I18n.tr("Orrery's login needs greetd. The switch happens at the next boot and can be undone here.")
             : I18n.tr("Orrery's login needs greetd: install it first.")
        Btn {
            visible: !dmTile.onGreetd && page.login.greetdInstalled
            text: I18n.tr("Switch to greetd")
            kind: "filled"
            enabled: !Backend.busy
            onClicked: Ui.pick(I18n.tr("Switch to greetd at the next boot?"), [
                { value: true, label: I18n.tr("Switch at the next boot"), sub: I18n.tr("%1 keeps working until then").replace("%1", page.login.dm || "—") },
                { value: false, label: I18n.tr("Cancel") }], false, v => {
                    if (v) Backend.helper(["dm-greetd"], I18n.tr("greetd will start at the next boot"));
                })
        }
        Btn {
            visible: !page.login.greetdInstalled
            icon: "content_copy"
            text: I18n.tr("Copy command")
            onClicked: { Quickshell.clipboardText = "paru -S greetd cage quickshell-greetd"; Backend.say(I18n.tr("Command copied: paste it in a terminal"), false); }
        }
        Btn {
            visible: dmTile.onGreetd && !!page.login.previousDm
            text: I18n.tr("Back to %1").replace("%1", page.login.previousDm)
            enabled: !Backend.busy
            onClicked: Backend.helper(["dm-restore"], I18n.tr("%1 will start at the next boot").replace("%1", page.login.previousDm))
        }
    }
    Tile {
        last: true
        icon: page.packages ? "package_2" : "deployed_code_alert"
        label: I18n.tr("Required packages")
        sub: Object.entries(page.login.packages).map(([n, ok]) => `${n} ${ok ? "✓" : "✗"}`).join("   ")
    }

    Head { text: I18n.tr("Options") }
    Tile { first: true; icon: "keyboard"; label: I18n.tr("Keyboard layout"); sub: I18n.tr("The first layout of the Keyboard page"); Txt { text: page.first.layout + (page.first.variant ? ` (${page.first.variant})` : ""); color: Theme.primary; weight: Font.Medium } }
    SliderTile { icon: "zoom_in"; label: I18n.tr("Scale"); sub: I18n.tr("Use the same scale as your monitor"); from: 0.75; to: 2.5; step: 0.25; value: page.loginScale; onMoved: v => page.loginScale = v }
    ToggleTile { last: true; icon: "dialpad"; label: I18n.tr("Numeric keypad always types digits"); checked: page.digits; onToggled: v => page.digits = v }

    Note {
        warn: true
        icon: "warning"
        text: I18n.tr("Experimental. If the login screen stays black press Ctrl+Alt+F3, log in and run:") + "\nsudo /usr/lib/orrery/orrery-helper login-disable"
    }

    RowLayout {
        Layout.topMargin: 16
        Layout.alignment: Qt.AlignRight
        spacing: 8
        Btn { cascade: true; visible: page.mine; text: I18n.tr("Restore previous login"); onClicked: Backend.helper(["login-disable"], I18n.tr("Restored, from the next boot")); enabled: !Backend.busy }
        Btn { cascade: true; visible: page.mine; text: I18n.tr("Update look now"); onClicked: Backend.helper(["login-sync"], I18n.tr("Applied")); enabled: !Backend.busy }
        Btn {
            cascade: true
            kind: page.armed ? "danger" : "filled"
            icon: page.armed ? "warning" : ""
            text: page.armed ? I18n.tr("Confirm: change the login screen") : I18n.tr("Enable")
            enabled: Backend.st.system.helper && page.packages && page.login.greetd && !Backend.busy
            onClicked: {
                if (!page.armed)
                    return page.armed = true;
                page.armed = false;
                Backend.helper(["login-enable", Quickshell.env("USER"), page.first.layout, page.first.variant || "-", String(page.loginScale), page.digits ? "1" : "0"], I18n.tr("Enabled, from the next boot"));
            }
        }
    }
    Note {
        visible: page.login.packages["caelestia-shell"] === false
        icon: "info"
        text: I18n.tr("The login screen is built from Caelestia installed from the AUR (caelestia-shell). A copy installed from git in your home cannot be used: the login screen is shared by every user of this computer.")
    }
    Note { visible: !Backend.st.system.helper; icon: "lock"; text: I18n.tr("Install the Orrery package to enable this: the system helper is missing.") }
}
