import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    id: page
    property var checks: []
    readonly property var names: ({
        quickshell: "Quickshell works with the installed Qt", noctaliaqs: "No incompatible Quickshell fork", hyprland: "Hyprland configuration has no errors",
        shell: "Caelestia is running", hook: "Orrery is active", conflicts: "No conflicts with hand-made configuration" })
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
            sub: k.ok ? "" : (k.detail ?? "")
            Txt { text: checkTile.k.ok ? "OK" : I18n.tr("Check"); color: checkTile.k.ok ? Theme.success : Theme.error; weight: Font.Medium }
        }
    }
    Btn { cascade: true; Layout.topMargin: 8; Layout.alignment: Qt.AlignRight; icon: "refresh"; text: I18n.tr("Check again"); onClicked: page.run() }

    Head { text: I18n.tr("Orrery") }
    Tile { first: true; icon: "undo"; label: I18n.tr("Undo the last apply"); sub: I18n.tr("Restores the files as they were before"); Btn { text: I18n.tr("Undo"); enabled: Backend.st.canUndo && !Backend.busy; onClicked: Backend.simple("undo", I18n.tr("Restored")) } }
    Tile { last: true; icon: "extension_off"; label: I18n.tr("Turn Orrery off"); sub: I18n.tr("Removes it from the Hyprland configuration and keeps your choices"); Btn { text: I18n.tr("Turn off"); enabled: Backend.st.active && !Backend.busy; onClicked: Backend.simple("disable", I18n.tr("Turned off")) } }
}
