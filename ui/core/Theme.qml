pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Follows Caelestia live: palette, transparency and fonts.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    readonly property string confDir: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`

    property var c: ({})
    property bool light: false

    // Caelestia's own values
    property bool shellTransparent: false
    property real shellBase: 0.85
    property real shellLayers: 0.4
    property real shellSpeed: 1

    // Orrery's preferences (~/.config/orrery/ui.json)
    property var prefs: ({ language: "auto", follow: true, transparent: true, base: 0.85, layers: 0.4, speed: 1, rounding: 1, channel: "auto", autoUpdate: true })
    readonly property bool transparent: prefs.follow ? shellTransparent : prefs.transparent
    readonly property real baseAlpha: prefs.follow ? shellBase : prefs.base
    readonly property real layerAlpha: prefs.follow ? shellLayers : prefs.layers
    readonly property real animScale: Math.max(0.01, Math.min(4, prefs.follow ? shellSpeed : prefs.speed))

    function setPrefs(changes: var): void {
        prefs = Object.assign({}, prefs, changes);
        Backend.call("prefs", changes, r => {
            if (!r.ok)
                Backend.say(r.error, true);
        });
    }
    function setPref(key: string, value: var): void {
        setPrefs({ [key]: value });
    }

    // Same layering as Caelestia: layer 0 is the window, higher layers are brighter and thinner
    function layer(c: color, n: int): color {
        if (!transparent)
            return c;
        if (n === 0)
            return Qt.alpha(c, Math.max(0.05, baseAlpha - (light ? 0.1 : 0)));
        const lum = Math.sqrt(0.299 * c.r ** 2 + 0.587 * c.g ** 2 + 0.114 * c.b ** 2);
        if (lum === 0)
            return Qt.alpha(c, layerAlpha);
        const offset = (!light || n === 1 ? 1 : -n / 2) * (light ? 0.2 : 0.3) * (1 - baseAlpha);
        const k = (lum + offset) / lum, f = v => Math.max(0, Math.min(1, v * k));
        return Qt.rgba(f(c.r), f(c.g), f(c.b), layerAlpha);
    }
    readonly property color window: layer(surface, 0)
    readonly property color frame: layer(containerLow, 1)
    readonly property color tile: layer(container, light ? 2 : 1)
    readonly property color navItem: layer(containerHigh, 2)
    readonly property color field: layer(containerHighest, 2)

    function col(name: string, fallback: string): color {
        return c[name] ? `#${c[name]}` : fallback;
    }

    readonly property color surface: col("surface", "#101414")
    readonly property color container: col("surfaceContainer", "#1a2120")
    readonly property color containerLow: col("surfaceContainerLow", "#151b1a")
    readonly property color containerHigh: col("surfaceContainerHigh", "#222a29")
    readonly property color containerHighest: col("surfaceContainerHighest", "#2c3534")
    readonly property color fg: col("onSurface", "#dce8e6")
    readonly property color fgVariant: col("onSurfaceVariant", "#a2adac")
    readonly property color outline: col("outline", "#6d7876")
    readonly property color outlineVariant: col("outlineVariant", "#3f4a49")
    readonly property color primary: col("primary", "#9bd0cc")
    readonly property color fgPrimary: col("onPrimary", "#0c3835")
    readonly property color secondaryContainer: col("secondaryContainer", "#304846")
    readonly property color fgSecondary: col("onSecondaryContainer", "#cfe8e5")
    readonly property color tertiaryContainer: col("tertiaryContainer", "#2f4a63")
    readonly property color fgTertiary: col("onTertiaryContainer", "#cfe4ff")
    readonly property color error: col("error", "#ffb4ab")
    readonly property color errorContainer: col("errorContainer", "#93000a")
    readonly property color fgError: col("onErrorContainer", "#ffdad6")
    readonly property color success: col("success", "#9bd09b")

    readonly property string font: gsf.status === FontLoader.Ready ? gsf.name : "Rubik"
    readonly property string mono: "CaskaydiaCove NF"
    readonly property string iconFont: "Material Symbols Rounded"

    readonly property real rScale: prefs.rounding
    readonly property int rXs: Math.round(5 * rScale)
    readonly property int rSm: Math.round(12 * rScale)
    readonly property int rMd: Math.round(18 * rScale)
    readonly property int rLg: Math.round(26 * rScale)
    readonly property int gap: 3

    FontLoader {
        id: gsf
        // Caelestia from the AUR, then a copy installed from git in ~/.config/quickshell
        readonly property string file: "assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
        source: `file:///etc/xdg/quickshell/caelestia/${file}`
        onStatusChanged: if (status === FontLoader.Error && !String(source).startsWith(`file://${root.confDir}`))
            source = `file://${root.confDir}/quickshell/caelestia/${file}`
    }

    FileView {
        path: `${root.stateDir}/caelestia/scheme.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.c = s.colours ?? {};
                root.light = s.mode === "light";
            } catch (e) {}
        }
    }

    FileView {
        path: `${root.confDir}/caelestia/shell.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const a = JSON.parse(text()).appearance ?? {};
                const t = a.transparency ?? {};
                root.shellSpeed = a.anim?.durations?.scale ?? 1;
                root.shellTransparent = t.enabled ?? false;
                root.shellBase = t.base ?? 0.85;
                root.shellLayers = t.layers ?? 0.4;
            } catch (e) {}
        }
    }

    FileView {
        path: `${root.confDir}/orrery/ui.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.prefs = Object.assign({}, root.prefs, JSON.parse(text()));
            } catch (e) {}
        }
    }
}
