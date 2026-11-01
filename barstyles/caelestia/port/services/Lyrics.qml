pragma Singleton

import QtQuick
import Quickshell.Io
import "../../config"

QtObject {
    id: root

    property list<string> lyrics: []
    property var times: []
    property int backend: hasLyrics ? 1 : 0
    property int preferredBackend: GlobalConfig.services.lyricsBackend
    onPreferredBackendChanged: {
        if (GlobalConfig.services.lyricsBackend !== preferredBackend)
            GlobalConfig.services.lyricsBackend = preferredBackend;
    }
    property var lyricCandidates: hasLyrics ? [selectedCandidate] : []
    property var selectedCandidate: ({ title: trackTitle, artist: trackArtist, album: trackAlbum, id: lyricFile.path })
    property bool loading: false
    readonly property bool hasLyrics: lyrics.length > 0
    property real offset: 0
    property string trackArtist: ""
    property string trackTitle: ""
    property string trackAlbum: ""

    function safePart(value: string): string {
        return value.replace(/[\\/:*?"<>|]/g, "_").trim();
    }

    function setTrack(artist: string, title: string, album = "", duration = 0): void {
        if (artist === trackArtist && title === trackTitle && album === trackAlbum)
            return;
        trackArtist = artist;
        trackTitle = title;
        trackAlbum = album;
        lyrics = [];
        times = [];
        if (!artist && !title)
            return;
        loading = true;
        lyricFile.path = `${GlobalConfig.paths.lyricsDir}/${safePart(artist)} - ${safePart(title)}.lrc`;
        lyricFile.reload();
    }

    function clearTrack(): void {
        trackArtist = "";
        trackTitle = "";
        trackAlbum = "";
        lyrics = [];
        times = [];
        loading = false;
    }

    function refresh(): void {
        if (lyricFile.path)
            lyricFile.reload();
    }

    function parse(text: string): void {
        const rows = [];
        for (const line of text.split("\n")) {
            const match = line.match(/\[(\d+):(\d+(?:\.\d+)?)\](.*)$/);
            if (!match)
                continue;
            rows.push({ time: Number(match[1]) * 60 + Number(match[2]), text: match[3].trim() });
        }
        rows.sort((left, right) => left.time - right.time);
        times = rows.map(row => row.time);
        lyrics = rows.map(row => row.text);
        loading = false;
    }

    function indexForTime(time: real): int {
        const adjusted = time + offset / 1000;
        let index = -1;
        for (let current = 0; current < times.length; current++) {
            if (times[current] > adjusted)
                break;
            index = current;
        }
        return Math.max(0, index);
    }

    function timeForIndex(index: int): real {
        return index >= 0 && index < times.length ? times[index] - offset / 1000 : 0;
    }

    property FileView lyricFile: FileView {
        printErrors: false
        onLoaded: root.parse(text())
        onLoadFailed: {
            root.lyrics = [];
            root.times = [];
            root.loading = false;
        }
    }
}
