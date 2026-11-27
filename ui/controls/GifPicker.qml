import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.core

// Chooses a picture for one of Caelestia's places: your files, or GIPHY stickers with your own key.
Item {
    id: root
    property string title
    property var done
    property bool open: false
    property string tab: "files" // files | giphy
    property bool loading: false
    property string error: ""
    property var files: []        // every picture found, read once per opening
    property string filesQuery: ""
    property string giphyQuery: ""
    // Both grids use a ListModel: adding rows (more GIPHY results) does not rebuild the ones already shown
    function fillFiles(): void {
        const q = filesQuery.toLowerCase(), list = q ? files.filter(f => f.title.toLowerCase().includes(q)) : files;
        if (list.length === shownFiles.count && list.every((f, i) => shownFiles.get(i).pid === f.pid)) {
            list.forEach((f, i) => { if (shownFiles.get(i).preview !== f.preview) shownFiles.setProperty(i, "preview", f.preview); });
            return;
        }
        shownFiles.clear();
        for (const f of list)
            shownFiles.append(f);
    }
    onFilesQueryChanged: fillFiles()
    onFilesChanged: fillFiles()
    ListModel { id: shownFiles }
    property int next: 0
    property int total: 0
    property string lastQuery: ""
    property Item before: null
    readonly property bool hasKey: !!Backend.st?.pics?.giphy
    readonly property Item grid: tab === "files" ? filesGrid : giphyGrid

    function show(t: string, cb: var): void {
        title = t; done = cb; error = "";
        before = Nav.current;
        open = true;
        closing.stop();
        opening.restart();
        loadFiles();
        query.text = tab === "files" ? filesQuery : giphyQuery;
        if (tab === "giphy" && !hasKey) keyField.focusInput();
        else query.forceActiveFocus();
    }
    function close(): void {
        open = false;
        opening.stop();
        closing.restart();
        if (before) before.forceActiveFocus(Qt.OtherFocusReason);
    }
    // Each tab keeps its own grid and search: switching back reloads nothing
    function setTab(t: string): void {
        if (t === tab) return;
        tab = t; error = "";
        query.text = t === "files" ? filesQuery : giphyQuery;
        if (t === "giphy" && hasKey && !results.count) search(giphyQuery, false);
        if (t === "files" || hasKey) query.forceActiveFocus();
        else keyField.focusInput();
    }
    // Still pictures are shown from small thumbnails: a 4K wallpaper decoded by Qt costs tens of MB
    function loadFiles(): void {
        Backend.call("pic-files", {}, r => {
            const list = (r.files ?? []).map(f => ({ pid: f.path, path: f.path, title: f.name, moving: /\.(gif|webp)$/i.test(f.path), transparent: -1,
                preview: f.still ? (f.thumb ? `file://${f.thumb}` : "") : `file://${f.path}` }));
            if (JSON.stringify(list) !== JSON.stringify(files))
                files = list;
            const missing = (r.files ?? []).filter(f => f.still && !f.thumb).map(f => f.path);
            if (missing.length)
                Backend.call("pic-thumbs", { paths: missing }, t => {
                    const made = t.thumbs ?? {};
                    files = files.map(f => made[f.path] ? Object.assign({}, f, { preview: `file://${made[f.path]}` }) : f);
                });
        });
    }
    function search(q: string, more: bool): void {
        if (loading) return;
        loading = true; error = "";
        if (!more) { results.clear(); next = 0; }
        lastQuery = q;
        Backend.call("giphy-search", { query: q, offset: more ? next : 0 }, r => {
            loading = false;
            if (!r.ok) return error = r.error ?? "";
            for (const x of r.results)
                results.append({ pid: x.id, path: "", title: x.title, preview: x.preview, moving: true, transparent: x.transparent === false ? 0 : x.transparent ? 1 : -1 });
            next = r.next; total = r.total;
        });
    }
    // transparent: 1 yes, 0 no (cannot be used), -1 unknown
    function pick(item: var): void {
        if (loading || item.transparent === 0) return;
        loading = true; error = "";
        const cmd = tab === "files" ? ["pic-import", { path: item.path }] : ["giphy-save", { id: item.id }];
        Backend.call(cmd[0], cmd[1], r => {
            loading = false;
            if (!r.ok) return error = r.error ?? "";
            if (r.info && r.info.transparent === false)
                Backend.say(I18n.tr("This picture has a background: Caelestia will show it as it is."), true);
            close();
            done(r.path);
        });
    }
    ListModel { id: results }

    readonly property bool navSkip: true
    anchors.fill: parent
    visible: open || pop > 0 || scrim.opacity > 0

    // Opens like Caelestia's lock: a small rounded square spins in, its icon turns away
    // while it grows to full size, then the content fades in. Closing runs it backwards, faster.
    property real pop: 0     // the square: scale and half a turn
    property real grow: 0    // from the square to the full box
    property real reveal: 0  // the content
    readonly property real fullW: Math.min(860, width - 60)
    readonly property real fullH: height - 80
    readonly property real seed: 96
    SequentialAnimation {
        id: opening
        Anim { target: root; property: "pop"; to: 1; kind: "fast" }
        ParallelAnimation {
            Anim { target: root; property: "grow"; to: 1; kind: "default" }
            SequentialAnimation {
                PauseAnimation { duration: 120 * Theme.animScale }
                Anim { target: root; property: "reveal"; to: 1; kind: "fxSlow" }
            }
        }
    }
    SequentialAnimation {
        id: closing
        ParallelAnimation {
            Anim { target: root; property: "reveal"; to: 0; kind: "fx" }
            Anim { target: root; property: "grow"; to: 0; kind: "accel"; duration: 260 * Theme.animScale }
        }
        Anim { target: root; property: "pop"; to: 0; kind: "accel" }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.alpha("black", 0.5)
        opacity: root.open ? 1 : 0
        Behavior on opacity { Anim { kind: "fxSlow" } }
    }
    MouseArea { anchors.fill: parent; enabled: root.open; hoverEnabled: true; onClicked: root.close(); onWheel: {} }

    Rectangle {
        id: box
        anchors.centerIn: parent
        width: root.seed + (root.fullW - root.seed) * root.grow
        height: root.seed + (root.fullH - root.seed) * root.grow
        radius: root.seed / 4 + (Theme.rLg - root.seed / 4) * Math.min(1, root.grow)
        color: Theme.container
        opacity: Math.min(1, root.pop * 2)
        scale: root.pop
        rotation: 180 + 180 * root.pop
        clip: root.grow < 1
        MouseArea { anchors.fill: parent }

        Ico {
            anchors.centerIn: parent
            text: "gif_box"
            size: 44
            fill: 1
            color: Theme.primary
            rotation: 180 + 180 * root.grow
            opacity: Math.max(0, 1 - root.grow * 1.6)
            visible: opacity > 0
        }

        // Laid out at full size from the start: growing the box never reflows the grid
        ColumnLayout {
            anchors.centerIn: parent
            width: root.fullW - 36
            height: root.fullH - 36
            spacing: 12
            opacity: root.reveal // not hidden: the search field takes the focus while the box opens
            scale: 0.94 + 0.06 * root.reveal

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; Layout.leftMargin: 6; text: root.title; size: 18; weight: Font.Medium; elide: Text.ElideRight }
                Btn { icon: "folder"; text: I18n.tr("Your files"); kind: root.tab === "files" ? "filled" : "tonal"; onClicked: root.setTab("files") }
                Btn { icon: "gif_box"; text: "GIPHY"; kind: root.tab === "giphy" ? "filled" : "tonal"; onClicked: root.setTab("giphy") }
                Btn { icon: "close"; kind: "text"; onClicked: root.close() }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: root.tab === "files" || root.hasKey
                implicitHeight: 42
                radius: 21
                color: Theme.containerHighest
                Ico { id: lens; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "search"; size: 20; color: query.activeFocus ? Theme.primary : Theme.fgVariant }
                TextInput {
                    id: query
                    anchors { left: lens.right; right: parent.right; leftMargin: 8; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.fgPrimary
                    font.family: Theme.font
                    font.pixelSize: 14
                    maximumLength: 50
                    onTextChanged: if (root.tab === "files") root.filesQuery = text; else root.giphyQuery = text
                    onAccepted: if (root.tab === "giphy") root.search(text, false); else root.grid.forceActiveFocus()
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: root.grid.forceActiveFocus()
                    Txt {
                        visible: !query.text
                        text: root.tab === "files" ? I18n.tr("Search by name in Pictures and Downloads") : I18n.tr("Search stickers, then press Enter")
                        color: Theme.outline
                    }
                }
            }

            // First time: how to get a key
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "giphy" && !root.hasKey
                contentHeight: guide.implicitHeight
                clip: true
                ColumnLayout {
                    id: guide
                    width: parent.width
                    spacing: Theme.gap
                    Txt {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Layout.bottomMargin: 6
                        wrapMode: Text.WordWrap
                        color: Theme.fgVariant
                        text: I18n.tr("To search GIPHY, Orrery uses a key of your own: it is free and takes a couple of minutes. Nothing is sent to GIPHY until you search.")
                    }
                    Repeater {
                        model: [
                            ["looks_one", "Open the GIPHY developer dashboard", "Sign in, or create a free account: it is the same as for giphy.com."],
                            ["looks_two", "Create an API key", "Press “Create an API Key”. If it asks what you are making, choose API (not SDK); any name works, for example “Orrery”."],
                            ["looks_3", "Copy the key", "The dashboard shows it under your app, as a long string of letters and numbers."],
                            ["looks_4", "Paste it below", "Orrery checks it with GIPHY and keeps it only on this computer, readable by you alone."]]
                        Tile {
                            id: step
                            required property var modelData
                            required property int index
                            first: index === 0
                            icon: modelData[0]
                            label: I18n.tr(modelData[1])
                            sub: I18n.tr(modelData[2])
                            Btn {
                                visible: step.index === 0
                                icon: "open_in_new"
                                text: I18n.tr("Open")
                                onClicked: Ui.openUrl("https://developers.giphy.com/dashboard/?create=true")
                            }
                        }
                    }
                    Tile {
                        last: true
                        icon: "key"
                        label: I18n.tr("Your GIPHY key")
                        Field {
                            id: keyField
                            mono: true
                            implicitWidth: 300
                            placeholder: "API Key"
                            onCommit: v => value = v
                        }
                        Btn {
                            text: I18n.tr("Check and save")
                            kind: "filled"
                            enabled: !root.loading
                            onClicked: {
                                const k = keyField.text.trim();
                                root.loading = true; root.error = "";
                                Backend.call("giphy-key", { key: k }, r => {
                                    root.loading = false;
                                    if (!r.ok) return root.error = r.error ?? "";
                                    Backend.say(I18n.tr("GIPHY key saved"), false);
                                    Backend.refresh(true);
                                    keyField.value = "";
                                    searchSoon.restart();
                                });
                            }
                        }
                    }
                    Note {
                        text: I18n.tr("A free key allows about 100 searches an hour. The stickers you choose are saved for you alone: please do not share them as your own. GIPHY's terms apply.")
                    }
                }
            }
            Timer { id: searchSoon; interval: 400; onTriggered: if (root.hasKey) { root.search("", false); query.forceActiveFocus(); } }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.tab === "files" || root.hasKey
                PicGrid {
                    id: filesGrid
                    anchors.fill: parent
                    visible: root.tab === "files"
                    model: shownFiles
                    playing: root.open && visible && Ui.awake
                    onChosen: item => root.pick(item)
                    onLeaveTop: query.forceActiveFocus()
                    onClose: root.close()
                }
                PicGrid {
                    id: giphyGrid
                    anchors.fill: parent
                    visible: root.tab === "giphy"
                    model: results
                    animateAll: true
                    playing: root.open && visible && Ui.awake
                    onChosen: item => root.pick(item)
                    onLeaveTop: query.forceActiveFocus()
                    onClose: root.close()
                    onAtYEndChanged: if (atYEnd && results.count && root.next < root.total && !root.loading) root.search(root.lastQuery, true)
                }
                OrreryLoader {
                    anchors.centerIn: parent
                    size: 120
                    visible: root.tab === "giphy" && root.loading && !results.count
                }
                OrreryLoader {
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                    size: 44
                    visible: root.tab === "giphy" && root.loading && results.count > 0
                }
                OrreryLoader {
                    anchors.centerIn: parent
                    size: 120
                    visible: root.tab === "files" && root.loading
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Txt {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    wrapMode: Text.WordWrap
                    size: 12
                    color: root.error ? Theme.error : Theme.fgVariant
                    text: root.error ? I18n.tr(root.error)
                        : root.tab === "files" ? (shownFiles.count ? I18n.tr("Copied into Orrery's folder when you choose one, so moving the original breaks nothing.") : I18n.tr("No pictures found in Pictures and Downloads."))
                        : root.hasKey ? I18n.tr("Stickers marked with a background cannot be used.") : ""
                }
                Btn {
                    visible: root.tab === "giphy" && root.hasKey
                    icon: "key_off"
                    kind: "text"
                    text: I18n.tr("Remove key")
                    onClicked: Backend.call("giphy-key", { key: "" }, r => { results.clear(); Backend.refresh(true); })
                }
                Txt { visible: root.tab === "giphy"; text: "Powered by GIPHY"; weight: Font.Bold; size: 12; color: Theme.fg }
            }
        }
    }
}
