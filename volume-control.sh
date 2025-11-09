#!/bin/bash
# ============================================================================
# KDE Plasma Volume Control
# ============================================================================
# Version: 0.1
# AUTHOR: bile
# Last Updated: 2025-11-09
# Tested on: CachyOS, KDE Plasma 6.5.2, PipeWire
#
# Description:
#   Volume control script with smooth fading, auto-unmute logic,
#   and notifications. Supports volumes >100% for amplification.
#
# Features:
#   - Smooth volume fading for large changes (ease-out curve)
#   - True percentage control up to 200%
#   - Safe for rapid key presses (lock file prevents conflicts)
#   - Notifications
#   - High volume warnings at configurable thresholds (dont blow your speakers, or your ears)
#
# Installation:
#   1. Copy this script to a location:
#      cp volume-control.sh ~/path/to/volume-control.sh
#      chmod +x ~/path/to/volume-control.sh
#
#   2. Find your audio sink name (optional, script uses default - verify this):
#      pactl list sinks | grep "Name:"
#      Update DEFAULT_SINK variable below
#
#   3. Configure KDE keyboard shortcuts
#      (System Settings > Keyboard > Shortcuts > Add new > Command or Script)
#      Create three custom commands:
#
#      → name         → command
#      - volume up    → /path/to/volume-control.sh up
#      → example keybind
#      - Meta+Ctrl++
#
#      → name         → command
#      - volume down  → /path/to/volume-control.sh down
#      → example keybind
#      - Meta+Ctrl+-
#
#      → name         → command
#      - volume mute  → /path/to/volume-control.sh mute
#      → example keybind
#      - Meta+Ctrl+0
#
# Console usage:
#   volume-control.sh [action] [optional-sink-name]
#
#   Actions:
#     up    - Increase volume by STEP amount
#     down  - Decrease volume by STEP amount
#     mute  - Toggle mute
#
#   Examples:
#     volume-control.sh up
#     volume-control.sh down
#     volume-control.sh mute
#
# Dependencies:
#   - bash (3.x or newer)
#   - pactl (PulseAudio/PipeWire command line tools)
#   - bc (arbitrary precision calculator)
#   - notify-send (libnotify)
#   - qdbus (KDE D-Bus interface)
#
# Troubleshooting:
#   - If script doesn't work, verify your sink name with: pactl list sinks | grep "Name:"
#
# TODO:
# verify default actually is what users default is set to - analog-stero/hdmi-stereo etc
#
# Per-application volume control
# Usage examples:
#   ./volume-control.sh app-up helium
#   ./volume-control.sh app-down spotify
#   ./volume-control.sh app-mute discord
#  notify-send cleanup
#
# ============================================================================

# Your audio device name
DEFAULT_SINK="alsa_output.pci-0000_2f_00.4.analog-stereo"
# Volume change per button press (percentage points)
STEP=10
# Maximum allowed volume (200% = 2x amplification)
MAX_VOL=200
# Volume changes >= this amount will fade smoothly instead of jumping instantly (percentage)
FADE_THRESHOLD=20
# Number of steps used during fade animation (more = smoother but slower)
FADE_STEPS=10
# Update on-screen display every X% during fade (lower = more updates, higher = less visual spam)
OSD_STEP=3
# Base fade duration in seconds (scales with volume change size)
BASE_FADE_DURATION=0.2
# Don't fade if calculated duration would be less than this (too fast to notice)
MIN_FADE_DURATION=0.05
# Lock file prevents multiple script instances from conflicting
LOCK_FILE="/tmp/volume_control.lock"
# How long notifications stay visible (milliseconds)
NOTIFICATION_TIMEOUT=600
# Warn user when volume reaches this threshold (percentage)
HIGH_VOLUME_THRESHOLD=120

ACTION="$1"
SINK="${2:-$DEFAULT_SINK}"

PREV_VOL_FILE="$HOME/.volume_prev_$(basename $SINK)"

trap "rm -f $LOCK_FILE" EXIT

