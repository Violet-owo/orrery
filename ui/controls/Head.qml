import QtQuick
import QtQuick.Layouts
import qs.core

Txt {
    size: 13
    weight: Font.Medium
    color: Theme.primary
    Layout.leftMargin: 8
    Layout.topMargin: 18
    Layout.bottomMargin: 4
    opacity: enter.p
    transform: Translate { y: (1 - enter.p) * 34 }
    Enter { id: enter }
}
