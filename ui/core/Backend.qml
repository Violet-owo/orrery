pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string ctl: Quickshell.env("ORRERY_CTL") || Quickshell.shellPath("../lib/orreryctl.py")
    property var st: null
    property var cfg: null
    property string savedJson: ""
    property bool busy: false
    property string message: ""
    property bool messageIsError: false
    readonly property bool ready: st !== null && cfg !== null
    readonly property bool dirty: ready && JSON.stringify(cfg) !== savedJson

    property var appsById: ({})

    property var past: []
    property var future: []

    function mutate(fn: var): void {
        const copy = JSON.parse(JSON.stringify(cfg));
        fn(copy);
        if (JSON.stringify(copy) === JSON.stringify(cfg))
            return;
        past = past.concat([JSON.stringify(cfg)]).slice(-100);
        future = [];
        cfg = copy;
    }
    function stepBack(): void {
        if (!past.length)
            return;
        future = future.concat([JSON.stringify(cfg)]);
        cfg = JSON.parse(past[past.length - 1]);
        past = past.slice(0, -1);
    }
    function stepForward(): void {
        if (!future.length)
            return;
        past = past.concat([JSON.stringify(cfg)]);
        cfg = JSON.parse(future[future.length - 1]);
        future = future.slice(0, -1);
    }
    function discard(): void {
        mutate(c => {
            const s = JSON.parse(savedJson);
            for (const k in s)
                c[k] = s[k];
        });
    }

    function say(text: string, error: bool): void {
        messageIsError = error; // first: the toast reads it when the text changes
        message = text;
        clear.restart();
    }

    function exec(argv: var, input: string, done: var): void {
        job.createObject(root, { command: argv, input: input, done: done });
    }

    function call(cmd: string, data: var, done: var): void {
        exec(["python3", "-I", ctl, cmd], data === null ? "" : JSON.stringify(data), (code, out, err) => {
            let r;
            try {
                r = JSON.parse(out);
            } catch (e) {
                r = { ok: false, error: err || `exit ${code}` };
            }
            done(r);
        });
    }

    function refresh(keepEdits: bool, after: var): void {
        call("state", null, r => {
            if (r.error) {
                if (after)
                    after();
                return say(r.error, true);
            }
            const byId = {};
            for (const a of r.apps)
                byId[a.id] = a;
            appsById = byId;
            st = r;
            if (!keepEdits || !cfg) {
                cfg = r.config;
                savedJson = JSON.stringify(r.config);
                past = [];
                future = [];
            }
            if (after)
                after();
        });
    }

    property bool quitAfterApply: false

    function apply(): void {
        if (busy)
            return;
        busy = true;
        call("apply", cfg, r => {
            const quit = quitAfterApply;
            quitAfterApply = false;
            if (!r.ok) {
                busy = false;
                return say(r.error, true);
            }
            if (quit)
                return Qt.quit();
            // Still busy until the new state is read: the bar leaves once, instead of flashing back first
            refresh(false, () => {
                busy = false;
                say(I18n.tr("Applied"), false);
            });
        });
    }

    function simple(cmd: string, okText: string): void {
        busy = true;
        call(cmd, null, r => {
            busy = false;
            say(r.error ?? okText, !!r.error);
            refresh(false);
        });
    }

    function helper(args: var, okText: string): void {
        busy = true;
        exec(["pkexec", "/usr/lib/orrery/orrery-helper", ...args], "", (code, out, err) => {
            busy = false;
            say(code === 0 ? okText : code === 126 || code === 127 ? I18n.tr("Authentication cancelled") : (err || out).trim(), code !== 0);
            refresh(true);
        });
    }

    Component.onCompleted: refresh(false)

    Timer {
        id: clear
        interval: 7000
        onTriggered: root.message = ""
    }

    Component {
        id: job

        Process {
            id: proc
            property string input
            property var done
            property int code: -1
            property int pending: 3

            function part(): void {
                if (--pending === 0) {
                    done(code, out.text, err.text);
                    destroy();
                }
            }

            running: true
            stdinEnabled: true
            onStarted: {
                if (input)
                    write(input);
                stdinEnabled = false;
            }
            onExited: c => {
                code = c;
                part();
            }
            stdout: StdioCollector {
                id: out
                onStreamFinished: proc.part()
            }
            stderr: StdioCollector {
                id: err
                onStreamFinished: proc.part()
            }
        }
    }
}
