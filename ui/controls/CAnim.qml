import QtQuick
import qs.core

ColorAnimation {
    duration: 300 * Theme.animScale
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.34, 0.88, 0.34, 1, 1, 1]
}
