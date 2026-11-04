import "../../shared"
import "../../../../../services"
import "../../../../common"
import "../../../../common/widgets"
import "../../shared/cards"

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../.."

StyledPopup {
    id: root
    popupId: "weather"
    popupRadius: Appearance.rounding.large
    animate: false // We have to disable the animation if we have only one card
    contentItem: HeroCard {
        id: weatherHero
        startAnim: root.opened && root.popupOpenProgress > 0.6
        anchors.centerIn: parent
        Layout.minimumWidth: 320
        margins: 20
        iconSize: 100
        iconUrl: WeatherIcons.getWeatherIcon(Weather.data?.wCode ?? 113, false)
        pillText: Weather.data.city || "--"
        pillIcon: Weather.data.city ? "location_on" : ""
        title: Weather.data.temp
        subtitle: Weather.data.wDesc
    }
}
