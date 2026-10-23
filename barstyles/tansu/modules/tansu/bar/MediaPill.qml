import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

// The media widget, matching the Figma "Media (Nothing Playing)" and
// "Media (Playing)" frames:
//
//   [ album art | divider |   Title (bold)   ]
//   [           |         |   Artist (light)  ]
//
// Pure UI (no Quickshell imports): Bar.qml -> Status_Bar.qml feed it
// plain properties and turn its signals into actions.
//
//   active   false -> single centered "Nothing Playing"
//            true  -> title, plus the artist underneath when there is one
//   playing  false while paused -> the content dims, the pill stays put
//
// Width follows the text (never below minWidth, never above maxWidth —
// Status_Bar sets maxWidth so this can't run into its neighbours), and
// long titles elide inside that.
//
// Click: left = play/pause, right = next track, middle = previous.
//
// Notifications used to take this pill over while one was showing; they
// now alert on the Quick Panel's phone instead (see QuickPanel.qml), so
// this file is just the media widget.
Pill {
    id: root

    property bool vertical: false

    property bool active: false
    property bool playing: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""

    // end4-pC's little visualizers, inside the pill (Settings -> Desktop -> "Media pill
    // visualizer"): "none", "dots" (PillBars.qml) or "wave" (PillWave.qml). `points` are
    // cava's bands (PcCavaService.qml). Never on a standing bar.
    property string visualizerStyle: "none"
    property var points: []
    readonly property bool showViz: !root.vertical && root.active && root.visualizerStyle !== "none"
    readonly property real vizWidth: root.visualizerStyle === "wave" ? 40 : 18
    readonly property real vizReserve: root.showViz ? root.vizWidth + 6 : 0

    property string mediaIcon: "genres"

    property real minWidth: 220
    property real maxWidth: 360

    // Natural text widths, measured independently of the live Text items. The
    // Text widths track the pill's own width (so a long title elides), which would
    // otherwise feed back into implicitWidth and trip Qt's binding-loop guard.
    TextMetrics {
        id: titleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.capsule ? Theme.fontSizeInfo : (root.active ? root.titleSize : root.idleSize)
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        text: root.active ? root.title : "Nothing Playing"
    }
    TextMetrics {
        id: artistMetrics
        font.family: Theme.fontFamily
        font.pixelSize: root.artistSize
        font.weight: Font.DemiBold
        text: root.artist
    }

    property int titleSize: 13
    property int artistSize: 11
    property int idleSize: Theme.fontSizeIdle

    property bool leftOpensPanel: true
    property bool wheelVolume: true
    property bool volumeAvailable: false

    signal toggleRequested()
    signal nextRequested()
    signal previousRequested()
    signal panelRequested()
    signal scrolled(int direction)

    // playing/title are a live reflection of the real MPRIS player
    // state (see MediaSource.qml) — they update the same way whether
    // play/pause/next/previous was triggered by clicking this pill or
    // by a keyboard media key (or another app's own controls) that
    // never touched this widget at all. Watch for that and pulse the
    // pill itself: a quick programmatic press-then-pop, same
    // animation a click gives, so it visually "presses" in sync with
    // whatever just happened to actually change playback.
    property bool keyPulse: false

    property bool suppressPulse: false

    onPlayingChanged: externalPulse()
    onTitleChanged: externalPulse()

    function externalPulse() {
        if (suppressPulse)
            return
        keyPulse = true
        pulseRelease.restart()
    }

    Timer {
        id: pulseRelease
        interval: 90
        onTriggered: root.keyPulse = false
    }

    Timer {
        id: suppressGrace
        interval: 400
        onTriggered: root.suppressPulse = false
    }

    readonly property real artWidth: root.capsule ? 24 : 35
    readonly property real dividerWidth: root.capsule ? 0 : 2
    readonly property real textMargin: 10
    readonly property color ink: root.capsule ? Theme.capInk : Theme.inkOnAccent

    cornerRadius: Theme.radiusBadge
    ringWidth: 3
    fillColor: Theme.surface

    readonly property Gradient mediaGradient: Gradient {
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }
    fillGradient: mediaGradient

    // Physical press, same as the workspace badges: pushes flush
    // into its own shadow on mouse-down, pops back on release.
    // Combines the real MouseArea press below with the auto-pulse
    // above, so it looks the same whether a human clicked it or a
    // media key changed playback. "enabled: root.active" on
    // mediaArea below already means the click half of this never
    // fires while there's nothing to click.
    pressed: mediaArea.pressed || root.keyPulse

    implicitWidth: artWidth + dividerWidth + textMargin * 2 + root.vizReserve
        + Math.max(titleMetrics.advanceWidth, artistText.visible ? artistMetrics.advanceWidth : 0)
    width: root.vertical ? (root.capsule ? Theme.capVChip : Theme.barVPillWidth - 4) : Math.max(minWidth, Math.min(maxWidth, implicitWidth))
    implicitHeight: root.vertical ? (root.capsule ? Theme.capVChip : Theme.barVPillWidth - 4) + Theme.shadowOffset
                                  : Theme.pillHeight + Theme.shadowOffset

    Behavior on width {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    readonly property real dim: root.active && !root.playing ? 0.55 : 1.0

    Item {
        id: body
        anchors.fill: parent

        Item {
            id: art
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.vertical ? parent.width : root.artWidth

            Item {
                id: artInner
                width: parent.width
                height: parent.height

                Item {
                    id: artContent
                    anchors.fill: parent
                    opacity: root.dim

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    MaterialIcon {
                        color: root.ink
                        anchors.centerIn: parent
                        size: 22
                        name: root.mediaIcon
                    }

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: root.active ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize: Qt.size(Math.max(1, art.width) * 2, Math.max(1, art.height) * 2)
                        // Don't reuse a stale image when a player rewrites
                        // the same cover file for the next track.
                        cache: false
                        visible: status === Image.Ready && !root.capsule

                        onStatusChanged: {
                            if (status === Image.Error)
                                console.warn("MediaPill: couldn't load cover art from " + source)
                        }
                    }
                }

                // Rounded corners without masking: redraw the pill's own
                // frame (white ring, then the navy outline — the very same
                // two rounded Rectangles Pill.qml draws) on top of the art,
                // clipped to the art's box. Where the square art overhangs
                // the curve, the frame covers it again, and because it's
                // the same primitive as the pill itself the corners are
                // exactly as smooth as the rest of the outline. The frame
                // is made much wider than the art so its right-hand
                // corners fall outside the clip and the art's right edge
                // stays square against the divider.
                Item {
                    anchors.fill: parent
                    clip: true
                    visible: !root.capsule

                    Rectangle {
                        x: -root.ringWidth
                        y: -root.ringWidth
                        width: root.vertical ? art.width + root.ringWidth * 2
                                             : root.artWidth + root.cornerRadius * 4
                        height: parent.height + root.ringWidth * 2
                        radius: root.effectiveRadius
                        color: "transparent"
                        border.width: root.ringWidth
                        border.color: Theme.ringWhite
                        antialiasing: true
                    }
                    Rectangle {
                        x: -root.ringWidth
                        y: -root.ringWidth
                        width: root.vertical ? art.width + root.ringWidth * 2
                                             : root.artWidth + root.cornerRadius * 4
                        height: parent.height + root.ringWidth * 2
                        radius: root.effectiveRadius
                        color: "transparent"
                        border.width: Theme.borderWidth
                        border.color: Theme.line
                        antialiasing: true
                    }
                }
            }
        }

        Rectangle {
            id: divider
            visible: !root.vertical && !root.capsule
            anchors.left: art.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.dividerWidth
            color: Theme.surface
        }

        Item {
            visible: !root.vertical
            anchors.left: divider.right
            anchors.leftMargin: root.textMargin
            anchors.right: parent.right
            anchors.rightMargin: root.textMargin + root.vizReserve
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            clip: true

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: 1

                Text {
                    id: titleText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.active ? root.title : "Nothing Playing"
                    color: root.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: root.capsule ? Theme.fontSizeInfo : (root.active ? root.titleSize : root.idleSize)
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.05)
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    id: artistText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: root.active && root.artist !== "" && !root.capsule
                    text: root.artist
                    color: Theme.inkOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: root.artistSize
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.05)
                    font.weight: Font.DemiBold
                }
            }
        }

        Loader {
            anchors.right: parent.right
            anchors.rightMargin: root.textMargin
            anchors.verticalCenter: parent.verticalCenter
            width: root.vizWidth
            height: root.capsule ? 14 : 22
            active: root.showViz
            opacity: root.dim
            sourceComponent: root.visualizerStyle === "wave" ? waveComp : dotsComp
        }

        Component {
            id: waveComp
            PillWave {
                points: root.points
                live: root.playing
                color: root.ink
                fillAlpha: 0.35
            }
        }

        Component {
            id: dotsComp
            PillBars {
                points: root.points
                live: root.playing
                contentColor: root.ink
                barCount: 3
                maxBarHeight: root.capsule ? 14 : 22
            }
        }

        ScrollHint {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -8
            anchors.rightMargin: -8
            active: root.active && root.wheelVolume && root.volumeAvailable && !root.capsule
            glyph: "volume_up"
        }

        MouseArea {
            id: mediaArea
            anchors.fill: parent
            anchors.margins: -root.ringWidth
            enabled: root.active
            cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton) {
                    if (root.leftOpensPanel)
                        root.panelRequested()
                    else
                        root.toggleRequested()
                } else if (mouse.button === Qt.RightButton) {
                    root.nextRequested()
                } else if (mouse.button === Qt.MiddleButton) {
                    if (root.leftOpensPanel)
                        root.toggleRequested()
                    else
                        root.previousRequested()
                }
            }
            onWheel: wheel => {
                if (!root.wheelVolume || wheel.angleDelta.y === 0) {
                    wheel.accepted = false
                    return
                }
                root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
            }
            onPressed: root.suppressPulse = true
            onReleased: suppressGrace.restart()
            onCanceled: suppressGrace.restart()
        }
    }
}
