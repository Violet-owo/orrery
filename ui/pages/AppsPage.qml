import QtQuick
import QtQuick.Layouts
import qs.core
import qs.controls

Page {
    title: I18n.tr("Default apps")
    intro: I18n.tr("Used for links and files, and for Caelestia's own shortcuts.")

    Repeater {
        id: rep
        model: [
            { id: "browser", icon: "language", name: "Web browser" },
            { id: "terminal", icon: "terminal", name: "Terminal" },
            { id: "editor", icon: "edit_note", name: "Text editor" },
            { id: "files", icon: "folder", name: "File manager" },
            { id: "images", icon: "image", name: "Images" },
            { id: "video", icon: "movie", name: "Video" },
            { id: "music", icon: "music_note", name: "Music" },
            { id: "pdf", icon: "picture_as_pdf", name: "PDF" },
            { id: "mail", icon: "mail", name: "Mail" }
        ]

        SelectTile {
            required property var modelData
            required property int index

            first: index === 0
            last: index === rep.count - 1
            icon: modelData.icon
            label: I18n.tr(modelData.name)
            sub: current === "" ? now : ""
            current: Backend.cfg.apps[modelData.id]
            readonly property string now: Backend.appsById[Backend.st.defaults[modelData.id]]?.name ?? ""
            items: [{ value: "", label: I18n.tr("Leave as it is"), sub: now }].concat((Backend.st.roles[modelData.id] ?? []).map(i => ({ value: i, label: Backend.appsById[i]?.name ?? i, sub: Backend.appsById[i]?.command })))
            onPicked: v => Backend.mutate(c => c.apps[modelData.id] = v)
        }
    }
}
