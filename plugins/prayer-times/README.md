# Prayer Times

Local prayer times, Hijri dates, Islamic holidays and Qibla for the Ryoku QS Bar.

![Bar widget](assets/preview-widget.png)

![Panel](assets/preview-panel.png)

## What it does

- Shows the next prayer and a live countdown in the bar.
- Opens a panel with today's six prayer times, a progress ring, night times and Qibla.
- Includes seven-day and whole-month tables, Umm al-Qura Hijri dates and Islamic holidays.
- Provides a Node CLI and a Waybar module example.

## Install

```sh
ryoku plugin add <git-url> --bar --yes
```

## Settings

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `city` | choice | `auto` | Preset city, or `auto` to detect from the system timezone. |
| `latitude` | text | `""` | Latitude override; empty uses the city. |
| `longitude` | text | `""` | Longitude override; empty uses the city. |
| `method` | choice | `auto` | Calculation method; `auto` uses the city's method. |
| `asr` | choice | `standard` | Standard or Hanafi Asr calculation. |
| `highLat` | choice | `none` | High-latitude adjustment: `none`, `middle`, `seventh` or `angle`. |
| `offsetFajr` | int | `0` | Fajr adjustment in minutes, from -30 to 30. |
| `offsetSunrise` | int | `0` | Sunrise adjustment in minutes, from -30 to 30. |
| `offsetDhuhr` | int | `0` | Dhuhr adjustment in minutes, from -30 to 30. |
| `offsetAsr` | int | `0` | Asr adjustment in minutes, from -30 to 30. |
| `offsetMaghrib` | int | `0` | Maghrib adjustment in minutes, from -30 to 30. |
| `offsetIsha` | int | `0` | Isha adjustment in minutes, from -30 to 30. |
| `display` | choice | `full` | Bar content: `full`, `time` or `name`. |
| `clock24` | toggle | `true` | Use a 24-hour clock instead of AM/PM. |
| `hijriAdjust` | int | `0` | Shift the Hijri date by -1, 0 or 1 day. |

## Offline and private

Everything is computed locally. The only external command is `readlink -f /etc/localtime`, used once to guess the city; there is no network, ever. The plugin reads only its settings and that timezone link, writes no files, and requests no privileged capabilities.

## Credits

- Prayer algorithm: PrayTimes.org.
- Umm al-Qura table: dralshehri/hijri-converter, MIT.
- City coordinates: OpenStreetMap.

## Licence

MIT
