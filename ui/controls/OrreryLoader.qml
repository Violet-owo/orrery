import QtQuick
import qs.core

// The logo, moving: the planets go round the sun, the inner ones faster. Drawn in the theme's colours.
Item {
    id: root
    property real size: 96
    property bool running: visible
    readonly property real k: size / 128 // the logo is drawn on 128×128

    implicitWidth: size
    implicitHeight: size

    Repeater {
        model: [22, 35, 48]
        Rectangle {
            required property real modelData
            anchors.centerIn: parent
            width: modelData * 2 * root.k
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, 2.5 * root.k)
            border.color: Qt.alpha(Theme.fgVariant, 0.35)
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: 22 * root.k
        height: width
        radius: width / 2
        color: Theme.primary
        SequentialAnimation on scale {
            running: root.running
            loops: Animation.Infinite
            NumberAnimation { to: 1.12; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }
    // Orbit radius, planet radius, where it starts (as in the logo), seconds per turn
    Repeater {
        model: [[22, 5.5, 201.3, 1.6], [35, 7.5, 320.2, 2.6], [48, 5, 84, 4.2]]
        Item {
            id: orbit
            required property var modelData
            anchors.fill: parent
            rotation: modelData[2]
            Rectangle {
                x: root.size / 2 + orbit.modelData[0] * root.k - width / 2
                y: root.size / 2 - height / 2
                width: orbit.modelData[1] * 2 * root.k
                height: width
                radius: width / 2
                color: Theme.primary
            }
            RotationAnimator on rotation {
                running: root.running
                loops: Animation.Infinite
                from: orbit.modelData[2]
                to: orbit.modelData[2] + 360
                duration: orbit.modelData[3] * 1000
            }
        }
    }
}
