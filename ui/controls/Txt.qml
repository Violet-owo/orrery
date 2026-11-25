import QtQuick
import qs.core

Text {
    property int size: 14
    property int weight: Font.Normal

    color: Theme.fg
    font.family: Theme.font
    font.pixelSize: size
    font.weight: weight
    elide: Text.ElideRight
    textFormat: Text.PlainText
    renderType: Text.NativeRendering

    Behavior on color { CAnim {} }
}
