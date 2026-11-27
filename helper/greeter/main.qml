// Runs Caelestia's lock screen as a greeter (loaded by quickshell-greetd).
import QtQuick
import Quickshell
import qs.modules
import qs.modules.lock

FocusScope {
    id: root

    anchors.fill: parent
    focus: true

    // When set, quickshell-greetd shows its built-in login instead
    property string themeError: ""

    // Clock font, loaded the same way the shell does
    GSFLoader {}

    QtObject {
        id: greeterLock

        property bool locked: true
        property bool secure: true

        signal unlock
    }

    Pam {
        id: greeterPam

        lock: greeterLock
    }

    // cage stretches a single window over every monitor: one lock per screen,
    // sharing the same Pam, as Caelestia does when it locks the session.
    // QT_SCALE_FACTOR scales the size of a screen but not its position, hence the ratio.
    readonly property var screens: Quickshell.screens
    readonly property real originX: screens.length ? Math.min(...screens.map(s => s.x)) : 0
    readonly property real originY: screens.length ? Math.min(...screens.map(s => s.y)) : 0

    Repeater {
        model: root.screens

        LockSurface {
            required property var modelData
            required property int index

            // Only the first screen takes input, the others mirror it: PasswordInput
            // grabs focus back whenever it loses it, so two active ones would fight.
            enabled: index === 0
            screen: modelData
            x: (modelData.x - root.originX) / modelData.devicePixelRatio
            y: (modelData.y - root.originY) / modelData.devicePixelRatio
            width: modelData.width
            height: modelData.height
            clip: true
            lock: greeterLock
            pam: greeterPam
        }
    }
}
