#!/bin/sh
hyprctl binds -j | jq -r '
  def bit($n): (.modmask / $n | floor) % 2 == 1;
  def mods: [ (if bit(64) then "Super" else empty end),
              (if bit(4)  then "Ctrl"  else empty end),
              (if bit(8)  then "Alt"   else empty end),
              (if bit(1)  then "Shift" else empty end) ];
  def key: if .key != "" then .key
           elif .keycode >= 10 and .keycode <= 18 then (.keycode - 9 | tostring)
           else "code:\(.keycode)" end;
  .[] | select(.has_description)
      | (.description | split(": ")) as $d
      | "\($d[0])\t\((mods + [key]) | join("+"))\t\($d[1:] | join(": "))"
' | sort -s -t "$(printf '\t')" -k1,1 | column -t -s "$(printf '\t')" \
  | rofi -dmenu -i -p "Hotkeys" -no-custom >/dev/null
