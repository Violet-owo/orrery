// Stands in for Caelestia's modules/lock/Pam.qml: same interface, but authentication
// goes through greetd (QsGreet.Auth) instead of PAM. Derived from Caelestia, GPL-3.0.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QsGreet

Scope {
    id: root

    enum PamState {
        None,
        Error,
        MaxTries,
        Failed
    }

    required property var lock

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy

    property string lockMessage
    property int state
    property string buffer

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        if (passwd.active)
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if (event.key === Qt.Key_Escape) {
            buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier)
                buffer = "";
            else
                buffer = buffer.slice(0, -1);
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            buffer += event.text;
        }
    }

    function fail(newState: int, message: string): void {
        passwd.message = message;
        state = newState;
        flashMsg();
        stateReset.restart();
    }

    QtObject {
        id: passwd

        readonly property bool active: Auth.busy
        property string message

        function start(): void {
            if (Auth.busy || root.buffer.length === 0)
                return;
            const secret = root.buffer;
            root.buffer = "";
            root.state = Pam.None;
            root.lockMessage = "";
            Auth.login(Users.selectedName, secret);
        }

        function abort(): void {
            Auth.cancel();
        }
    }

    // Fingerprint and face are not handled by the greeter
    component Unavailable: QtObject {
        readonly property bool available: false
        readonly property bool enabled: false
        readonly property bool active: false
        readonly property bool canAttempt: false
        readonly property int tries: 0
        readonly property int errorTries: 0
        readonly property int maxTries: 0
        readonly property int state: Pam.None
        readonly property string message: ""

        function start(): void {}
        function abort(): void {}
        function reset(): void {}
    }

    Unavailable {
        id: fprint
    }

    Unavailable {
        id: howdy
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: root.state = Pam.None
    }

    Connections {
        target: Auth

        function onFailed(message: string): void {
            // A wrong password is Failed; anything else shows its message
            if (/auth/i.test(message))
                root.fail(Pam.Failed, message);
            else
                root.fail(Pam.Error, message);
        }

        // Extra PAM questions (expired password, OTP) are not supported here:
        // cancel and say so.
        function onPromptRequested(message: string, echo: bool): void {
            Auth.cancel();
            root.fail(Pam.Error, message);
        }

        function onInfo(message: string, error: bool): void {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
        }

        function onLaunching(): void {
            root.lock.unlock();
        }
    }
}
