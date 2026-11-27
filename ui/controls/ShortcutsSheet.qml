import QtQuick
import QtQuick.Layouts
import qs.core

// Every desktop shortcut, read-only: Caelestia's, Orrery's and yours, with what Hyprland really has active.
Item {
    id: root
    property bool open: false
    property bool loading: false
    property var rows: []
    property string query: ""
    property Item before: null
    readonly property Item view: list
    readonly property var groups: ["Areas", "Shell", "Workspaces", "Windows", "Apps", "Tools", "Media", "Yours", "Other"]
    readonly property var shown: {
        const q = query.toLowerCase();
        return rows.filter(r => !q || `${I18n.tr(r.label)} ${r.label} ${r.sub} ${r.keys.join(" ")} ${I18n.tr(r.group)}`.toLowerCase().includes(q))
            .sort((a, b) => groups.indexOf(a.group) - groups.indexOf(b.group));
    }

    function show(): void {
        before = Nav.current;
        open = true;
        search.text = "";
        search.forceActiveFocus();
        loading = true;
        Backend.call("shortcuts", {}, r => {
            loading = false;
            rows = r.shortcuts ?? [];
        });
    }
    function close(): void {
        open = false;
        if (before) before.forceActiveFocus(Qt.OtherFocusReason);
    }

    // Hyprland's key names, as people say them
    readonly property var names: ({
        "SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift", "SUPER_L": "Super", "Escape": "Esc", "TAB": "Tab", "Tab": "Tab",
        "Space": "Space", "Delete": "Delete", "Backspace": "Backspace", "Print": "Print", "Comma": ",", "Period": ".", "Backslash": "\\",
        "Minus": "-", "Equal": "=", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Page_Up": "Page ↑", "Page_Down": "Page ↓",
        "mouse_up": "Wheel ↑", "mouse_down": "Wheel ↓", "mouse:272": "Left click", "mouse:273": "Right click",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pause", "XF86AudioNext": "Next ⏭", "XF86AudioPrev": "Previous ⏮", "XF86AudioStop": "Stop ⏹",
        "XF86AudioMute": "Mute 🔇", "XF86AudioMicMute": "Mic mute", "XF86AudioRaiseVolume": "Volume +", "XF86AudioLowerVolume": "Volume −",
        "XF86MonBrightnessUp": "Brightness +", "XF86MonBrightnessDown": "Brightness −" })
    function parts(combo: string): var {
        if (combo.replace(/\s/g, "").toUpperCase() === "SUPER+SUPER_L")
            return [I18n.tr("Super, alone")];
        return combo.split("+").map(p => p.trim()).filter(p => p).map(p => {
            const n = names[p] ?? names[p.toUpperCase()];
            return n ? I18n.tr(n) : p.length === 1 ? p.toUpperCase() : p;
        });
    }

    readonly property bool navSkip: true
    anchors.fill: parent
    visible: open || scrim.opacity > 0

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
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(900, parent.width - 60)
        height: parent.height - 80
        y: 40 + (root.open ? 0 : 50)
        radius: root.open ? Theme.rLg : 60
        color: Theme.container
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.92
        Behavior on y { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on scale { Anim { kind: root.open ? "default" : "accel" } }
        Behavior on radius { Anim { kind: "default" } }
        Behavior on opacity { Anim { kind: "fx" } }
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 18 }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Ico { text: "keyboard_command_key"; size: 24; color: Theme.primary; Layout.leftMargin: 6 }
                Txt { Layout.fillWidth: true; text: I18n.tr("Desktop shortcuts"); size: 18; weight: Font.Medium }
                Txt { text: I18n.tr("%1 shortcuts").replace("%1", root.shown.length); color: Theme.fgVariant; size: 12 }
                Btn { icon: "close"; kind: "text"; onClicked: root.close() }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: 21
                color: Theme.containerHighest
                Ico { id: lens; anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "search"; size: 20; color: search.activeFocus ? Theme.primary : Theme.fgVariant }
                TextInput {
                    id: search
                    anchors { left: lens.right; right: parent.right; leftMargin: 8; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.fgPrimary
                    font.family: Theme.font
                    font.pixelSize: 14
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.close()
                    Keys.onDownPressed: list.forceActiveFocus()
                    Txt { visible: !search.text; text: I18n.tr("Search an action or a key, for example “screenshot” or “Super + D”"); color: Theme.outline }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: root.shown
                keyNavigationEnabled: true
                boundsBehavior: Flickable.StopAtBounds
                Keys.onEscapePressed: root.close()
                Keys.onUpPressed: e => { if (currentIndex <= 0) search.forceActiveFocus(); else e.accepted = false; }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool off: modelData.active === false
                    readonly property bool head: index === 0 || root.shown[index - 1]?.group !== modelData.group
                    width: ListView.view.width - 14     // room for the scroll bar
                    implicitHeight: card.height + (head ? title.height : 0)
                    Txt {
                        id: title
                        visible: row.head
                        topPadding: row.index === 0 ? 4 : 14
                        bottomPadding: 6
                        leftPadding: 8
                        text: I18n.tr(row.modelData.group)
                        color: Theme.primary
                        weight: Font.Medium
                        size: 13
                    }
                    Rectangle {
                    id: card
                    y: row.head ? title.height : 0
                    width: parent.width
                    implicitHeight: Math.max(52, line.implicitHeight + 20)
                    radius: Theme.rMd
                    color: row.ListView.isCurrentItem && list.activeFocus ? Theme.containerHighest : Theme.containerHigh
                    opacity: row.off ? 0.5 : 1
                    RowLayout {
                        id: line
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 12 }
                        spacing: 14
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Txt { text: I18n.tr(row.modelData.label); elide: Text.ElideRight; Layout.maximumWidth: list.width * 0.42 }
                                Rectangle {
                                    visible: row.modelData.source === "orrery"
                                    implicitWidth: tag.implicitWidth + 14; implicitHeight: 20; radius: 10
                                    color: Theme.secondaryContainer
                                    Txt { id: tag; anchors.centerIn: parent; text: "Orrery"; size: 10; color: Theme.fgSecondary }
                                }
                            }
                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                size: 11
                                elide: Text.ElideRight
                                color: row.modelData.twice?.length || row.modelData.missing ? Theme.error : Theme.fgVariant
                                text: [row.modelData.sub,
                                       row.off ? I18n.tr("Not active") : "",
                                       row.modelData.missing ? I18n.tr("App not installed: the key does nothing") : "",
                                       row.modelData.twice?.length ? I18n.tr("Same key as: %1").replace("%1", row.modelData.twice.map(t => I18n.tr(t)).join(", ")) : ""]
                                      .filter(x => x).join(" · ")
                            }
                        }
                        // One line per combination, against the right edge
                        ColumnLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 4
                            Repeater {
                                model: row.modelData.keys
                                Row {
                                    id: combo
                                    required property string modelData
                                    Layout.alignment: Qt.AlignRight
                                    spacing: 3
                                    Repeater {
                                        model: root.parts(combo.modelData)
                                        Rectangle {
                                            required property string modelData
                                            implicitWidth: Math.max(26, k.implicitWidth + 14)
                                            implicitHeight: 26
                                            radius: 8
                                            color: Theme.container
                                            border.width: 1
                                            border.color: Qt.alpha(Theme.outline, 0.5)
                                            Txt { id: k; anchors.centerIn: parent; text: parent.modelData; size: 12; weight: Font.Medium }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    }
                }
                OrreryLoader { anchors.centerIn: parent; size: 96; visible: root.loading }
                Scroller { parent: list; target: list }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                wrapMode: Text.WordWrap
                size: 11
                color: Theme.fgVariant
                text: I18n.tr("Areas and the layout key are set in Orrery. Caelestia's own keys can be changed in ~/.config/caelestia/hypr-vars.lua.")
            }
        }
    }
}
