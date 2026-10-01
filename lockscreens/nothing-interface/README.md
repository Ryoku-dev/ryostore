# Nothing Interface lockscreen

A live Ryoku lockscreen with dot clock, date, battery, daily screen time and
MPRIS media controls. In a locked desktop session it displays the current
Ryogami wallpaper and follows wallpaper changes. It does not install its own
wallpaper. The system login greeter uses a charcoal fallback and cannot show
the session's live data.

The QML and Python helpers are original MIT-licensed code by Ivan. Python 3 and
`playerctl` are used for live media data; the helpers read local power-supply
state and Ryoku's screen-time state. They write no files, make no outbound
network requests, and require no privileged commands. The image URL provided by
a local media player may be fetched by Qt when the lockscreen shows album art.

The catalogue preview is not installed. No Nothing artwork or font is bundled.
See [PROVENANCE.txt](PROVENANCE.txt) and the
[upstream project](https://github.com/venchik111/ryoku-nothing-interface).
Maintainer: [venchik111](https://github.com/venchik111).
