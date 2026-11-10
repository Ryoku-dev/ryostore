import QtQuick
import QtQuick.Controls
ComboBox {
    id: control
    required property var i18n
    signal chosen()
    implicitWidth: 100
    implicitHeight: 34
    model: [i18n.t("language.auto"),"Português","English","Español","Français"]
    currentIndex: Math.max(0,i18n.options.indexOf(i18n.requestedLanguage))
    displayText: currentIndex===0 ? i18n.t("language.shortAuto")+" · "+i18n.language.toUpperCase() : i18n.language.toUpperCase()
    onActivated: index => {i18n.setLanguage(i18n.options[index]);control.chosen();}
    Accessible.name: i18n.t("language.label")
    ToolTip.visible: hovered
    ToolTip.text: i18n.t("language.label")
    ToolTip.delay: 650
    palette.text: Theme.ink
    palette.buttonText: Theme.ink
    palette.windowText: Theme.ink
    palette.window: Theme.raised
    palette.base: Theme.surface
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.accentInk
    background: Rectangle {radius:9;color:control.hovered?Theme.hover:Theme.raised;border.color:Theme.border}
    popup.width: 200
}
