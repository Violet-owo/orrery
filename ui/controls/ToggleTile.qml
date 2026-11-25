import QtQuick

Tile {
    id: root
    property bool checked
    signal toggled(bool value)

    clickable: true
    iconFill: checked ? 1 : 0
    onClicked: toggled(!checked)

    Toggle { checked: root.checked; held: root.held }
}
