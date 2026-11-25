pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// English strings are the keys; other languages live in i18n/<lang>.json
Singleton {
    id: root

    readonly property string wanted: Theme.prefs.language
    readonly property string lang: wanted !== "auto" ? wanted : (Quickshell.env("LANG") || "en").startsWith("it") ? "it" : "en"
    property var it: ({})

    function tr(s: string): string {
        return lang === "it" ? (it[s] ?? s) : s;
    }

    FileView {
        path: Quickshell.shellPath("i18n/it.json")
        blockLoading: true
        onLoaded: root.it = JSON.parse(text())
    }
}
