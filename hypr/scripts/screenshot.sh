#!/bin/sh
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

if [ "$1" = full ]; then
    grim -o "$(hyprctl activeworkspace -j | jq -r .monitor)" "$file"
else
    geom=$(slurp) || exit 0
    grim -g "$geom" "$file"
fi || exit 1

wl-copy --type image/png < "$file"
notify-send -i "$file" "Screenshot" "$file"
