// Runs Caelestia's lock screen as a greeter (loaded by quickshell-greetd).
import QtQuick
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

    LockSurface {
        id: surface

        anchors.fill: parent
        lock: greeterLock
        pam: greeterPam
    }
}
