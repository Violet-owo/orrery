pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ORRERY_PAGE / ORRERY_AREA open the app on a given page
    readonly property var nav: [
        { icon: "palette", name: "Appearance", sub: "Transparency, motion, language", group: 0 },
        { icon: "wallpaper", name: "Wallpapers", sub: "Folder, light and dark", group: 0 },
        { icon: "apps", name: "Default apps", sub: "Links, files, shortcuts", group: 1 },
        { icon: "keyboard", name: "Keyboard", sub: "Layouts, Num Lock", group: 1 },
        { icon: "dashboard", name: "Areas", sub: "Super+S, D, M and yours", group: 1 },
        { icon: "power_settings_new", name: "Startup", sub: "Keyboard light", group: 2 },
        { icon: "login", name: "Login", sub: "Lock screen at boot", group: 2 },
        { icon: "health_and_safety", name: "Health", sub: "Checks, undo, credits", group: 3 }]

    // What the search knows: [page, English label]
    readonly property var index: [
        [0, "Follow Caelestia"], [0, "Transparency"], [0, "Background opacity"], [0, "Layer opacity"], [0, "Animation duration"], [0, "Rounding"], [0, "Language"],
        [1, "Set up the wallpapers"], [1, "Folder to use"], [2, "Web browser"], [2, "Terminal"], [2, "Text editor"], [2, "File manager"], [2, "Images"], [2, "Video"], [2, "Music"], [2, "PDF"], [2, "Mail"],
        [3, "Manage the keyboard with Orrery"], [3, "Add a layout"], [3, "Switch layout"], [3, "Num Lock at startup"], [3, "Repeat rate"], [3, "Repeat delay"],
        [4, "Customise this area"], [4, "Shortcut"], [4, "Add an app"], [4, "Move between workspaces with the arrows"], [4, "Wrap around"], [4, "Bring apps back"], [4, "Opening"], [4, "Changing workspace"],
        [5, "Turn on at startup"], [5, "Level"], [6, "Required packages"], [6, "Scale"], [6, "Numeric keypad always types digits"],
        [7, "Developed by"], [7, "Source code"], [7, "Undo the last apply"], [7, "Turn Orrery off"]]
    property string target: "" // label to highlight after a search

    property int page: parseInt(Quickshell.env("ORRERY_PAGE") || "0")
    readonly property int startScroll: parseInt(Quickshell.env("ORRERY_SCROLL") || "0")
    property int area: parseInt(Quickshell.env("ORRERY_AREA") || "0")
    readonly property string version: "0.1.2beta1"
    readonly property string author: "Violet Miller"
    readonly property string portfolio: "https://portfolio.violetvrc30.workers.dev/"
    readonly property string source: "https://github.com/Violet-owo/orrery"
    function openUrl(url: string): void { Quickshell.execDetached(["xdg-open", url]); }

    property var picker: null
    property bool down: true // direction of the last page change
    function go(i: int): void {
        down = i >= page; // first, so the menu pill knows which edge leads
        page = i;
    }

    // Page entrance: rows created while `entering` cascade in
    property bool entering: false
    function beginEntrance(): void {
        entering = true;
        enterEnd.restart();
    }

    // Row just created by the user: it grows in, the others stay put
    property string added: ""
    function markAdded(key: string): void {
        added = key;
        addedEnd.restart();
    }

    // items: [{ value, label, sub, icon }]
    function pick(title: string, items: var, current: var, done: var): void {
        picker?.show(title, items, current, done);
    }

    Timer { id: enterEnd; interval: 250; onTriggered: root.entering = false }
    Timer { id: addedEnd; interval: 400; onTriggered: root.added = "" }
}
