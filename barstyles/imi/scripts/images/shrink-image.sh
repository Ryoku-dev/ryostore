#!/bin/sh

# Helper for pick-image.sh and scripts/state/preset-state.sh: puts a picture at
# <dst>, scaled down on the way if it is far bigger than the avatar or banner
# can ever show.
#
#   shrink-image.sh avatar|banner <src> <dst>
#
# Why: a 24-megapixel photo costs the shell a lot to decode, and the same file
# is decoded again for every place that shows it (the Quick Panel's banner and
# avatar, and the desktop user card's, per monitor). A PNG or WebP has to be
# decoded in full before Qt can scale it, whatever `sourceSize` says, so the
# shell would stall for a moment and eat a few hundred MB after every pick.
# Scaling once, here, at low priority, in its own process, is much cheaper.
#
# How much: the picture is scaled so it still COVERS the box below (the slots
# crop with PreserveAspectCrop, so what matters is that the cropped part keeps
# its detail), keeping its proportions. Only when it is bigger than the box in
# both directions; anything smaller is copied byte for byte (no re-encode, no
# loss). The boxes hold the largest slot at 2x for hidpi, plus some room.
#
#   avatar  800 x 800        banner  2000 x 800
#
# Not touched, just copied: svg (resolution independent) and gif (may be
# animated). JPEG orientation (EXIF) is applied when it is scaled.
#
# Tools: ImageMagick (magick / convert), else ffmpeg + ffprobe. With none of
# them, or if scaling fails for any reason, the picture is simply copied as it
# is: picking never fails because of this. Exits 0 once <dst> exists.

kind="$1"
src="$2"
dst="$3"

case "$kind" in
    avatar) maxw=800; maxh=800 ;;
    banner) maxw=2000; maxh=800 ;;
    *) echo "usage: $0 avatar|banner <src> <dst>" >&2; exit 2 ;;
esac
[ -f "$src" ] && [ -n "$dst" ] || exit 2

have() { command -v "$1" >/dev/null 2>&1; }

plain() {
    cp -- "$src" "$dst"
    exit $?
}

# Low CPU and disk priority: a big picture must not make the desktop stutter.
low() {
    if have ionice; then
        nice -n 19 ionice -c 3 "$@"
    else
        nice -n 19 "$@"
    fi
}

ext=$(printf '%s' "${dst##*.}" | tr 'A-Z' 'a-z')
case "$ext" in
    svg|gif) plain ;;
esac

# Width and height of the picture (its first frame), or nothing if unknown.
tool=""
dims=""
if have magick; then
    tool=magick
    dims=$(magick identify -ping -format '%w %h' "$src[0]" 2>/dev/null)
elif have convert && have identify; then
    tool=convert
    dims=$(identify -ping -format '%w %h' "$src[0]" 2>/dev/null)
elif have ffmpeg && have ffprobe; then
    tool=ffmpeg
    dims=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0 "$src" 2>/dev/null | head -n 1 | tr ',' ' ')
fi

# Not understood, or not bigger than the box both ways: leave it alone.
set -- $dims
w="$1"
h="$2"
case "$w$h" in
    ''|*[!0-9]*) plain ;;
esac
{ [ "$w" -gt "$maxw" ] && [ "$h" -gt "$maxh" ]; } || plain

tmp="$dst.tmp.$ext"
rm -f "$tmp"

case "$tool" in
    magick|convert)
        q=""
        case "$ext" in
            jpg|jpeg|webp) q="-quality 90" ;;
        esac
        # shellcheck disable=SC2086
        low $tool "$src[0]" -auto-orient -resize "${maxw}x${maxh}^" $q "$tmp" 2>/dev/null
        ;;
    ffmpeg)
        q=""
        case "$ext" in
            jpg|jpeg) q="-q:v 2" ;;
        esac
        # scale = the larger of maxw/iw and maxh/ih (< 1 here); -2 keeps the
        # height even and the proportions.
        # shellcheck disable=SC2086
        low ffmpeg -v error -y -i "$src" -frames:v 1 -update 1 \
            -vf "scale=trunc(iw*max($maxw/iw\,$maxh/ih)/2)*2:-2" $q "$tmp" 2>/dev/null
        ;;
esac

if [ -s "$tmp" ]; then
    mv -- "$tmp" "$dst"
    exit $?
fi
rm -f "$tmp"
plain