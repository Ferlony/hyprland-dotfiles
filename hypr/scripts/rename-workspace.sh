#!/bin/sh
# lain.util.rename_tag (SUPER+SHIFT+R)
name=$(rofi -dmenu -p "Rename tag" -l 0 </dev/null) || exit 0
[ -n "$name" ] || exit 0
id=$(hyprctl activeworkspace -j | jq -r .id)
name=$(printf '%s' "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
hyprctl dispatch "hl.dsp.workspace.rename({ workspace = \"$id\", name = \"$name\" })"
