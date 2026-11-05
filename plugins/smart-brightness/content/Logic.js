// Media / fullscreen detection ported from SweetPotato smart-brightness-lib.py
// (itself from fullscreen-maxbright). Kept in sync with those class and title
// lists: compositor fullscreen alone is not enough — the focused window must
// also look like a media player or a media page title.

.pragma library

var MEDIA_WINDOW_CLASSES = [
    "vlc", "mpv", "celluloid", "totem", "smplayer", "gnome-mpv", "parole",
    "dragon", "kaffeine", "xine", "mplayer", "audacious", "clementine",
    "rhythmbox", "stremio", "jellyfin", "jellyfin-media-player", "fladder",
    "plex", "plexhometheater", "kodi", "osmc", "libreelec", "firefox",
    "chrome", "chromium", "brave", "zen", "waterfox", "librewolf", "floorp"
];

var VIDEO_TITLE_KEYWORDS = [
    "youtube", "vimeo", "netflix", "prime video", "disney", "hulu", "twitch",
    "video", "media", "vlc", "mpv", "watch", "play", "movie", "film",
    "stremio", "jellyfin", "plex", "kodi", "emby", "plexamp", "spotify",
    "tidal", "soundcloud", "bandcamp"
];

function shouldActivate(isFullscreen, windowClass, windowTitle) {
    if (!isFullscreen)
        return false;
    var cls = String(windowClass || "").toLowerCase();
    var title = String(windowTitle || "").toLowerCase();
    var i;
    for (i = 0; i < MEDIA_WINDOW_CLASSES.length; i++) {
        if (cls.indexOf(MEDIA_WINDOW_CLASSES[i]) >= 0)
            return true;
    }
    for (i = 0; i < VIDEO_TITLE_KEYWORDS.length; i++) {
        if (title.indexOf(VIDEO_TITLE_KEYWORDS[i]) >= 0)
            return true;
    }
    return false;
}

function statusLabel(enabled, videoActive) {
    if (!enabled)
        return "off";
    if (videoActive)
        return "video";
    return "on";
}
