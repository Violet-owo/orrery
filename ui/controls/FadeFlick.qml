import QtQuick
import QtQuick.Effects
import qs.core

// Flickable whose content dissolves at the top and bottom edges, like Caelestia's
Flickable {
    id: root
    property int fade: 46
    property real topAlpha: contentY > 1 ? 0 : 1
    property real bottomAlpha: contentY + height < contentHeight - 1 ? 0 : 1
    Behavior on topAlpha { Anim { kind: "fxSlow" } }
    Behavior on bottomAlpha { Anim { kind: "fxSlow" } }

    clip: true
    flickableDirection: Flickable.VerticalFlick
    layer.enabled: topAlpha < 1 || bottomAlpha < 1
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    Rectangle {
        id: mask
        parent: root
        width: root.width
        height: root.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, root.topAlpha) }
            GradientStop { position: Math.min(0.4, root.fade / Math.max(1, root.height)); color: "black" }
            GradientStop { position: 1 - Math.min(0.4, root.fade / Math.max(1, root.height)); color: "black" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.bottomAlpha) }
        }
    }
}
