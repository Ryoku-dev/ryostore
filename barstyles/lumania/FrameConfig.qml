import QtQuick
import shell.services

QtObject {
  id: config

  property var settings: ({})

  function num(key, fallback) {
    var v = settings ? settings[key] : undefined
    return (typeof v === "number" && isFinite(v)) ? v : fallback
  }

  readonly property int borderThickness: Math.max(1, Math.min(12, num("borderThickness", 5)))

  readonly property color activeBorderColor: Theme.surface
  readonly property color activeTextColor: Theme.onSurface
  readonly property color accentColor: Theme.primary
  readonly property color accentTextColor: Theme.onPrimary
  readonly property color mutedColor: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.72)
  readonly property color activeSliderFillColor: accentColor
  readonly property color activeSliderIconColorFilled: accentTextColor

  readonly property bool reduceMotion: settings ? settings.reduceMotion === true : false
  readonly property bool islandNotifications: settings ? settings.islandNotifications !== false : true

  readonly property real topLeftRadius: num("radius", 16)
  readonly property real topRightRadius: num("radius", 16)
  readonly property real bottomLeftRadius: num("radius", 16)
  readonly property real bottomRightRadius: num("radius", 16)

  readonly property string cornerStyle: (settings && settings.cornerStyle) ? settings.cornerStyle : "squircle"

  property real squircleFactor: 0.52

  readonly property int islandBodyWidth: Math.max(150, Math.min(320, num("islandWidth", 206)))
  property int islandTopCurveRadius: 10
  property int islandExpandedTopCurveRadius: 14
  property int islandBottomCornerRadius: 15
  property int islandExpandedBottomCornerRadius: 28
  property int islandHoverWidthDelta: 140
  property int islandHoverHeightDeltaIdle: 46
  property int islandHoverHeightDeltaMedia: 24

  property real trayNotchRightMargin: 26
  property real trayNotchBaseHeight: 37
  property real trayNotchHoverHeightDelta: 5
  property real trayNotchTopCurveRadius: 10
  property real trayNotchExpandedTopCurveRadius: 12
  property real trayNotchBottomCornerRadius: 15
  property real trayNotchExpandedBottomCornerRadius: 18
  property real trayNotchItemSize: 28
  property real trayNotchItemRadius: 8
  property real trayNotchItemSpacing: 6
  property real trayNotchSidePadding: 12
  property int trayNotchOpenDuration: 340
  property int trayNotchCloseDuration: 280
  property real trayNotchOpenOvershoot: 1.08

  property real powerNotchLeftMargin: 26
  property real powerNotchBaseHeight: trayNotchBaseHeight
  property real powerNotchHoverHeightDelta: trayNotchHoverHeightDelta
  property real powerNotchTopCurveRadius: trayNotchTopCurveRadius
  property real powerNotchExpandedTopCurveRadius: trayNotchExpandedTopCurveRadius
  property real powerNotchBottomCornerRadius: trayNotchBottomCornerRadius
  property real powerNotchExpandedBottomCornerRadius: trayNotchExpandedBottomCornerRadius
  property real powerNotchItemSize: 26
  property real powerNotchItemRadius: 7
  property real powerNotchItemSpacing: 6
  property real powerNotchSidePadding: 12
  property int powerNotchOpenDuration: 340
  property int powerNotchCloseDuration: 280
  property real powerNotchOpenOvershoot: 1.08

  property real controlCollapsedWidth: 110

  property real controlRightTabWidth: 10

  property real controlExpandedWidth: 312

  property real controlCollapsedHeight: 5

  property real controlRightTabHeight: 100

  property real controlExpandedHeight: 252

  property real controlTabCapRadius: 5
  property real controlInnerRadius: 12
  property real controlCornerRadius: 10
  property real controlFlareRadius: 12
  property real controlExpandedCornerRadius: 20
  property real controlExpandedFlareRadius: 12
  property real controlCurveTension: 0.55

  property int controlOpenDuration: 300
  property int controlCloseDuration: 220
  property real controlOpenOvershoot: 1.08
  property real controlWidthPulse: 10
  property real controlHeightPulse: 6

  property real controlButtonSize: 46
  property real controlPowerButtonSize: 46
  property real controlSliderWidth: 160
  property real controlSliderHeight: 46
  property real controlBatteryRowWidth: 272
  property real controlBatteryHeight: 42

  property real controlSubpanelWidth: 300
  property real controlSubpanelHeight: 236
  property real controlSubpanelFlareRadius: 20
  property real controlSubpanelCornerRadius: 22

  property real workspaceTopMargin: 68

  property real workspaceWidth: 61

  property real workspaceSidePadding: 12

  property real workspaceHeight: 272

  property real workspaceItemSize: 32
  property real workspaceItemRadius: 10
  property real workspaceItemSpacing: 12
  property real workspaceRailPadding: 32

  property real workspaceCornerRadius: 16
  property real workspaceFlareRadius: 12

  property int workspaceOpenDuration: 340
  property int workspaceCloseDuration: 280
  property real workspaceOpenOvershoot: 1.08

  property real statusSubpanelWidth: 320
  property real statusSubpanelHeight: 220
  property real statusSubpanelFlareRadius: 16
  property real statusSubpanelBottomRadius: 20
  property real statusSubpanelTopMargin: -4
  property color statusSubpanelBg: activeBorderColor
  property color statusSubpanelBorder: Qt.rgba(0, 0, 0, 0.15)

  property real searchCollapsedWidth: 110

  property real searchLeftTabWidth: 10

  property real searchExpandedWidth: 660

  property real searchCollapsedHeight: 5

  property real searchLeftTabHeight: 100

  property real searchExpandedHeight: 640

  property real searchTabCapRadius: 5

  property real searchInnerRadius: 12

  property real searchCornerRadius: 10

  property real searchFlareRadius: 12

  property real searchExpandedCornerRadius: 26
  property real searchExpandedFlareRadius: 20

  property real searchCurveTension: 0.55

  property real searchTabWidthMaxRatio: 0.25
  property real searchLipFlareMaxRatio: 0.4
  property real searchLipCornerRatio: 0.55
  property real searchTopEdgeGuardRatio: 0.22

  property int searchOpenDuration: 380
  property int searchCloseDuration: 260
  property real searchOpenOvershoot: 1.08
  property real searchWidthPulse: 10
  property real searchHeightPulse: 6

  property real searchPowerButtonSize: 42
  property real searchFooterHeight: 60

  property real searchBarHeight: 46
  property real searchBarRadius: 23
  property int searchGridColumns: 5
  property real searchGridCellHeight: 86
  property color searchFieldBg: Qt.rgba(0, 0, 0, 0.28)
  property color searchItemHoverBg: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.08)
  property color searchItemActiveBg: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.14)
  property color searchItemActiveBorder: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.26)

  property real wallpaperCollapsedWidth: 226

  readonly property int wallpaperMaxVisibleThumbs: Math.max(3, Math.min(7, num("wallpaperThumbs", 7)))

  property real wallpaperCollapsedHeight: 10

  property real wallpaperExpandedHeight: 118

  property real wallpaperFlareRadius: 10

  property real wallpaperCornerRadius: 15

  property real wallpaperExpandedFlareRadius: 22
  property real wallpaperExpandedCornerRadius: 36

  property real wallpaperFlareControlRatio: 0.5

  property real wallpaperBleed: 2

  property real wallpaperTopEdgeGuardRatio: 0.3

  property int wallpaperOpenDuration: 380
  property int wallpaperCloseDuration: 260
  property real wallpaperOpenOvershoot: 1.04
  property real wallpaperOpenResponse: 0.40
  property real wallpaperOpenDamping: 0.84
  property real wallpaperCloseResponse: 0.30
  property real wallpaperCloseDamping: 1.0
  property real wallpaperWidthPulse: 0
  property real wallpaperHeightPulse: 4
  property real wallpaperRestingPressScale: 0.96
  property real wallpaperHoverScale: 1.02
  property real wallpaperSelectedScale: 1.05
  property real wallpaperThumbHoverResponse: 0.30
  property real wallpaperThumbHoverDamping: 0.82
  property int wallpaperHoverCloseDelay: 260
  property int wallpaperPointerPollInterval: 120
  property int wallpaperWatchdogStrikes: 2
  property real wallpaperPointerGrace: 8
  property real wallpaperSpringEpsilon: 0.0004

  property real wallpaperRetractResponse: 0.28
  property real wallpaperRetractDamping: 1.0
  property real wallpaperWakeResponse: 0.36
  property real wallpaperWakeDamping: 0.8

  property real wallpaperPressResponse: 0.18
  property real wallpaperPressDamping: 1.0
  property real wallpaperReleaseResponse: 0.30
  property real wallpaperReleaseDamping: 0.78

  property real wallpaperWakeZoneWidth: 180
  property real wallpaperWakeZoneHeight: 24
  property real wallpaperRetractProgressEpsilon: 0.05

  property real wallpaperContentPadding: 48
  property real wallpaperThumbWidth: 140
  property real wallpaperThumbHeight: 78
  property real wallpaperThumbRadius: 16
  property real wallpaperThumbSpacing: 12
  property int wallpaperThumbSourceScale: 2
  property int wallpaperCacheBuffer: 900
  property int wallpaperThumbFadeDuration: 120

  property real wallpaperSelectedBorderWidth: 2
  property real wallpaperAppliedBorderWidth: 2
  property color wallpaperAppliedBorderColor: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.62)

  property real wallpaperContentFadeStart: 0.10
  property real wallpaperContentFadeRate: 1.6
  property real wallpaperContentScaleFrom: 0.95
  property real wallpaperRestingFadeRate: 3.0
  property real wallpaperRestingHideAt: 0.9

  property bool wallpaperInstantSwitch: false

  property int wallpaperApplyDebounce: 40

  property int wallpaperScanFreshness: 60000

  property bool wallpaperDecodeCacheEnabled: true
  property int wallpaperDecodeCacheMinBytes: 1200000
  property int wallpaperCacheWidth: 1920
  property int wallpaperCacheHeight: 1080
  property int wallpaperCacheQuality: 92

  property color wallpaperThumbBg: Qt.rgba(0, 0, 0, 0.28)
  property color wallpaperThumbBorder: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.18)
  property color wallpaperThumbHoverBorder: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.40)
  property color wallpaperThumbActiveBorder: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.92)
  property color wallpaperItemHoverBg: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.10)

  property color sliderTrackColor: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.20)

  property color sliderFillColor: accentColor

  property color sliderIconColorUnfilled: activeTextColor

  property color sliderIconColorFilled: accentTextColor

  property color powerButtonActiveBg: accentColor
  property color powerButtonInactiveBg: Qt.rgba(activeTextColor.r, activeTextColor.g, activeTextColor.b, 0.12)
  property color powerButtonActiveIcon: accentTextColor
  property color powerButtonInactiveIcon: activeTextColor
}