(
    flock -n 9 || exit 0

    if ! command -v bc &>/dev/null; then
        notify-send -t "$NOTIFICATION_TIMEOUT" "❌ Missing Dependency" "Install 'bc' package for smooth volume fading"
        exit 1
    fi

    if ! pactl get-sink-volume "$SINK" &>/dev/null; then
        notify-send -t "$NOTIFICATION_TIMEOUT" "❌ Audio Error" "Sink $SINK not found"
        exit 1
    fi

    CURRENT_VOL=$(pactl get-sink-volume "$SINK" | grep -o '[0-9]*%' | head -1 | tr -d '%')
    MUTE_STATE=$(pactl get-sink-mute "$SINK" | awk '{print $2}')

    if [ -z "$CURRENT_VOL" ]; then
        notify-send -t "$NOTIFICATION_TIMEOUT" "❌ Parse Error" "Couldn't read current volume"
        exit 1
    fi

    update_ui() {
        local TITLE="$1"
        local BODY="$2"
        local VOL="$3"
        notify-send -t "$NOTIFICATION_TIMEOUT" "$TITLE" "$BODY"
        qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolume 0 "$VOL"
    }

    fade_volume() {
        local TARGET="$1"
        local START="$2"
        local SUPPRESS_NOTIFY="$3"
        local DIFF=$((TARGET-START))
        local ABS_DIFF=${DIFF#-}

        [ "$ABS_DIFF" -lt "$FADE_THRESHOLD" ] && {
            pactl set-sink-volume "$SINK" "${TARGET}%"
            update_ui "🔊 Volume" "Set to ${TARGET}%" "$TARGET"
            return
        }

        local FADE_DURATION=$(echo "scale=3; $BASE_FADE_DURATION * ($ABS_DIFF / 100)" | bc)
        FADE_DURATION=$(echo "if ($FADE_DURATION < 0.1) 0.1 else if ($FADE_DURATION > 0.5) 0.5 else $FADE_DURATION" | bc)

        if [ $(echo "$FADE_DURATION < $MIN_FADE_DURATION" | bc) -eq 1 ]; then
            pactl set-sink-volume "$SINK" "${TARGET}%"
            update_ui "🔊 Volume" "Set to ${TARGET}%" "$TARGET"
            return
        fi

        local FADE_DELAY=$(echo "scale=3; $FADE_DURATION / $FADE_STEPS" | bc)
        local LAST_OSD=$START

        for ((i=1; i<=FADE_STEPS; i++)); do
            local PROGRESS=$(echo "scale=4; $i / $FADE_STEPS" | bc)
            local EASED=$(echo "scale=4; 1 - (1 - $PROGRESS) * (1 - $PROGRESS)" | bc)
            local VOL=$(printf "%.0f" $(echo "$START + ($DIFF * $EASED)" | bc))

            [ "$VOL" -gt "$MAX_VOL" ] && VOL=$MAX_VOL
            [ "$VOL" -lt 0 ] && VOL=0

            pactl set-sink-volume "$SINK" "${VOL}%"

            local OSD_DIFF=$((VOL-LAST_OSD))
            local ABS_OSD_DIFF=${OSD_DIFF#-}
            if [ "$ABS_OSD_DIFF" -ge "$OSD_STEP" ]; then
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolume 0 "$VOL"
                LAST_OSD=$VOL
            fi

            sleep "$FADE_DELAY"
        done

        pactl set-sink-volume "$SINK" "${TARGET}%"
        if [ "$START" -ne "$TARGET" ] && [ "$SUPPRESS_NOTIFY" != "suppress" ]; then
            update_ui "🔊 Volume" "Set to ${TARGET}%" "$TARGET"
        fi
    }

    case "$ACTION" in
        up)
            MANUALLY_UNMUTED=false
            if [ "$MUTE_STATE" = "yes" ]; then
                pactl set-sink-mute "$SINK" 0
                MANUALLY_UNMUTED=true
            fi

            NEW_VOL=$((CURRENT_VOL+STEP))
            [ "$NEW_VOL" -gt "$MAX_VOL" ] && NEW_VOL=$MAX_VOL

            if [ "$NEW_VOL" -ge "$HIGH_VOLUME_THRESHOLD" ] && [ "$CURRENT_VOL" -lt "$HIGH_VOLUME_THRESHOLD" ]; then
                notify-send -t "$NOTIFICATION_TIMEOUT" "⚠️ High Volume" "Approaching ${NEW_VOL}%"
                fade_volume "$NEW_VOL" "$CURRENT_VOL" "suppress"
            else
                fade_volume "$NEW_VOL" "$CURRENT_VOL"
            fi
            [ "$NEW_VOL" -eq "$MAX_VOL" ] && notify-send -t "$NOTIFICATION_TIMEOUT" "⚠️ Max Volume" "Be careful! ${NEW_VOL}%"
            ;;

        down)
            MANUALLY_UNMUTED=false
            if [ "$MUTE_STATE" = "yes" ]; then
                pactl set-sink-mute "$SINK" 0
                MANUALLY_UNMUTED=true
            fi

            NEW_VOL=$((CURRENT_VOL-STEP))
            [ "$NEW_VOL" -lt 0 ] && NEW_VOL=0
            fade_volume "$NEW_VOL" "$CURRENT_VOL"
            if [ "$NEW_VOL" -eq 0 ] && [ "$MANUALLY_UNMUTED" = false ]; then
                pactl set-sink-mute "$SINK" 1
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolumeMute 0 true
            fi
            ;;

        mute)
            if [ "$MUTE_STATE" = "yes" ]; then
                PREV_VOL=$(cat "$PREV_VOL_FILE" 2>/dev/null || echo 50)
                pactl set-sink-volume "$SINK" "${PREV_VOL}%"
                pactl set-sink-mute "$SINK" 0
                notify-send -t "$NOTIFICATION_TIMEOUT" "🔈 Unmuted" "Restored to ${PREV_VOL}%"
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolumeMute 0 false
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolume 0 "$PREV_VOL"
            else
                if ! echo "$CURRENT_VOL" > "$PREV_VOL_FILE" 2>/dev/null; then
                    notify-send -t "$NOTIFICATION_TIMEOUT" "⚠️ Warning" "Couldn't save volume state"
                fi
                pactl set-sink-mute "$SINK" 1
                notify-send -t "$NOTIFICATION_TIMEOUT" "🔇 Muted" "Audio output disabled"
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolumeMute 0 true
                qdbus org.kde.kded6 /modules/kosd org.kde.kosd.showVolume 0 0
            fi
            ;;

        *)
            echo "Usage: $0 [up|down|mute] [optional-sink-name]"
            echo "       $0 [app-up|app-down|app-mute] [optional-sink-name] [app-name]"
            exit 1
            ;;
    esac

) 9>"$LOCK_FILE"
