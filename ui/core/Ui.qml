pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ORRERY_PAGE / ORRERY_AREA open the app on a given page
    readonly property var nav: [
        { icon: "palette", name: "Appearance", sub: "Orrery's look, colours in your apps", group: 0 },
        { icon: "wallpaper", name: "Wallpapers", sub: "Light and dark, desktop clock, GIFs", group: 0 },
        { icon: "toolbar", name: "Bar", sub: "Blocks, screens, indicators, panels", group: 0 },
        { icon: "apps", name: "Default apps", sub: "Links, files, shortcuts, Spotify", group: 1 },
        { icon: "keyboard", name: "Keyboard", sub: "Layouts, Num Lock", group: 1 },
        { icon: "dashboard", name: "Areas", sub: "Super+S, D, M and yours", group: 1 },
        { icon: "power_settings_new", name: "Startup", sub: "Keyboard light", group: 2 },
        { icon: "login", name: "Login", sub: "Lock screen at boot", group: 2 },
        { icon: "bedtime", name: "Power", sub: "Lock, screen off, suspend", group: 2 },
        { icon: "health_and_safety", name: "Health", sub: "Checks, updates, credits", group: 3 }]

    // What the search knows: [page, English label]
    readonly property var index: [
        [0, "Follow Caelestia"], [0, "Transparency"], [0, "Background opacity"], [0, "Layer opacity"], [0, "Animation duration"], [0, "Rounding"], [0, "Language"], [0, "Caelestia's colours in your apps"], [0, "Discord"], [0, "GTK apps"], [0, "Qt apps"], [0, "Terminals"], [0, "Icons with the dark theme"], [0, "Icons with the light theme"],
        [1, "Set up the wallpapers"], [1, "Folder to use"], [1, "On the desktop"], [1, "Clock on the desktop"], [1, "Audio bars on the desktop"], [1, "GIFs and pictures"], [1, "Media speed"], [1, "Shut down menu speed"], [1, "GIPHY"], [1, "Caelestia's originals"],
        [2, "Blocks, from the top"], [2, "Add a space"], [2, "Screens"], [2, "Show the indicators"], [2, "Brightness"], [2, "Microphone"], [2, "Stays on screen for"], [2, "Weather city"], [2, "Clicking a notification runs its action"], [2, "Third button of the shut down menu"],
        [3, "Web browser"], [3, "Terminal"], [3, "Text editor"], [3, "File manager"], [3, "Images"], [3, "Video"], [3, "Music"], [3, "PDF"], [3, "Mail"], [3, "Spotify follows Caelestia's colours"], [3, "Colours change live"], [3, "Spotify extensions"],
        [4, "Manage the keyboard with Orrery"], [4, "Desktop shortcuts"], [4, "Add a layout"], [4, "Switch layout"], [4, "Num Lock at startup"], [4, "Repeat rate"], [4, "Repeat delay"],
        [5, "Customise this area"], [5, "Shortcut"], [5, "Add an app"], [5, "Move between workspaces with the arrows"], [5, "Wrap around"], [5, "Bring apps back"], [5, "Opening"], [5, "Changing workspace"],
        [6, "Turn on at startup"], [6, "Level"], [7, "Required packages"], [7, "Switch to greetd"], [7, "Scale"], [7, "Numeric keypad always types digits"],
        [8, "Lock"], [8, "Turn the screen off"], [8, "Suspend"], [8, "Suspend on battery"], [8, "Suspend while charging"], [8, "Lock before suspending"], [8, "Stay awake while something plays"], [8, "Stay awake while charging"], [8, "Hibernate after a while asleep"], [8, "Caelestia's defaults"], [8, "Low battery"], [8, "Add a warning"], [8, "Hibernate when the battery is almost empty"],
        [9, "Developed by"], [9, "Source code"], [9, "Undo the last apply"], [9, "Turn Orrery off"], [9, "Updates"], [9, "Channel"], [9, "Check for updates at start"]]
    property string target: "" // label to highlight after a search

    property int page: parseInt(Quickshell.env("ORRERY_PAGE") || "0")
    readonly property int startScroll: parseInt(Quickshell.env("ORRERY_SCROLL") || "0")
    property int area: parseInt(Quickshell.env("ORRERY_AREA") || "0")
    readonly property string version: "0.2.1beta2"
    readonly property string author: "Violet Miller"
    readonly property string portfolio: "https://portfolio.violetvrc30.workers.dev/"
    readonly property string source: "https://github.com/Violet-owo/orrery"
    function openUrl(url: string): void { Quickshell.execDetached(["xdg-open", url]); }

    // false while Orrery's window is not the active one: looping animations pause, nothing is drawn for nobody
    property bool awake: true
    property var picker: null
    property var gifPicker: null
    property var shortcuts: null
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
