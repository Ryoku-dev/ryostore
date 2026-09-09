# livewalls

Curated live (video) wallpapers for the Ryoku desktop. They show up in ryowalls
under the **Ryoku** source, download into `~/Pictures/livewalls`, and play through
mpvpaper like any other live wallpaper.

`registry.json` lists every wallpaper. The poster lives in this repo; the video
is a **GitHub Release asset** (kept out of git so the repo stays lean).

## Add a wallpaper

1. Prepare a seamless-looping clip (mp4 or webm, 1080p is plenty, no audio) and a
   poster still (jpg). Keep the clip small: a short loop at a sane bitrate.
2. Put the poster at `livewalls/<id>/poster.jpg`.
3. Upload the video to the `livewalls` release:
   ```sh
   gh release upload livewalls <id>.mp4 --clobber
   ```
4. Add an entry to `registry.json`:
   ```json
   {
     "id": "<id>",
     "name": "Display Name",
     "author": "you",
     "poster": "livewalls/<id>/poster.jpg",
     "video": "https://github.com/ryoku-dev/ryostore/releases/download/livewalls/<id>.mp4",
     "tags": ["anime", "abstract"]
   }
   ```
5. Commit the poster + registry and push.

Only ship clips you have the right to redistribute (your own, CC0, or explicitly
licensed). This catalogue is the licensing-clean alternative to scraping.
