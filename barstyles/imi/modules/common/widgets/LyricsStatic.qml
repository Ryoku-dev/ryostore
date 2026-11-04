import QtQuick
import "../../../services"
import ".."
import "."

StyledText {
    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    font.pixelSize: Appearance.font.pixelSize.smallie
    text: LyricsService.syncedLines[LyricsService.currentIndex] ? LyricsService.syncedLines[LyricsService.currentIndex].text : "" 
    animateChange: true
    elide: Text.ElideRight
}