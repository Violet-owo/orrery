import QtQuick
import qs.core

// Caelestia's own curves and durations (Material 3 Expressive), scaled by its animation speed setting.
// Spatial kinds overshoot: use them for position, size and corners. Effects (fx) do not: colour and opacity.
NumberAnimation {
    property string kind: "default" // fast | default | slow | fx | fxSlow | decel | accel

    readonly property var spec: ({
            "fast": [350, [0.42, 1.67, 0.21, 0.9, 1, 1]],
            "default": [500, [0.38, 1.21, 0.22, 1, 1, 1]],
            "slow": [650, [0.39, 1.29, 0.35, 0.98, 1, 1]],
            "fx": [200, [0.34, 0.8, 0.34, 1, 1, 1]],
            "fxSlow": [300, [0.34, 0.88, 0.34, 1, 1, 1]],
            "decel": [400, [0.05, 0.7, 0.1, 1, 1, 1]],
            "accel": [200, [0.3, 0, 0.8, 0.15, 1, 1]]
        })[kind]

    duration: spec[0] * Theme.animScale
    easing.type: Easing.BezierSpline
    easing.bezierCurve: spec[1]
}
