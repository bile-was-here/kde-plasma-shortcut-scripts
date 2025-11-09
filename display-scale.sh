#!/bin/bash
# ============================================================================
# KDE Plasma Display Scale Control
# ============================================================================
# Version: 0.1
# AUTHOR: bile
# Last Updated: 2025-11-09
# Tested on: CachyOS, KDE Plasma 6.5.2
#
# Description:
#   Display scaling control script for KDE Plasma.
#
# Features:
#   - Automatic display detection
#   - Bounded scaling (1.0 to 3.0)
#   - Uses official KDE kscreen-doctor utility
#
# Installation:
#   1. Copy this script to a location:
#      cp display-scale.sh ~/path/to/display-scale.sh
#      chmod +x ~/path/to/display-scale.sh
#
#   2. Configure KDE keyboard shortcuts
#      (System Settings > Keyboard > Shortcuts > Add new > Command or Script)
#      Create two custom commands:
#
#      → name               → command
#      - display scale up   → /path/to/display-scale.sh up
#      → example keybind
#      - Meta+Ctrl+Alt++
#
#      → name               → command
#      - display scale down → /path/to/display-scale.sh down
#      → example keybind
#      - Meta+Ctrl+Alt+-
#
# Console usage:
#   display-scale.sh [action]
#
#   Actions:
#     up    - Increase scale by 0.25 (max 3.0)
#     down  - Decrease scale by 0.25 (min 1.0)
#
#   Examples:
#     display-scale.sh up
#     display-scale.sh down
#
# Dependencies:
#   - bash (3.x or newer)
#   - kscreen-doctor (KDE display management tool)
#   - bc (arbitrary precision calculator)
#   - sed (stream editor)
#
# Troubleshooting:
#   - If script doesn't work, verify kscreen-doctor is installed:
#     which kscreen-doctor
#   - Check your display info: kscreen-doctor -o
#   - For multiple monitors, script uses first enabled output
#
# Notes:
#   - Scale changes apply immediately to all UI elements
#   - Scale increments: 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0
#   - Works with Wayland and X11
#
# TODO: ???
#
# ============================================================================

if [ -z "$1" ]; then
    echo "Usage: $0 [up|down]"
    exit 1
fi

kscreen_output=$(kscreen-doctor -o | sed 's/\x1b\[[0-9;]*m//g')

output=$(echo "$kscreen_output" | grep "Output:" | head -1 | awk '{print $3}')

current=$(echo "$kscreen_output" | grep "Scale:" | awk '{print $2}')
current=${current:-1.0}

case "$1" in
    up)
        new=$(echo "$current + 0.25" | bc)
        [ "$(echo "$new > 3" | bc)" -eq 1 ] && new=3
        ;;
    down)
        new=$(echo "$current - 0.25" | bc)
        [ "$(echo "$new < 1" | bc)" -eq 1 ] && new=1
        ;;
    *)
        echo "Invalid argument. Use 'up' or 'down'"
        exit 1
        ;;
esac

kscreen-doctor output.${output}.scale.${new}
