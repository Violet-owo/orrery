import QtQuick
import qs.core

Text {
    property int size: 22
    property real fill: 0

    color: Theme.fg
    textFormat: Text.PlainText
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({ FILL: fill, wght: 500, GRAD: 0, opsz: 24 })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color { CAnim {} }
    Behavior on fill { Anim { kind: "fxSlow" } }
}
