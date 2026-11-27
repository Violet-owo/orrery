//@ pragma Env QS_NO_RELOAD_POPUP=1
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.controls
import qs.pages

ShellRoot {
    // An update replaces the files while Orrery runs: it restarts by itself instead of reloading halfway
    settings.watchFiles: false

    FloatingWindow {
        id: win
        title: "Orrery"
        implicitWidth: 1180
        implicitHeight: 800
        minimumSize: Qt.size(820, 560)
        color: Theme.window
        surfaceFormat.opaque: false
        Behavior on color { CAnim {} }
        onVisibleChanged: if (!visible) Qt.quit()

        Item {
            id: bg
            anchors.fill: parent
            focus: true

            function quit(): void {
                if (!Backend.dirty)
                    return Qt.quit();
                Ui.pick(I18n.tr("There are unsaved changes"), [
                    { value: "stay", label: I18n.tr("Keep editing") },
                    { value: "apply", label: I18n.tr("Apply and close") },
                    { value: "drop", label: I18n.tr("Close without applying") }], "stay", v => {
                    if (v === "drop")
                        Qt.quit();
                    if (v === "apply") {
                        Backend.quitAfterApply = true;
                        Backend.apply();
                    }
                });
            }

            function pressed(e: KeyEvent): bool {
                const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier, alt = e.modifiers & Qt.AltModifier;
                if (e.key === Qt.Key_F1) { help.open = !help.open; return true; }
                if (help.open) { if (e.key === Qt.Key_Escape) help.open = false; return true; }
                if (picker.open || gifPicker.open || shortcutsSheet.open) return false;
                if (ctrl && e.key === Qt.Key_K) { shortcutsSheet.show(); return true; }
                if (ctrl && e.key >= Qt.Key_0 && e.key <= Qt.Key_9) { Ui.go(e.key === Qt.Key_0 ? 9 : e.key - Qt.Key_1); return Nav.toMenu(); }
                if (ctrl && (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab || e.key === Qt.Key_PageDown || e.key === Qt.Key_PageUp)) {
                    const back = e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp || (e.key === Qt.Key_Tab && shift);
                    Ui.go((Ui.page + (back ? bg.nav.length - 1 : 1)) % bg.nav.length);
                    return Nav.toMenu();
                }
                if ((ctrl && e.key === Qt.Key_F) || (!ctrl && e.text === "/")) return Nav.focus(search.input);
                if (ctrl && e.key === Qt.Key_S) { commit(); if (Backend.dirty) Backend.apply(); return true; }
                if (ctrl && e.key === Qt.Key_Z) { if (shift) Backend.stepForward(); else Backend.stepBack(); return true; }
                if (ctrl && e.key === Qt.Key_Y) { Backend.stepForward(); return true; }
                if (ctrl && (e.key === Qt.Key_Q || e.key === Qt.Key_W)) { commit(); quit(); return true; }
                if (ctrl) return false;
                if (alt && Ui.page === 5 && Backend.ready && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
                    const n = Backend.cfg.areas.length;
                    if (n) Ui.area = (Math.min(Ui.area, n - 1) + (e.key === Qt.Key_Right ? 1 : n - 1)) % n;
                    return true;
                }
                if (e.key === Qt.Key_PageDown || e.key === Qt.Key_PageUp) {
                    const p = stack.currentItem;
                    p?.glideTo(p.contentY + p.height * (e.key === Qt.Key_PageDown ? 0.8 : -0.8));
                    return true;
                }
                if (e.key === Qt.Key_Escape) { Nav.toMenu(); return true; }
                const dir = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right" }[e.key];
                return dir ? Nav.move(dir) : false;
            }
            // Leaving a text field commits what was typed
            function commit(): void { bg.forceActiveFocus(); }

            Keys.onPressed: e => { Nav.keys = true; e.accepted = pressed(e); }

            readonly property Item focused: Window.activeFocusItem
            Binding { target: Ui; property: "awake"; value: bg.Window.active }
            onFocusedChanged: {
                Nav.current = focused;
                if (Nav.keys && focused?.navigable === true && Nav.inside(focused, stack))
                    stack.currentItem?.reveal(focused);
            }
            HoverHandler { onPointChanged: if (!quiet.running) Nav.keys = false }
            Timer { id: quiet; interval: 400; running: true }
            Connections { target: Ui; function onPageChanged(): void { quiet.restart(); } }
            readonly property var nav: Ui.nav
            readonly property int navWidth: Math.round(Math.min(380, width / 3))

            Loader {
                anchors.fill: parent
                source: "controls/Frame.qml"
                onStatusChanged: if (status === Loader.Error) source = "controls/FrameSimple.qml"
                onLoaded: {
                    item.leftBorder = Qt.binding(() => bg.navWidth + 36);
                    item.notchWidth = Qt.binding(() => windowButtons.width + 20);
                    item.notchHeight = Qt.binding(() => windowButtons.height + 16);
                }
            }

            // --- navigation ---------------------------------------------------------
            SearchBox {
                id: search
                readonly property bool navSkip: true
                readonly property string query: text.trim().toLowerCase()
                readonly property var hits: query ? Ui.index.filter(h => `${I18n.tr(h[1])} ${h[1]} ${I18n.tr(Ui.nav[h[0]].name)}`.toLowerCase().includes(query)).slice(0, 9) : []
                anchors { left: parent.left; top: parent.top; margins: 18 }
                width: bg.navWidth
                input.Component.onCompleted: Nav.searchField = input
                function open(hit: var): void {
                    Ui.target = hit[1];
                    const same = Ui.page === hit[0];
                    Ui.go(hit[0]);
                    text = "";
                    bg.forceActiveFocus();
                    if (same)
                        seek.restart();
                }
                onDown: hits.length ? Nav.focus(Nav.collect(results, [])[0]) : Nav.toMenu()
                onAccepted: if (hits.length) open(hits[0])
            }

            FadeFlick {
                id: navFlick
                Component.onCompleted: Nav.menuPane = navFlick
                anchors { left: parent.left; top: search.bottom; bottom: parent.bottom; leftMargin: 18; topMargin: 14; bottomMargin: 10 }
                width: bg.navWidth
                contentHeight: side.height + 14
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: side
                    readonly property int rowH: 70
                    readonly property int step: rowH + Theme.gap
                    readonly property bool idle: search.query === ""
                    readonly property real pillR: Math.min(rowH / 2, 35 * Theme.rScale)
                    function rowY(i: int): real { return i * step + Ui.nav[i].group * 12; }
                    width: navFlick.width
                    height: rowY(Ui.nav.length - 1) + rowH
                    opacity: idle ? 1 : 0
                    visible: opacity > 0
                    scale: idle ? 1 : 0.96
                    Behavior on opacity { Anim { kind: "fx" } }
                    Behavior on scale { Anim { kind: "fast" } }
                    Component.onCompleted: Nav.menu = side

                    Repeater {
                        model: bg.nav
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool near: h.pressed
                            readonly property bool on: Ui.page === index
                            readonly property bool first: index === 0 || Ui.nav[index - 1].group !== modelData.group
                            readonly property bool last: index === Ui.nav.length - 1 || Ui.nav[index + 1].group !== modelData.group
                            y: side.rowY(index)
                            width: side.width
                            height: side.rowH
                            // Takes the pill's shape and steps aside, so nothing shows behind its corners
                            color: on ? Qt.alpha(Theme.navItem, 0) : Theme.navItem
                            topLeftRadius: on ? side.pillR : near ? Theme.rMd : first ? Theme.rLg : Theme.rXs
                            topRightRadius: topLeftRadius
                            bottomLeftRadius: on ? side.pillR : near ? Theme.rMd : last ? Theme.rLg : Theme.rXs
                            bottomRightRadius: bottomLeftRadius
                            Behavior on topLeftRadius { Anim { kind: "fast" } }
                            Behavior on bottomLeftRadius { Anim { kind: "fast" } }
                            Behavior on color { ColorAnimation { duration: 140 * Theme.animScale } }
                            Hover { id: h; onClicked: Ui.go(parent.index) }
                        }
                    }

                    // Elastic pill: the leading edge moves first, the trailing one catches up
                    Rectangle {
                        id: pill
                        property real topEdge: side.rowY(Ui.page)
                        property real bottomEdge: side.rowY(Ui.page) + side.rowH
                        Behavior on topEdge { Anim { kind: Ui.down ? "default" : "fast"; duration: (Ui.down ? 480 : 300) * Theme.animScale } }
                        Behavior on bottomEdge { Anim { kind: Ui.down ? "fast" : "default"; duration: (Ui.down ? 300 : 480) * Theme.animScale } }
                        y: topEdge
                        width: side.width
                        height: Math.max(30, bottomEdge - topEdge)
                        radius: side.pillR
                        color: Theme.secondaryContainer
                        Behavior on color { CAnim {} }
                    }

                    Repeater {
                        model: bg.nav
                        RowLayout {
                            id: navRow
                            required property var modelData
                            required property int index
                            readonly property bool on: Ui.page === index
                            x: 16
                            y: side.rowY(index)
                            width: side.width - 32
                            height: side.rowH
                            spacing: 14
                            Rectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: 22
                                color: navRow.on ? Theme.primary : Theme.secondaryContainer
                                scale: navRow.on ? 1.06 : 1
                                Behavior on scale { Anim { kind: "slow" } }
                                Behavior on color { CAnim {} }
                                Ico { anchors.centerIn: parent; text: navRow.modelData.icon; fill: 1; size: 22; color: navRow.on ? Theme.fgPrimary : Theme.fgSecondary }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Txt { Layout.fillWidth: true; size: 16; text: I18n.tr(navRow.modelData.name); color: Theme.fg }
                                Txt { Layout.fillWidth: true; text: I18n.tr(navRow.modelData.sub); size: 12; color: Theme.fgVariant }
                            }
                        }
                    }
                }

                // Search results take the menu's place
                Column {
                    id: results
                    width: navFlick.width
                    spacing: Theme.gap
                    visible: !side.idle
                    Repeater {
                        id: resultRep
                        model: search.hits
                        Rectangle {
                            id: hit
                            required property var modelData
                            required property int index
                            property real p: 0
                            width: results.width
                            height: 62
                            opacity: p
                            transform: Translate { y: (1 - hit.p) * 18 }
                            color: Theme.navItem
                            topLeftRadius: index === 0 ? Theme.rLg : Theme.rXs
                            topRightRadius: topLeftRadius
                            bottomLeftRadius: index === resultRep.count - 1 ? Theme.rLg : Theme.rXs
                            bottomRightRadius: bottomLeftRadius
                            Component.onCompleted: p = 1
                            Behavior on p { Anim { kind: "default" } }
                            Ico { id: hitIcon; x: 20; anchors.verticalCenter: parent.verticalCenter; text: Ui.nav[hit.modelData[0]].icon; color: Theme.primary; fill: 1 }
                            Column {
                                anchors { left: hitIcon.right; leftMargin: 16; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                Txt { width: parent.width; text: I18n.tr(hit.modelData[1]); size: 15 }
                                Txt { width: parent.width; text: I18n.tr(Ui.nav[hit.modelData[0]].name); size: 12; color: Theme.fgVariant }
                            }
                            Hover {
                                onClicked: search.open(hit.modelData)
                                Keys.onDownPressed: Nav.focus(Nav.collect(results, [])[hit.index + 1] ?? this)
                                Keys.onUpPressed: Nav.focus(hit.index ? Nav.collect(results, [])[hit.index - 1] : search.input)
                            }
                        }
                    }
                    Txt { visible: search.hits.length === 0; text: I18n.tr("Nothing found"); color: Theme.fgVariant; leftPadding: 20; topPadding: 12 }
                }
            }

            // Lands on the searched option
            Timer {
                id: seek
                interval: 420 * Theme.animScale + 60
                onTriggered: {
                    const page = stack.currentItem, tile = Ui.target && page ? page.findTile(I18n.tr(Ui.target), null) : null;
                    Ui.target = "";
                    if (!tile)
                        return;
                    page.reveal(tile);
                    tile.pulse();
                    Nav.focus(Nav.collect(tile, [])[0] ?? null);
                }
            }

            // --- content --------------------------------------------------------------
            Item {
                id: content
                anchors { fill: parent; leftMargin: bg.navWidth + 40; topMargin: 10; rightMargin: 12; bottomMargin: 10 }
                clip: true

                readonly property var pages: [appearance, wallpapers, barPage, apps, keyboard, areas, startup, login, power, health]
                property int shown: -1
                property int dir: 1

                function go(): void {
                    if (!Backend.ready || shown === Ui.page)
                        return;
                    dir = Ui.page >= shown ? 1 : -1;
                    const firstPage = shown < 0;
                    shown = Ui.page;
                    Ui.beginEntrance();
                    if (Ui.target !== "")
                        seek.restart();
                    if (firstPage)
                        stack.push(pages[shown], { contentY: Ui.startScroll }, StackView.Immediate);
                    else
                        stack.replace(null, pages[shown]);
                }

                Connections {
                    target: Ui
                    function onPageChanged(): void { content.go(); }
                }
                Connections {
                    target: Backend
                    function onReadyChanged(): void { content.go(); }
                }
                Component.onCompleted: {
                    Nav.body = bg;
                    go();
                    Nav.toMenu();
                    Nav.keys = false;
                }

                StackView {
                    id: stack
                    anchors { fill: parent; topMargin: 16; leftMargin: 12; rightMargin: 4; bottomMargin: Backend.dirty || Backend.busy ? 72 : 0 }
                    Behavior on anchors.bottomMargin { Anim { kind: "decel" } }
                    replaceEnter: Transition {
                        // Fade through: the old page is gone before the new one shows
                        SequentialAnimation {
                            PropertyAction { property: "opacity"; value: 0 }
                            PauseAnimation { duration: 90 * Theme.animScale }
                            ParallelAnimation {
                                Anim { property: "opacity"; from: 0; to: 1; kind: "fxSlow" }
                                Anim { property: "y"; from: 56 * content.dir; to: 0; kind: "default" }
                            }
                        }
                    }
                    replaceExit: Transition {
                        Anim { property: "opacity"; from: 1; to: 0; kind: "fx"; duration: 110 * Theme.animScale }
                        Anim { property: "y"; from: 0; to: -40 * content.dir; kind: "fx"; duration: 130 * Theme.animScale }
                    }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    opacity: Backend.ready ? 0 : 1
                    Behavior on opacity { Anim { kind: "fxSlow" } }
                    Ico {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "orbit"
                        size: 54
                        color: Theme.primary
                        RotationAnimation on rotation { running: !Backend.ready; loops: Animation.Infinite; from: 0; to: 360; duration: 1800 }
                    }
                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Backend.message || I18n.tr("Loading") + "…"; color: Theme.fgVariant }
                }
                Component { id: appearance; AppearancePage {} }
                Component { id: wallpapers; WallpapersPage {} }
                Component { id: barPage; BarPage {} }
                Component { id: apps; AppsPage {} }
                Component { id: keyboard; KeyboardPage {} }
                Component { id: areas; AreasPage {} }
                Component { id: startup; StartupPage {} }
                Component { id: login; LoginPage {} }
                Component { id: power; PowerPage {} }
                Component { id: health; HealthPage {} }

                // Unsaved changes
                Rectangle {
                    id: bar
                    readonly property bool navSkip: !shown
                    readonly property bool shown: Backend.dirty || Backend.busy
                    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                    y: shown ? parent.height - height - 12 : parent.height + 14
                    height: 60
                    radius: 30
                    color: Theme.containerHighest
                    scale: shown ? 1 : 0.9
                    Behavior on y { Anim { kind: bar.shown ? "default" : "accel" } }
                    Behavior on scale { Anim { kind: bar.shown ? "default" : "accel" } }
                    Behavior on color { CAnim {} }
                    Rectangle {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.primary
                        SequentialAnimation on scale {
                            running: bar.shown && !Backend.busy && Ui.awake
                            loops: Animation.Infinite
                            Anim { to: 1.35; kind: "slow"; duration: 900 }
                            Anim { to: 0.8; kind: "slow"; duration: 900 }
                        }
                    }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 48; rightMargin: 10 }
                        Txt { Layout.fillWidth: true; text: I18n.tr("Unsaved changes") }
                        Btn { text: I18n.tr("Discard"); kind: "text"; enabled: !Backend.busy; onClicked: Backend.discard() }
                        Btn {
                            text: Backend.busy ? I18n.tr("Applying…") : I18n.tr("Apply")
                            icon: "check"
                            kind: "filled"
                            loading: Backend.busy
                            onClicked: Backend.apply()
                        }
                    }
                }

                // Toast
                Rectangle {
                    id: toastBox
                    readonly property bool shown: Backend.message !== "" && Backend.ready
                    property string text
                    property bool bad
                    readonly property int rest: content.height - height - 14 - (bar.shown ? 72 : 0)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: shown ? rest : content.height + 20
                    width: Math.min(parent.width - 60, toastRow.implicitWidth + 44)
                    height: toast.height + 26
                    radius: shown ? 22 : 60
                    scale: shown ? 1 : 0.8
                    color: bad ? Theme.errorContainer : Theme.primary
                    Behavior on y { Anim { kind: toastBox.shown ? "default" : "accel" } }
                    Behavior on scale { Anim { kind: toastBox.shown ? "default" : "accel" } }
                    Behavior on radius { Anim { kind: "default" } }
                    Connections {
                        target: Backend
                        function onMessageChanged(): void {
                            if (Backend.message === "")
                                return; // keep the text while it slides away
                            toastBox.text = Backend.message;
                            toastBox.bad = Backend.messageIsError;
                            if (toastBox.bad)
                                shake.restart();
                        }
                    }
                    transform: Translate { id: shakeX }
                    SequentialAnimation {
                        id: shake
                        PauseAnimation { duration: 260 }
                        NumberAnimation { target: shakeX; property: "x"; to: 9; duration: 60 }
                        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 80 }
                        NumberAnimation { target: shakeX; property: "x"; to: 5; duration: 70 }
                        Anim { target: shakeX; property: "x"; to: 0; kind: "fast" }
                    }
                    Row {
                        id: toastRow
                        anchors.centerIn: parent
                        spacing: 10
                        Ico { anchors.verticalCenter: parent.verticalCenter; text: toastBox.bad ? "error" : "check_circle"; fill: 1; size: 20; color: toastBox.bad ? Theme.fgError : Theme.fgPrimary }
                        Txt { id: toast; width: Math.min(implicitWidth, content.width - 150); wrapMode: Text.WordWrap; elide: Text.ElideNone; text: toastBox.text; color: toastBox.bad ? Theme.fgError : Theme.fgPrimary; weight: Font.Medium }
                    }
                }
            }

            RowLayout {
                id: windowButtons
                anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: 6 }
                spacing: 0
                Btn { icon: "keyboard"; kind: "text"; windowButton: true; onClicked: help.open = true }
                Btn { icon: "close"; kind: "text"; windowButton: true; onClicked: bg.quit() }
            }

            Help { id: help }
            Picker { id: picker; Component.onCompleted: Ui.picker = picker }
            GifPicker { id: gifPicker; Component.onCompleted: Ui.gifPicker = gifPicker }
            ShortcutsSheet { id: shortcutsSheet; Component.onCompleted: Ui.shortcuts = shortcutsSheet }
        }
    }
}
