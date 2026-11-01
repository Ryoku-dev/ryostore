import QtQuick.Layouts
import "../../../config"
import "../../../port/i18n"
import "../../../components"
import "../../../services"

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        text: Hypr.capsLock ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled")
    }

    StyledText {
        text: Hypr.numLock ? Tr.tr("Num lock enabled") : Tr.tr("Num lock disabled")
    }
}
