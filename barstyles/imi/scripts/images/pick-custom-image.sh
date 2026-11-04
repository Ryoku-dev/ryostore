#!/bin/sh

# Helper for ImageService.qml: lets you choose a picture for the Custom Image
# widget with a normal file chooser, and keeps a copy of it.
#
#   pick-custom-image.sh pick           open a file chooser; the chosen picture is
#                                       copied into the data folder and its new
#                                       path is printed (nothing if cancelled)
#   pick-custom-image.sh import <file>  the same, for a file you already have
#                                       (qs -c imi ipc call image addPath <file>)
#   pick-custom-image.sh remove <path>  delete one copy (only ever inside the
#                                       data folder below; anything else is left alone)
#
# The copies live in ${XDG_DATA_HOME:-~/.local/share}/imi/custom-images/
# (copied, so moving or deleting the original doesn't break the desktop). The
# bytes are NOT re-encoded or shrunk: a GIF (or an animated WebP / APNG) has to
# arrive exactly as it is or it stops moving. The widget decodes a big still
# picture at the size it needs, so there is nothing to gain from shrinking here.
# Each copy gets its own name, img-<time>-<pid>.<ext>, so a picture that is
# replaced is really reloaded instead of coming out of Qt's cache.
#
# The chooser is the first of kdialog, zenity or yad that is installed;
# IMI_CHOOSER (Settings -> General -> Quick Panel -> picker) is tried first.

mode="$1"
dir="${XDG_DATA_HOME:-$HOME/.local/share}/imi/custom-images"
exts="png jpg jpeg webp gif apng bmp svg"

# Copies <file> into the data folder; prints the new path. 1 = not a picture we show.
store() {
    f="$1"
    [ -f "$f" ] || return 1
    ext="${f##*.}"
    ext=$(printf '%s' "$ext" | tr 'A-Z' 'a-z')
    ok=""
    for e in $exts; do
        [ "$e" = "$ext" ] && ok=1
    done
    [ -n "$ok" ] || { echo "not a picture type this widget shows: .$ext" >&2; return 1; }
    mkdir -p "$dir" || return 1
    new="$dir/img-$(date +%s)-$$.$ext"
    cp -- "$f" "$new" || return 1
    printf '%s\n' "$new"
}

case "$mode" in
    import)
        store "$2" || exit 1
        exit 0
        ;;
    remove)
        case "$2" in
            "$dir"/img-*) rm -f -- "$2" ;;
        esac
        exit 0
        ;;
    pick) ;;
    *) echo "usage: $0 pick|import <file>|remove <path>" >&2; exit 2 ;;
esac

title="Choose a picture"

# Start in the Pictures folder if there is one.
start=$(xdg-user-dir PICTURES 2>/dev/null)
[ -d "$start" ] || start="$HOME/Pictures"
[ -d "$start" ] || start="$HOME"

# "*.png *.PNG *.jpg ..." — the choosers match case-sensitively.
patterns=""
for e in $exts; do
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
            --file-filter="Pictures | $patterns" 2>/dev/null)
        ;;
    kdialog)
        f=$(kdialog --title "$title" --getopenfilename "$start" "$patterns|Pictures" 2>/dev/null)
        ;;
    yad)
        f=$(yad --file --title="$title" --filename="$start/" \
            --file-filter="Pictures | $patterns" 2>/dev/null)
        ;;
    *)
        echo "no file chooser found: install zenity (or kdialog / yad)" >&2
        exit 127
        ;;
esac

# Cancelled, or nothing usable picked.
[ -n "$f" ] && [ -f "$f" ] || exit 1
store "$f" || exit 1
