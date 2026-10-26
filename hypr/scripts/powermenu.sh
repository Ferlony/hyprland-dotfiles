#!/bin/sh
choice=$(printf '%s\n' "Log out" "Lock" "Reboot" "Suspend" "Power off" \
    | rofi -dmenu -i -p "Power" -no-custom) || exit 0

quit() { 
    if command -v hyprshutdown >/dev/null; then
        if [ -n "$2" ]; then hyprshutdown -t "$1" --post-cmd "$2"; else hyprshutdown -t "$1"; fi
    elif [ -n "$2" ]; then
        sh -c "$2"
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

case "$choice" in
    "Log out")   quit 'Logging out...' '' ;;
    "Lock")      loginctl lock-session ;;
    "Reboot")    quit 'Restarting...' 'systemctl reboot' ;;
    "Suspend")   systemctl suspend ;;
    "Power off") quit 'Shutting down...' 'systemctl poweroff' ;;
esac
