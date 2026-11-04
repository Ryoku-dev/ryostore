#!/bin/sh

# Helper for PanelImages.qml: lets you pick the Quick Panel's avatar and
# banner pictures with a normal file chooser, and keeps them.
#
#   pick-image.sh pick  avatar|banner   open a file chooser; the chosen
#                                       picture is copied into the data
#                                       folder and its path is printed
#   pick-image.sh load                  print "<kind> <path>" for each
#                                       picture already picked
#   pick-image.sh clear avatar|banner   forget one (back to the default)
#
# The pictures live in ${XDG_DATA_HOME:-~/.local/share}/imi/ (copied,
# so moving or deleting the original doesn't break the panel). Each pick
# gets a fresh file name — avatar-<time>.<ext> — so the image is really
# reloaded instead of the old one coming out of a cache.
#
# The chooser is the first of kdialog, zenity or yad that's installed. kdialog
# comes first because it opens its own window at once; GTK4 zenity goes through
# the desktop portal, which can take seconds to wake up. Settings > General >
# Quick Panel > "Avatar & banner picker" sets IMI_CHOOSER (kdialog, zenity
# or yad) to try one of them first; "Auto" leaves it unset. A chooser that is
# not installed is skipped, so a wrong choice never leaves you without one.
#
# A picture much bigger than the avatar / banner can show is scaled down while
# it is copied (shrink-image.sh), so the shell doesn't have to decode a huge
# photo several times over right after you pick it.

mode="$1"
kind="$2"
dir="${XDG_DATA_HOME:-$HOME/.local/share}/imi"
here=$(cd "$(dirname "$0")" && pwd)

case "$kind" in
    avatar|banner|"") ;;
    *) echo "unknown kind: $kind" >&2; exit 2 ;;
esac

case "$mode" in
    load)
        for k in avatar banner; do
            f=$(ls -1t "$dir/$k"-* 2>/dev/null | head -n 1)
            [ -n "$f" ] && printf '%s %s\n' "$k" "$f"
        done
        exit 0
        ;;
    clear)
        [ -n "$kind" ] && rm -f -- "$dir/$kind"-*
        exit 0
        ;;
    pick) ;;
    *) echo "usage: $0 pick|load|clear [avatar|banner]" >&2; exit 2 ;;
esac

[ -n "$kind" ] || exit 2

if [ "$kind" = avatar ]; then
    title="Choose your avatar"
else
    title="Choose your banner"
fi

# Start in the Pictures folder if there is one.
start=$(xdg-user-dir PICTURES 2>/dev/null)
[ -d "$start" ] || start="$HOME/Pictures"
[ -d "$start" ] || start="$HOME"

# "*.png *.PNG *.jpg ..." — the choosers match case-sensitively.
patterns=""
for e in png jpg jpeg webp gif bmp svg; do
    up=$(printf '%s' "$e" | tr 'a-z' 'A-Z')
    patterns="$patterns *.$e *.$up"
done
patterns="${patterns# }"

chooser=""
for c in ${IMI_CHOOSER:-} kdialog zenity yad; do
    case "$c" in
        zenity|kdialog|yad) ;;
        *) continue ;;
    esac
    if command -v "$c" >/dev/null 2>&1; then
        chooser="$c"
        break
    fi
done

case "$chooser" in
    zenity)
        f=$(zenity --file-selection --title="$title" --filename="$start/" \
            --file-filter="Images | $patterns" 2>/dev/null)
        ;;
    kdialog)
        f=$(kdialog --title "$title" --getopenfilename "$start" "$patterns|Images" 2>/dev/null)
        ;;
    yad)
        f=$(yad --file --title="$title" --filename="$start/" \
            --file-filter="Images | $patterns" 2>/dev/null)
        ;;
    *)
        echo "no file chooser found: install zenity (or kdialog / yad)" >&2
        exit 127
        ;;
esac

# Cancelled, or nothing usable picked.
[ -n "$f" ] && [ -f "$f" ] || exit 1

ext="${f##*.}"
ext=$(printf '%s' "$ext" | tr 'A-Z' 'a-z')
mkdir -p "$dir" || exit 1
new="$dir/$kind-$(date +%s).$ext"
sh "$here/shrink-image.sh" "$kind" "$f" "$new" || exit 1

# Drop the previous picture of this kind.
for old in "$dir/$kind"-*; do
    [ "$old" != "$new" ] && rm -f -- "$old"
done

printf '%s\n' "$new"
