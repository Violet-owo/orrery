import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    title: I18n.tr("Appearance")
    intro: I18n.tr("How Orrery looks. Saved immediately; colours always follow Caelestia.")

    Rectangle {
        id: hero
        Layout.fillWidth: true
        Layout.bottomMargin: 12
        implicitHeight: 150
        radius: Theme.rLg
        color: Theme.primary
        clip: true
        opacity: enter.p
        transform: Translate { y: (1 - enter.p) * 34 }
        Behavior on color { CAnim {} }
        Behavior on radius { Anim {} }
        Enter { id: enter }
        // A small orrery, turning at the chosen animation speed
        Item {
            id: sky
            anchors { right: parent.right; rightMargin: 40; verticalCenter: parent.verticalCenter }
            width: 130
            height: 130
            property real t: 0
            NumberAnimation on t { from: 0; to: 360; duration: 14000 * Theme.animScale; loops: Animation.Infinite }
            Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: Theme.fgPrimary }
            Repeater {
                model: [[26, 8, 5], [42, 11, 2.4], [60, 7, 1]]
                Item {
                    required property var modelData
                    anchors.fill: parent
                    Rectangle { anchors.centerIn: parent; width: modelData[0] * 2; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.alpha(Theme.fgPrimary, 0.3) }
                    Rectangle {
                        readonly property real a: sky.t * modelData[2] * Math.PI / 180
                        width: modelData[1] * 2
                        height: width
                        radius: width / 2
                        color: Theme.fgPrimary
                        x: sky.width / 2 + Math.cos(a) * modelData[0] - width / 2
                        y: sky.height / 2 + Math.sin(a) * modelData[0] - height / 2
                    }
                }
            }
        }
        Column {
            anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
            spacing: 4
            Txt { text: "Orrery"; size: 34; weight: Font.Bold; color: Theme.fgPrimary }
            Txt { text: I18n.tr("Extra settings for Caelestia"); color: Theme.fgPrimary }
        }
    }

    Head { text: I18n.tr("Transparency"); Layout.topMargin: 4 }
    ToggleTile {
        first: true
        icon: "sync"
        label: I18n.tr("Follow Caelestia")
        sub: I18n.tr("Uses the transparency and animation speed of the shell")
        checked: Theme.prefs.follow
        onToggled: v => Theme.setPref("follow", v)
    }
    ToggleTile {
        icon: "opacity"
        label: I18n.tr("Transparency")
        sub: I18n.tr("Base %1, layers %2").replace("%1", Theme.baseAlpha).replace("%2", Theme.layerAlpha)
        dim: Theme.prefs.follow
        checked: Theme.transparent
        onToggled: v => Theme.setPrefs({ follow: false, transparent: v, base: Theme.baseAlpha, layers: Theme.layerAlpha, speed: Theme.animScale })
    }
    SliderTile { dim: Theme.prefs.follow || !Theme.transparent; icon: "blur_on"; label: I18n.tr("Background opacity"); from: 0.3; to: 1; step: 0.05; value: Theme.baseAlpha; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: v, layers: Theme.layerAlpha, speed: Theme.animScale }) }
    SliderTile { last: true; dim: Theme.prefs.follow || !Theme.transparent; icon: "layers"; label: I18n.tr("Layer opacity"); from: 0.1; to: 1; step: 0.05; value: Theme.layerAlpha; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: Theme.baseAlpha, layers: v, speed: Theme.animScale }) }

    Head { text: I18n.tr("Motion and shape") }
    SliderTile { first: true; icon: "animation"; dim: Theme.prefs.follow; label: I18n.tr("Animation duration"); sub: I18n.tr("Lower is faster"); from: 0.25; to: 2; step: 0.05; suffix: "×"; value: Theme.animScale; onMoved: v => Theme.setPrefs({ follow: false, transparent: Theme.transparent, base: Theme.baseAlpha, layers: Theme.layerAlpha, speed: v }) }
    SliderTile { last: true; icon: "rounded_corner"; label: I18n.tr("Rounding"); from: 0; to: 1.5; step: 0.1; suffix: "×"; value: Theme.prefs.rounding; onMoved: v => Theme.setPref("rounding", v) }

    Head { text: I18n.tr("Language") }
    SelectTile {
        first: true
        last: true
        icon: "translate"
        label: I18n.tr("Language")
        items: [{ value: "auto", label: I18n.tr("System") }, { value: "en", label: "English" }, { value: "it", label: "Italiano" }]
        current: Theme.prefs.language
        onPicked: v => Theme.setPref("language", v)
    }
}
