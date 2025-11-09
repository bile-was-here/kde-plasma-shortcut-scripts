#!/bin/bash
# ============================================================================
# WALLPAPER CHANGER (wpc.sh)
# ============================================================================
# Version: 0.7
# AUTHOR: bile
# Last Updated: 2025-11-09
# Tested on: CachyOS, KDE Plasma 6.5.2
#
# DESCRIPTION:
# A script to download and set wallpapers from Wallhaven API or local folder
# full history navigation and favorites management with multi monitor support
#
# DEPENDENCIES:    curl, jq, wget, notify-send, file
# Desktop-specific:
# KDE Plasma:      plasma-apply-wallpaperimage, kwriteconfig6 (optional), qdbus/qdbus6 (optional)
# GNOME/Cinnamon:  gsettings
# XFCE:            xfconf-query
# MATE:            gsettings
# LXQt:            pcmanfm-qt
#
# DESKTOP SUPPORT:
# Single Monitor:  KDE Plasma, GNOME, Cinnamon, XFCE, MATE, LXQt
# Multi-Monitor:   KDE Plasma (native), XFCE (native)
# Multi-Monitor*:  GNOME, Cinnamon, MATE, LXQt (applies to all monitors)
#                  *These DEs don't support per-monitor wallpapers natively
#
# FEATURES:
# - Download wallpapers from Wallhaven API with filtering
# - Multi-monitor support (independent wallpapers & history per monitor)
# - Full history navigation (back/forward through wallpaper history)
# - Favorites management (copy wallpapers to favorites folder)
# - Local random wallpaper selection from favorites
# - Configurable search queries with include/exclude terms & quoted phrases
# - Category filtering (General, Anime, People - any combination)
# - Purity filtering (SFW, Sketchy, NSFW with API key)
# - Sorting options (random, relevance, date_added, views, favorites, toplist)
# - Resolution filtering (minimum resolution, exact resolutions)
# - Aspect ratio filtering (16x9, 21x9, etc.)
# - Color-based wallpaper search (hex color matching)
# - Top range filtering for toplist sorting (1d, 3d, 1w, 1M, 3M, 6M, 1y)
# - Automatic cleanup of old wallpapers (keep last N)
# - Desktop notifications with wallpaper preview thumbnails
# - Persistent configuration (save settings to script with --save)
# - Rate limiting and duplicate detection (avoids re-downloading)
# - History cleanup (remove dead/missing entries)
# - Order-independent command arguments (monitor can be anywhere)
# - Lock file mechanism (prevents concurrent runs)
# - Automatic pagination (moves to next page when current exhausted)
# - File validation (size, type, integrity checks)
# - Tag fetching for exclusion-only queries
# - Lockscreen wallpaper sync (KDE Plasma)
# - Per-monitor history files (independent navigation per display)
#
# USAGE:
#   ./wpc.sh                    # Use configuration values from script (all monitors)
#   ./wpc.sh [OPTIONS]          # Override configuration with command-line options
#   ./wpc.sh --save [OPTIONS]   # Save OPTIONS to script configuration permanently
#   ./wpc.sh m1                 # Set wallpaper on monitor 1
#   ./wpc.sh m2                 # Set wallpaper on monitor 2
#   ./wpc.sh m3                 # Set wallpaper on monitor 3
#   ./wpc.sh m1 back            # Go back to previous wallpaper on monitor 1
#   ./wpc.sh m2 forward         # Go forward to next wallpaper on monitor 2
#   ./wpc.sh m1 copy            # Copy current wallpaper from monitor 1 to favorites
#   ./wpc.sh m2 localrandom     # Set random wallpaper from favorites on monitor 2
#   ./wpc.sh back               # Go back to previous wallpaper (all monitors)
#   ./wpc.sh forward            # Go forward to next wallpaper (all monitors)
#   ./wpc.sh copy               # Copy current wallpaper to favorites folder
#   ./wpc.sh localrandom        # Set random wallpaper from USER_WALLPAPER_DIR
#   ./wpc.sh cleanup            # Remove dead entries from history
#   ./wpc.sh show-config        # Display current configuration
#
# MULTI-MONITOR COMMANDS:
#   m1, m2, m3, m4, etc.        Specify which monitor to change wallpaper on
#                               Example: ./wpc.sh m1 (changes monitor 1)
#                               Example: ./wpc.sh m2 -q "sunset" (monitor 2 with sunset query)
#
#   NOTES:
#   - Each monitor maintains its own independent wallpaper history
#   - History files are stored as ~/.cache/wpc_history_m1, wpc_history_m2, etc.
#   - When no monitor is specified, wallpaper applies to all monitors (default)
#   - KDE Plasma has native per-monitor wallpaper support
#   - GNOME/Cinnamon/MATE apply wallpaper to all monitors (no per-monitor support)
#   - XFCE supports per-monitor wallpapers
#
# OPTIONS:
#   -h, --help                  Show this help message
#   --save                      Save the provided options to script config (updates the file)
#   back                        Navigate to previous wallpaper in history
#   forward                     Navigate to next wallpaper in history
#   copy                        Copy current wallpaper to USER_WALLPAPER_DIR (favorites)
#   localrandom                 Set random wallpaper from USER_WALLPAPER_DIR (favorites)
#   cleanup                     Remove non-existent wallpapers from history
#   show-config                 Display current configuration values
#   -l, --local                 Use local wallpaper mode (ignores other options)
#   -d, --dir PATH              Local wallpaper directory (default: ~/Pictures/Wallpapers)
#   -q, --query "TEXT"          Search query (e.g., "abstract", "+sunset -city", "-'video games'")
#   -c, --categories XXX        Categories: 100=General, 010=Anime, 001=People
#   -p, --purity XXX            Purity: 100=SFW, 010=Sketchy, 001=NSFW
#   -k, --apikey KEY            Wallhaven API key (required for NSFW)
#   -s, --sorting METHOD        Sorting: date_added, relevance, random, views, favorites, toplist
#   -o, --order ORDER           Order: desc, asc (default: desc)
#   -t, --toprange RANGE        Top range (toplist only): 1d, 3d, 1w, 1M, 3M, 6M, 1y
#   -m, --minres WIDTHxHEIGHT   Minimum resolution (e.g., 1920x1080, 3840x2160)
#   -e, --exact RES1,RES2       Exact resolutions, comma-separated
#   -r, --ratios RATIO1,RATIO2  Aspect ratios, comma-separated (e.g., 16x9,21x9)
#   --color HEXCOLOR            Color filter (hex without #, e.g., 660000)
#   --keep N                    Keep last N wallpapers (0=keep all)
#   --timeout N                 API request timeout in seconds (default: 5)
#
# CONFIGURATION:
#   The script stores configuration directly in itself. Use --save to persist changes:
#     ./wpc.sh --save -q "nature" -m 1920x1080 --keep 50
#
#   View current settings:
#     ./wpc.sh show-config
#
#   Default values (before any customization):
#     MIN_RESOLUTION    = 3840x2160 (4K - change if you have lower resolution screen)
#     SEARCH_QUERY      = "-city -aircraft -vehicle -car -cars +abstract"
#     CATEGORIES        = 100 (General only)
#     PURITY            = 100 (SFW only)
#     KEEP_LAST         = 25 wallpapers
#     API_TIMEOUT       = 5 seconds
#     WALLPAPER_DIR     = ~/Pictures/wpc
#     USER_WALLPAPER_DIR = ~/Pictures/Wallpapers (for favorites)
#
# DIRECTORIES:
#   Downloads:  ~/Pictures/wpc
#   Favorites:  ~/Pictures/Wallpapers
#   Cache:      ~/.cache/wpc_state, ~/.cache/wpc_history, ~/.cache/wpc_current
#               Per-monitor: ~/.cache/wpc_history_m1, wpc_history_m2, etc.
#
# API KEY (for NSFW content):
#   Get your free API key: https://wallhaven.cc/settings/account
#   Save it permanently: ./wpc.sh --save -k YOUR_API_KEY_HERE
#   Or use temporarily: ./wpc.sh -k YOUR_API_KEY_HERE -p 001
#
# SEARCH QUERY SYNTAX:
#   Basic search:        ./wpc.sh -q "sunset"
#   Include term:        ./wpc.sh -q "+sunset"
#   Exclude term:        ./wpc.sh -q "-city"
#   Multiple terms:      ./wpc.sh -q "+sunset -city +nature"
#   Quoted phrases:      ./wpc.sh -q "-'video games' +abstract"
#   Exclusion-only:      ./wpc.sh -q "-city -car" (fetches tags from results)
#
# CATEGORIES & PURITY (3-digit bitmask):
#   Categories:
#     100 = General only
#     010 = Anime only
#     001 = People only
#     110 = General + Anime
#     111 = All categories
#
#   Purity:
#     100 = SFW only
#     110 = SFW + Sketchy
#     111 = All (requires API key)
#
# EXAMPLE KEYBINDS (KDE):
#
#   Single Monitor Setup:
#     System Settings > Keyboard > Shortcuts > Add New > Command or Script
#     Command: /path/to/wpc.sh
#                        → command
#     Meta+Ctrl+W        → /path/to/wpc.sh                # Next wallpaper (API)
#     Meta+Ctrl+Q        → /path/to/wpc.sh back           # Previous wallpaper
#     Meta+Ctrl+E        → /path/to/wpc.sh forward        # Forward in history
#     Meta+Ctrl+C        → /path/to/wpc.sh copy           # Copy to favorites
#     Meta+Ctrl+Shift+R  → /path/to/wpc.sh localrandom    # Random from favorites
#
#   Multi-Monitor Setup:
#     Meta+Ctrl+1        → /path/to/wpc.sh m1             # Change monitor 1 wallpaper
#     Meta+Ctrl+2        → /path/to/wpc.sh m2             # Change monitor 2 wallpaper
#     Meta+Ctrl+3        → /path/to/wpc.sh m3             # Change monitor 3 wallpaper
#     Meta+Ctrl+Shift+1  → /path/to/wpc.sh m1 back        # Monitor 1 previous
#     Meta+Ctrl+Shift+2  → /path/to/wpc.sh m1 forward     # Monitor 1 forward
#     Meta+Ctrl+C+1      → /path/to/wpc.sh m1 copy        # Copy monitor 1 to favorites
#     Meta+Ctrl+Shift+R  → /path/to/wpc.sh m1 localrandom # Monitor 1 random from favorites
#     Meta+Ctrl+Shift+3  → /path/to/wpc.sh m2 back        # Monitor 2 previous
#     Meta+Ctrl+Shift+4  → /path/to/wpc.sh m2 forward     # Monitor 2 forward
#     Meta+Ctrl+C+2      → /path/to/wpc.sh m2 copy        # Copy monitor 2 to favorites
#
# TROUBLESHOOTING:
#   Wallpaper doesn't change:
#     - Check if your desktop environment is supported: ./wpc.sh show-config
#     - For KDE: Ensure plasma-apply-wallpaperimage is installed
#     - Try manually: plasma-apply-wallpaperimage ~/Pictures/wpc/any_image.jpg
#
#   Multi-monitor not working:
#     - Check detected monitors: ./wpc.sh show-config
#     - KDE: plasma-apply-wallpaperimage supports per-monitor with -m flag
#     - XFCE: Per-monitor supported via xfconf-query
#     - GNOME/MATE: No native per-monitor support (applies to all)
#
#   "All wallpapers already exist" message:
#     - Script tracks downloaded wallpapers to avoid duplicates
#     - Will auto-advance to next page on next run
#     - To force new downloads: rm ~/.cache/wpc_state
#
#   Clear all cache and start fresh:
#     rm ~/.cache/wpc_*
#
#   Script seems to do nothing:
#     - Check rate limiting (2-second minimum between runs)
#     - View errors: ./wpc.sh 2>&1 | less
#
#   TODO for future me
#   TODO:  cleanup documentation
#   TODO:  function to browse and navigate through USER_WALLPAPER_DIR with keybind instead of only random choice
#   TODO:  when fav is added, add to a tagged dir in USER_WALLPAPER_DIR either based on color (if enabled) or initial tag/q +tag
#   TODO:  add history support ^
#   TODO:  fix other random obvious problems i've ignored (like lock screen, MM stuff and others)
#   TODO:  theming based on dominant COLOR= (DE specific)
#   TODO:  DE support: cosmic, hyprland, sway, niri
#
# ============================================================================

MIN_INTERVAL=2
MIN_FILE_SIZE=10000
TIMESTAMP_FILE="/tmp/wpc_last_run"
LOCK_STALE_THRESHOLD=30
FILENAME_MAX_LENGTH=50

if [[ "$1" != "back" && "$1" != "forward" && "$1" != "copy" && "$1" != "localrandom" && "$1" != "cleanup" && "$1" != "show-config" && ! "$1" =~ ^m[0-9]+$ ]]; then
    if [[ -f "$TIMESTAMP_FILE" ]]; then
        LAST_RUN=$(cat "$TIMESTAMP_FILE" 2>/dev/null || echo "0")
        CURRENT_TIME=$(date +%s)
        TIME_DIFF=$((CURRENT_TIME - LAST_RUN))

        if [[ $TIME_DIFF -lt $MIN_INTERVAL ]]; then
            exit 0
        fi
    fi

    date +%s > "$TIMESTAMP_FILE"
fi

LOCK_FILE="/tmp/wpc_lock_$$"
GLOBAL_LOCK="/tmp/wpc_global.lock"

cleanup_lock() {
    rm -f "$LOCK_FILE" 2>/dev/null
    if [[ -f "$GLOBAL_LOCK" ]]; then
        local lock_pid
        lock_pid=$(cat "$GLOBAL_LOCK" 2>/dev/null)
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$GLOBAL_LOCK" 2>/dev/null
        fi
    fi
}

if [[ -f "$GLOBAL_LOCK" ]]; then
    LOCK_PID=$(cat "$GLOBAL_LOCK" 2>/dev/null)

    if [[ -f "$GLOBAL_LOCK" ]]; then
        LOCK_TIME=$(stat -c %Y "$GLOBAL_LOCK" 2>/dev/null || stat -f %m "$GLOBAL_LOCK" 2>/dev/null || echo 0)
        LOCK_AGE=$(($(date +%s) - LOCK_TIME))
    else
        LOCK_AGE=0
    fi

    if [[ -n "$LOCK_PID" ]] && kill -0 "$LOCK_PID" 2>/dev/null && [[ $LOCK_AGE -lt $LOCK_STALE_THRESHOLD ]]; then
        exit 0
    else
        rm -f "$GLOBAL_LOCK" 2>/dev/null
    fi
fi

if (set -o noclobber; echo "$$" > "$GLOBAL_LOCK") 2>/dev/null; then
    trap cleanup_lock EXIT INT TERM
    touch "$LOCK_FILE"
else
    exit 0
fi

USER_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER_DIR="$HOME/Pictures/wpc"
SEARCH_QUERY="-city -aircraft -vehicle -car -cars -people +abstract"
CATEGORIES="100"
PURITY="100"
API_KEY=""
SORTING="random"
ORDER="desc"
TOP_RANGE=""
MIN_RESOLUTION="3840x2160"
EXACT_RESOLUTIONS=""
RATIOS=""
COLOR=""
KEEP_LAST=50
API_TIMEOUT=5
NOTIFY_SUCCESS_EXPIRE=3000
NOTIFY_ERROR_EXPIRE=5000
STATE_FILE="$HOME/.cache/wpc_state"
HISTORY_FILE="$HOME/.cache/wpc_history"
CURRENT_FILE="$HOME/.cache/wpc_current"
STATE_MAX_ENTRIES=25
HISTORY_MAX_ENTRIES=25

NOTIFY_APP_NAME="wpc"
DESKTOP_ENV="${XDG_CURRENT_DESKTOP,,}"

MONITOR=""
MONITOR_COUNT=0

detect_monitors() {
    case "$DESKTOP_ENV" in
        *kde*)
            if command -v kscreen-doctor &> /dev/null; then
                MONITOR_COUNT=$(kscreen-doctor -o 2>/dev/null | grep -c "Output:" || echo 1)
            else
                MONITOR_COUNT=1
            fi
            ;;
        *gnome*|*cinnamon*)
            if command -v gdbus &> /dev/null; then
                MONITOR_COUNT=$(gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
                    --object-path /org/gnome/Mutter/DisplayConfig \
                    --method org.gnome.Mutter.DisplayConfig.GetCurrentState 2>/dev/null | \
                    grep -o "monitor" | wc -l || echo 1)
                [[ $MONITOR_COUNT -eq 0 ]] && MONITOR_COUNT=1
            else
                MONITOR_COUNT=1
            fi
            ;;
        *xfce*)
            MONITOR_COUNT=$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -c "/backdrop/screen0/monitor" || echo 1)
            [[ $MONITOR_COUNT -eq 0 ]] && MONITOR_COUNT=1
            ;;
        *)
            MONITOR_COUNT=1
            ;;
    esac
}

notify() {
    local message="$1"
    local icon="${2:-dialog-information}"
    local expire="${3:-$NOTIFY_SUCCESS_EXPIRE}"
    notify-send "$NOTIFY_APP_NAME" "$message" --app-name="$NOTIFY_APP_NAME" --icon="$icon" --expire-time="$expire"
}

notify_error() {
    notify "$1" "dialog-error" "$NOTIFY_ERROR_EXPIRE"
}

notify_success() {
    notify "$1" "${2:-dialog-information}" "$NOTIFY_SUCCESS_EXPIRE"
}

check_history_files() {
    local history_file="${HISTORY_FILE}${MONITOR:+_m${MONITOR}}"
    local current_file="${CURRENT_FILE}${MONITOR:+_m${MONITOR}}"

    if [[ ! -f "$history_file" ]] || [[ ! -f "$current_file" ]]; then
        notify_error "No wallpaper history available${MONITOR:+ for monitor $MONITOR}"
        exit 1
    fi
}

trim_file() {
    local file="$1"
    local max_entries="$2"

    if [[ -f "$file" ]]; then
        local lines
        lines=$(wc -l < "$file")
        if [[ $lines -gt $max_entries ]]; then
            local temp_file
            temp_file=$(mktemp) || return 1
            if tail -n "$max_entries" "$file" > "$temp_file" 2>/dev/null; then
                if mv "$temp_file" "$file" 2>/dev/null; then
                    return 0
                fi
            fi
            rm -f "$temp_file"
            return 1
        fi
    fi
    return 0
}

check_desktop_support() {
    case "$DESKTOP_ENV" in
        *kde*)
            if ! command -v plasma-apply-wallpaperimage &> /dev/null; then
                notify_error "plasma-apply-wallpaperimage not found!"
                exit 1
            fi
            ;;
        *gnome*|*cinnamon*)
            if ! command -v gsettings &> /dev/null; then
                notify_error "gsettings not found!"
                exit 1
            fi
            ;;
        *xfce*)
            if ! command -v xfconf-query &> /dev/null; then
                notify_error "xfconf-query not found!"
                exit 1
            fi
            ;;
        *mate*)
            if ! command -v gsettings &> /dev/null; then
                notify_error "gsettings not found!"
                exit 1
            fi
            ;;
        *lxqt*)
            if ! command -v pcmanfm-qt &> /dev/null; then
                notify_error "pcmanfm-qt not found!"
                exit 1
            fi
            ;;
        *)
            notify_error "Unsupported desktop environment: $DESKTOP_ENV"
            exit 1
            ;;
    esac
}

apply_wallpaper() {
    local wallpaper_file="$1"
    local monitor="$2"

    case "$DESKTOP_ENV" in
        *kde*)
            if [[ -n "$monitor" ]]; then
                plasma-apply-wallpaperimage -m "$monitor" "$wallpaper_file"
            else
                plasma-apply-wallpaperimage "$wallpaper_file"
            fi

            if command -v kwriteconfig6 &> /dev/null; then
                kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$wallpaper_file"
                if command -v qdbus6 &> /dev/null; then
                    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
                elif command -v qdbus &> /dev/null; then
                    qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
                fi
            fi
            ;;
        *gnome*|*cinnamon*)
            gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_file"
            gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_file"
            ;;
        *xfce*)
            if [[ -n "$monitor" ]]; then
                local monitor_index=$((monitor - 1))
                xfconf-query -c xfce4-desktop -p "/backdrop/screen0/monitor${monitor_index}/image-path" -s "$wallpaper_file"
            else
                xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s "$wallpaper_file"
            fi
            ;;
        *mate*)
            gsettings set org.mate.background picture-filename "$wallpaper_file"
            ;;
        *lxqt*)
            pcmanfm-qt --set-wallpaper "$wallpaper_file"
            ;;
    esac
}

add_to_history() {
    local wallpaper_file="$1"
    local history_file="${HISTORY_FILE}${MONITOR:+_m${MONITOR}}"
    local current_file="${CURRENT_FILE}${MONITOR:+_m${MONITOR}}"

    echo "$wallpaper_file" >> "$history_file"
    trim_file "$history_file" "$HISTORY_MAX_ENTRIES"
    echo "0" > "$current_file"
}

cleanup_old_wallpapers() {
    [[ "$KEEP_LAST" -eq 0 ]] && return

    local existing_count
    existing_count=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | wc -l)

    if [[ $existing_count -ge $KEEP_LAST ]]; then
        local delete_count=$((existing_count - KEEP_LAST + 1))

        find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf '%T@ %p\n' 2>/dev/null | \
            sort -n | \
            head -n "$delete_count" | \
            cut -d' ' -f2- | \
            xargs -r rm -f
    fi
}

update_state_file() {
    local state_key="$1"
    local next_page="$2"
    local seed="$3"

    local temp_file
    temp_file=$(mktemp) || return 1

    if [[ -f "$STATE_FILE" ]]; then
        awk -v key="$state_key" -F: '$1 != key' "$STATE_FILE" > "$temp_file" 2>/dev/null || true
    fi

    if [[ -n "$seed" ]]; then
        echo "${state_key}:${next_page}:${seed}" >> "$temp_file"
    else
        echo "${state_key}:${next_page}" >> "$temp_file"
    fi

    if tail -n "$STATE_MAX_ENTRIES" "$temp_file" > "${temp_file}.trim" 2>/dev/null; then
        mv "${temp_file}.trim" "$STATE_FILE" 2>/dev/null || rm -f "${temp_file}.trim"
    fi

    rm -f "$temp_file"
}

set_local_wallpaper() {
    local source_dir="$1"
    local notification_prefix="$2"

    if [[ ! -d "$source_dir" ]]; then
        notify_error "Directory not found: $source_dir"
        exit 1
    fi

    mapfile -t wallpapers < <(find "$source_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null)

    if [[ ${#wallpapers[@]} -eq 0 ]]; then
        notify_error "No wallpapers found in: $source_dir"
        exit 1
    fi

    local random_index
    random_index=$(shuf -i 0-$((${#wallpapers[@]} - 1)) -n 1)
    local wallpaper_file="${wallpapers[$random_index]}"
    local filename
    filename=$(basename "$wallpaper_file")

    check_desktop_support
    apply_wallpaper "$wallpaper_file" "$MONITOR" || exit 1
    add_to_history "$wallpaper_file"

    local monitor_text=""
    [[ -n "$MONITOR" ]] && monitor_text=" (Monitor $MONITOR)"
    notify_success "${notification_prefix}: $filename${monitor_text}" "$wallpaper_file"
    exit 0
}

navigate_history() {
    local direction="$1"
    check_history_files
    check_desktop_support

    local history_file="${HISTORY_FILE}${MONITOR:+_m${MONITOR}}"
    local current_file="${CURRENT_FILE}${MONITOR:+_m${MONITOR}}"

    local current_index
    current_index=$(cat "$current_file" 2>/dev/null || echo "0")
    local history_count
    history_count=$(wc -l < "$history_file")
    local next_index
    local wallpaper_file
    local attempts=0
    local max_attempts=$history_count

    while [[ $attempts -lt $max_attempts ]]; do
        if [[ "$direction" == "back" ]]; then
            next_index=$((current_index + 1))

            if [[ $next_index -ge $history_count ]]; then
                notify "Already at oldest wallpaper in history" "dialog-information" "$NOTIFY_ERROR_EXPIRE"
                exit 0
            fi
        else
            next_index=$((current_index - 1))

            if [[ $next_index -lt 0 ]]; then
                notify "Already at newest wallpaper in history" "dialog-information" "$NOTIFY_ERROR_EXPIRE"
                exit 0
            fi
        fi

        wallpaper_file=$(tail -n "$((next_index + 1))" "$history_file" | head -n 1)

        if [[ -f "$wallpaper_file" ]]; then
            echo "$next_index" > "$current_file"
            apply_wallpaper "$wallpaper_file" "$MONITOR" || exit 1

            local direction_text filename monitor_text
            [[ "$direction" == "back" ]] && direction_text="Previous" || direction_text="Next"
            filename=$(basename "$wallpaper_file")
            [[ -n "$MONITOR" ]] && monitor_text=" (Monitor $MONITOR)" || monitor_text=""

            notify_success "$direction_text: $filename$monitor_text\n($((history_count - next_index)) of $history_count)" "$wallpaper_file"
            exit 0
        else
            current_index=$next_index
            ((attempts++))
        fi
    done

    notify_error "No valid wallpapers found in history"
    exit 1
}

cleanup_history() {
    check_history_files

    local history_file="${HISTORY_FILE}${MONITOR:+_m${MONITOR}}"
    local current_file="${CURRENT_FILE}${MONITOR:+_m${MONITOR}}"

    local temp_file
    temp_file=$(mktemp) || exit 1
    trap "rm -f '$temp_file'" RETURN

    local removed_count=0
    local kept_count=0

    while IFS= read -r wallpaper_file; do
        if [[ -f "$wallpaper_file" ]]; then
            echo "$wallpaper_file" >> "$temp_file"
            ((kept_count++))
        else
            ((removed_count++))
        fi
    done < "$history_file"

    if [[ $removed_count -gt 0 ]]; then
        mv "$temp_file" "$history_file"
        echo "0" > "$current_file"
        notify_success "Cleaned up history:\nRemoved: $removed_count dead entries\nKept: $kept_count valid entries"
    else
        notify_success "History is clean: All $kept_count entries are valid"
    fi
    exit 0
}

show_config() {
    detect_monitors
    cat << EOF
WALLPAPER CHANGER - CURRENT CONFIGURATION

Directories:
  USER_WALLPAPER_DIR    = $USER_WALLPAPER_DIR
  WALLPAPER_DIR         = $WALLPAPER_DIR

Search Parameters:
  SEARCH_QUERY          = $SEARCH_QUERY
  CATEGORIES            = $CATEGORIES (100=General, 010=Anime, 001=People)
  PURITY                = $PURITY (100=SFW, 010=Sketchy, 001=NSFW)
  API_KEY               = ${API_KEY:+[SET]}${API_KEY:-[NOT SET]}

Sorting & Filtering:
  SORTING               = $SORTING
  ORDER                 = $ORDER
  TOP_RANGE             = ${TOP_RANGE:-[NOT SET]}
  MIN_RESOLUTION        = $MIN_RESOLUTION
  EXACT_RESOLUTIONS     = ${EXACT_RESOLUTIONS:-[NOT SET]}
  RATIOS                = ${RATIOS:-[NOT SET]}
  COLOR                 = ${COLOR:-[NOT SET]}

Behavior:
  KEEP_LAST             = $KEEP_LAST wallpapers
  API_TIMEOUT           = $API_TIMEOUT seconds
  MIN_FILE_SIZE         = $MIN_FILE_SIZE bytes
  NOTIFY_SUCCESS_EXPIRE = $NOTIFY_SUCCESS_EXPIRE ms
  NOTIFY_ERROR_EXPIRE   = $NOTIFY_ERROR_EXPIRE ms

History & State:
  STATE_FILE            = $STATE_FILE
  HISTORY_FILE          = $HISTORY_FILE
  CURRENT_FILE          = $CURRENT_FILE
  STATE_MAX_ENTRIES     = $STATE_MAX_ENTRIES
  HISTORY_MAX_ENTRIES   = $HISTORY_MAX_ENTRIES

Multi-Monitor:
  DETECTED_MONITORS     = $MONITOR_COUNT
  MONITOR_SUPPORT       = ${MONITOR:+Monitor $MONITOR selected}${MONITOR:-All monitors (default)}

Desktop Environment:
  DESKTOP_ENV           = $DESKTOP_ENV
EOF
    exit 0
}

show_help() {
    cat << 'EOF'
WALLPAPER CHANGER SCRIPT (wpc.sh)

USAGE:
  ./wpc.sh                    # Use configuration values from script (all monitors)
  ./wpc.sh [OPTIONS]          # Override configuration with command-line options
  ./wpc.sh --save [OPTIONS]   # Save OPTIONS to script configuration permanently
  ./wpc.sh m1                 # Set wallpaper on monitor 1
  ./wpc.sh m2                 # Set wallpaper on monitor 2
  ./wpc.sh m3                 # Set wallpaper on monitor 3
  ./wpc.sh m1 back            # Go back to previous wallpaper on monitor 1
  ./wpc.sh m2 forward         # Go forward to next wallpaper on monitor 2
  ./wpc.sh m1 copy            # Copy current wallpaper from monitor 1 to favorites
  ./wpc.sh m2 localrandom     # Set random wallpaper from favorites on monitor 2
  ./wpc.sh back               # Go back to previous wallpaper (all monitors)
  ./wpc.sh forward            # Go forward to next wallpaper (all monitors)
  ./wpc.sh copy               # Copy current wallpaper to favorites folder
  ./wpc.sh localrandom        # Set random wallpaper from USER_WALLPAPER_DIR
  ./wpc.sh cleanup            # Remove dead entries from history
  ./wpc.sh show-config        # Display current configuration

MULTI-MONITOR COMMANDS:
  m1, m2, m3, m4, etc.        Specify which monitor to change wallpaper on
                              Example: ./wpc.sh m1 (changes monitor 1)
                              Example: ./wpc.sh m2 -q "sunset" (monitor 2 with sunset query)

  NOTES:
  - Each monitor maintains its own independent wallpaper history
  - History files are stored as ~/.cache/wpc_history_m1, wpc_history_m2, etc.
  - When no monitor is specified, wallpaper applies to all monitors (default)
  - KDE Plasma has native per-monitor wallpaper support
  - GNOME/Cinnamon/MATE apply wallpaper to all monitors (no per-monitor support)
  - XFCE supports per-monitor wallpapers

OPTIONS:
  -h, --help                  Show this help message
  --save                      Save the provided options to script config (updates the file)
  back                        Navigate to previous wallpaper in history
  forward                     Navigate to next wallpaper in history
  copy                        Copy current wallpaper to USER_WALLPAPER_DIR (favorites)
  localrandom                 Set random wallpaper from USER_WALLPAPER_DIR (favorites)
  cleanup                     Remove non-existent wallpapers from history
  show-config                 Display current configuration values
  -l, --local                 Use local wallpaper mode (ignores other options)
  -d, --dir PATH              Local wallpaper directory (default: ~/Pictures/Wallpapers)
  -q, --query "TEXT"          Search query (e.g., "abstract", "+sunset -city", "-'video games'")
  -c, --categories XXX        Categories: 100=General, 010=Anime, 001=People
  -p, --purity XXX            Purity: 100=SFW, 010=Sketchy, 001=NSFW
  -k, --apikey KEY            Wallhaven API key (required for NSFW)
  -s, --sorting METHOD        Sorting: date_added, relevance, random, views, favorites, toplist
  -o, --order ORDER           Order: desc, asc (default: desc)
  -t, --toprange RANGE        Top range (toplist only): 1d, 3d, 1w, 1M, 3M, 6M, 1y
  -m, --minres WIDTHxHEIGHT   Minimum resolution (e.g., 1920x1080, 3840x2160)
  -e, --exact RES1,RES2       Exact resolutions, comma-separated
  -r, --ratios RATIO1,RATIO2  Aspect ratios, comma-separated (e.g., 16x9,21x9)
  --color HEXCOLOR            Color filter (hex without #, e.g., 660000)
  --keep N                    Keep last N wallpapers (0=keep all)
  --timeout N                 API request timeout in seconds (default: 5)

CONFIGURATION:
  The script stores configuration directly in itself. Use --save to persist changes:
    ./wpc.sh --save -q "nature" -m 1920x1080 --keep 50

  View current settings:
    ./wpc.sh show-config

  Default values (before any customization):
    MIN_RESOLUTION    = 3840x2160 (4K - change if you have lower resolution screen)
    SEARCH_QUERY      = "-city -aircraft -vehicle -car -cars +abstract"
    CATEGORIES        = 100 (General only)
    PURITY            = 100 (SFW only)
    KEEP_LAST         = 25 wallpapers
    API_TIMEOUT       = 5 seconds
    WALLPAPER_DIR     = ~/Pictures/wpc
    USER_WALLPAPER_DIR = ~/Pictures/Wallpapers (for favorites)

DIRECTORIES:
  Downloads:  ~/Pictures/wpc
  Favorites:  ~/Pictures/Wallpapers
  Cache:      ~/.cache/wpc_state, ~/.cache/wpc_history, ~/.cache/wpc_current
              Per-monitor: ~/.cache/wpc_history_m1, wpc_history_m2, etc.

API KEY (for NSFW content):
  Get your free API key: https://wallhaven.cc/settings/account
  Save it permanently: ./wpc.sh --save -k YOUR_API_KEY_HERE
  Or use temporarily: ./wpc.sh -k YOUR_API_KEY_HERE -p 001

SEARCH QUERY SYNTAX:
  Basic search:        ./wpc.sh -q "sunset"
  Include term:        ./wpc.sh -q "+sunset"
  Exclude term:        ./wpc.sh -q "-city"
  Multiple terms:      ./wpc.sh -q "+sunset -city +nature"
  Quoted phrases:      ./wpc.sh -q "-'video games' +abstract"
  Exclusion-only:      ./wpc.sh -q "-city -car" (fetches tags from results)

CATEGORIES & PURITY (3-digit bitmask):
  Categories:
    100 = General only
    010 = Anime only
    001 = People only
    110 = General + Anime
    111 = All categories

  Purity:
    100 = SFW only
    110 = SFW + Sketchy
    111 = All (requires API key)

EXAMPLE KEYBINDS (KDE):

  Single Monitor Setup:
    System Settings > Keyboard > Shortcuts > Add New > Command or Script
    Command: /path/to/wpc.sh
    Suggested keys:    → command
    Meta+Ctrl+W        → /path/to/wpc.sh                # Next wallpaper (API)
    Meta+Ctrl+Q        → /path/to/wpc.sh back           # Previous wallpaper
    Meta+Ctrl+E        → /path/to/wpc.sh forward        # Forward in history
    Meta+Ctrl+C        → /path/to/wpc.sh copy           # Copy to favorites
    Meta+Ctrl+Shift+R  → /path/to/wpc.sh localrandom    # Random from favorites

  Multi-Monitor Setup:
    Meta+Ctrl+1        → /path/to/wpc.sh m1             # Change monitor 1 wallpaper
    Meta+Ctrl+2        → /path/to/wpc.sh m2             # Change monitor 2 wallpaper
    Meta+Ctrl+3        → /path/to/wpc.sh m3             # Change monitor 3 wallpaper
    Meta+Ctrl+Shift+1  → /path/to/wpc.sh m1 back        # Monitor 1 previous
    Meta+Alt+1         → /path/to/wpc.sh m1 forward     # Monitor 1 forward
    Meta+Ctrl+C+1      → /path/to/wpc.sh m1 copy        # Copy monitor 1 to favorites
    Meta+Ctrl+Shift+R  → /path/to/wpc.sh m1 localrandom # Monitor 1 random from favorites
    Meta+Ctrl+Shift+2  → /path/to/wpc.sh m2 back        # Monitor 2 previous
    Meta+Alt+2         → /path/to/wpc.sh m2 forward     # Monitor 2 forward
    Meta+Ctrl+C+2      → /path/to/wpc.sh m2 copy        # Copy monitor 2 to favorites

TROUBLESHOOTING:
  Wallpaper doesn't change:
    - Check if your desktop environment is supported: ./wpc.sh show-config
    - For KDE: Ensure plasma-apply-wallpaperimage is installed
    - Try manually: plasma-apply-wallpaperimage ~/Pictures/wpc/any_image.jpg

  Multi-monitor not working:
    - Check detected monitors: ./wpc.sh show-config
    - KDE: plasma-apply-wallpaperimage supports per-monitor with -m flag
    - XFCE: Per-monitor supported via xfconf-query
    - GNOME/MATE: No native per-monitor support (applies to all)

  "All wallpapers already exist" message:
    - Script tracks downloaded wallpapers to avoid duplicates
    - Will auto-advance to next page on next run
    - To force new downloads: rm ~/.cache/wpc_state

  Clear all cache and start fresh:
    rm ~/.cache/wpc_*

  Script seems to do nothing:
    - Check rate limiting (2-second minimum between runs)
    - View errors: ./wpc.sh 2>&1 | less

EOF
    exit 0
}

save_config() {
    local script_path="$0"
    local temp_file
    temp_file=$(mktemp) || exit 1
    declare -A updates

    for var in USER_WALLPAPER_DIR SEARCH_QUERY CATEGORIES PURITY API_KEY SORTING ORDER TOP_RANGE MIN_RESOLUTION EXACT_RESOLUTIONS RATIOS COLOR KEEP_LAST API_TIMEOUT; do
        [[ -n "${!SAVE_${var}+x}" ]] && eval "updates[$var]=\${SAVE_${var}}"
    done

    local quoted_vars="SEARCH_QUERY USER_WALLPAPER_DIR API_KEY SORTING ORDER TOP_RANGE MIN_RESOLUTION EXACT_RESOLUTIONS RATIOS COLOR CATEGORIES PURITY"

    while IFS= read -r line; do
        local updated=false
        for var in "${!updates[@]}"; do
            if [[ "$line" =~ ^${var}= ]]; then
                if [[ " $quoted_vars " =~ " $var " ]]; then
                    echo "${var}=\"${updates[$var]}\"" >> "$temp_file"
                else
                    echo "${var}=${updates[$var]}" >> "$temp_file"
                fi
                updated=true
                break
            fi
        done

        [[ "$updated" == false ]] && echo "$line" >> "$temp_file"
    done < "$script_path"

    mv "$temp_file" "$script_path"
    chmod +x "$script_path"

    echo "Configuration saved successfully to $script_path"
    echo ""
    echo "Updated values:"
    for var in "${!updates[@]}"; do
        echo "  $var = ${updates[$var]}"
    done
    exit 0
}

validate_parameters() {
    if ! [[ "$KEEP_LAST" =~ ^[0-9]+$ ]]; then
        echo "Error: --keep must be a non-negative integer (got: $KEEP_LAST)" >&2
        exit 1
    fi

    if ! [[ "$API_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$API_TIMEOUT" -lt 1 ]]; then
        echo "Error: --timeout must be a positive integer (seconds, got: $API_TIMEOUT)" >&2
        exit 1
    fi

    if [[ -n "$CATEGORIES" ]] && ! [[ "$CATEGORIES" =~ ^[01]{3}$ ]]; then
        echo "Error: --categories must be exactly 3 digits (0 or 1)" >&2
        echo "Examples: 100 (General), 010 (Anime), 001 (People), 111 (All)" >&2
        exit 1
    fi

    if [[ -n "$PURITY" ]] && ! [[ "$PURITY" =~ ^[01]{3}$ ]]; then
        echo "Error: --purity must be exactly 3 digits (0 or 1)" >&2
        echo "Examples: 100 (SFW), 010 (Sketchy), 001 (NSFW), 110 (SFW+Sketchy)" >&2
        exit 1
    fi

    if [[ "$PURITY" =~ 1$ && -z "$API_KEY" ]]; then
        echo "Error: API key required for NSFW content (purity includes 001)" >&2
        echo "Get your API key from: https://wallhaven.cc/settings/account" >&2
        exit 1
    fi

    if [[ -n "$SORTING" ]]; then
        local valid_sorting=("date_added" "relevance" "random" "views" "favorites" "toplist")
        if [[ ! " ${valid_sorting[@]} " =~ " ${SORTING} " ]]; then
            echo "Error: --sorting must be one of: ${valid_sorting[*]}" >&2
            exit 1
        fi
    fi

    if [[ -n "$ORDER" ]] && [[ "$ORDER" != "desc" && "$ORDER" != "asc" ]]; then
        echo "Error: --order must be either 'desc' or 'asc'" >&2
        exit 1
    fi

    if [[ -n "$TOP_RANGE" ]]; then
        local valid_toprange=("1d" "3d" "1w" "1M" "3M" "6M" "1y")
        if [[ ! " ${valid_toprange[@]} " =~ " ${TOP_RANGE} " ]]; then
            echo "Error: --toprange must be one of: ${valid_toprange[*]}" >&2
            exit 1
        fi
    fi

    if [[ -n "$MIN_RESOLUTION" ]] && ! [[ "$MIN_RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "Error: --minres must be in format WIDTHxHEIGHT (e.g., 1920x1080)" >&2
        exit 1
    fi

    if [[ -n "$EXACT_RESOLUTIONS" ]]; then
        IFS=',' read -ra res_array <<< "$EXACT_RESOLUTIONS"
        for res in "${res_array[@]}"; do
            if ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
                echo "Error: --exact resolutions must be comma-separated WIDTHxHEIGHT values" >&2
                echo "Example: 1920x1080,2560x1440" >&2
                exit 1
            fi
        done
    fi

    if [[ -n "$RATIOS" ]]; then
        IFS=',' read -ra ratio_array <<< "$RATIOS"
        for ratio in "${ratio_array[@]}"; do
            if ! [[ "$ratio" =~ ^[0-9]+x[0-9]+$ ]]; then
                echo "Error: --ratios must be comma-separated WIDTHxHEIGHT values" >&2
                echo "Example: 16x9,21x9,16x10" >&2
                exit 1
            fi
        done
    fi

    if [[ -n "$COLOR" ]] && ! [[ "$COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "Error: --color must be a 6-character hex color without # (e.g., 660000, ff0000)" >&2
        exit 1
    fi
}

SAVE_MODE=false
[[ " $* " =~ " --save " ]] && SAVE_MODE=true

# Check for monitor specification anywhere in arguments
for arg in "$@"; do
    if [[ "$arg" =~ ^m[0-9]+$ ]]; then
        MONITOR="${arg:1}"
        detect_monitors
        if [[ $MONITOR -gt $MONITOR_COUNT ]]; then
            notify_error "Monitor $MONITOR not found (detected $MONITOR_COUNT monitor(s))"
            exit 1
        fi
        # Remove monitor argument from the list
        set -- "${@/$arg/}"
        break
    fi
done

case "$1" in
    back)
        navigate_history "back"
        ;;
    forward)
        navigate_history "forward"
        ;;
    localrandom)
        set_local_wallpaper "$USER_WALLPAPER_DIR" "Favorite"
        ;;
    cleanup)
        cleanup_history
        ;;
    show-config)
        show_config
        ;;
    copy)
        check_history_files
        mkdir -p "$USER_WALLPAPER_DIR"

        history_file="${HISTORY_FILE}${MONITOR:+_m${MONITOR}}"
        current_file="${CURRENT_FILE}${MONITOR:+_m${MONITOR}}"

        current_index=$(cat "$current_file" 2>/dev/null || echo "0")
        wallpaper_file=$(tail -n "$((current_index + 1))" "$history_file" | head -n 1)

        if [[ ! -f "$wallpaper_file" ]]; then
            notify_error "Current wallpaper file no longer exists"
            exit 1
        fi

        filename=$(basename "$wallpaper_file")
        dest_file="$USER_WALLPAPER_DIR/$filename"

        if [[ -f "$dest_file" ]]; then
            notify_success "Already in favorites: $filename"
            exit 0
        fi

        if cp "$wallpaper_file" "$dest_file"; then
            notify_success "Added to favorites!\n$filename" "$wallpaper_file"
            exit 0
        else
            notify_error "Failed to copy wallpaper to favorites"
            exit 1
        fi
        ;;
esac

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        --save)
            shift
            ;;
        -l|--local)
            [[ "$SAVE_MODE" != true ]] && set_local_wallpaper "$USER_WALLPAPER_DIR" "Local"
            shift
            ;;
        -d|--dir)
            [[ "$SAVE_MODE" == true ]] && SAVE_USER_WALLPAPER_DIR="$2" || USER_WALLPAPER_DIR="$2"
            shift 2
            ;;
        -q|--query)
            [[ "$SAVE_MODE" == true ]] && SAVE_SEARCH_QUERY="$2" || SEARCH_QUERY="$2"
            shift 2
            ;;
        -c|--categories)
            [[ "$SAVE_MODE" == true ]] && SAVE_CATEGORIES="$2" || CATEGORIES="$2"
            shift 2
            ;;
        -p|--purity)
            [[ "$SAVE_MODE" == true ]] && SAVE_PURITY="$2" || PURITY="$2"
            shift 2
            ;;
        -k|--apikey)
            [[ "$SAVE_MODE" == true ]] && SAVE_API_KEY="$2" || API_KEY="$2"
            shift 2
            ;;
        -s|--sorting)
            [[ "$SAVE_MODE" == true ]] && SAVE_SORTING="$2" || SORTING="$2"
            shift 2
            ;;
        -o|--order)
            [[ "$SAVE_MODE" == true ]] && SAVE_ORDER="$2" || ORDER="$2"
            shift 2
            ;;
        -t|--toprange)
            [[ "$SAVE_MODE" == true ]] && SAVE_TOP_RANGE="$2" || TOP_RANGE="$2"
            shift 2
            ;;
        -m|--minres)
            [[ "$SAVE_MODE" == true ]] && SAVE_MIN_RESOLUTION="$2" || MIN_RESOLUTION="$2"
            shift 2
            ;;
        -e|--exact)
            [[ "$SAVE_MODE" == true ]] && SAVE_EXACT_RESOLUTIONS="$2" || EXACT_RESOLUTIONS="$2"
            shift 2
            ;;
        -r|--ratios)
            [[ "$SAVE_MODE" == true ]] && SAVE_RATIOS="$2" || RATIOS="$2"
            shift 2
            ;;
        --color)
            [[ "$SAVE_MODE" == true ]] && SAVE_COLOR="$2" || COLOR="$2"
            shift 2
            ;;
        --keep)
            [[ "$SAVE_MODE" == true ]] && SAVE_KEEP_LAST="$2" || KEEP_LAST="$2"
            shift 2
            ;;
        --timeout)
            [[ "$SAVE_MODE" == true ]] && SAVE_API_TIMEOUT="$2" || API_TIMEOUT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

if [[ "$SAVE_MODE" == true ]]; then
    for var in KEEP_LAST CATEGORIES PURITY SORTING ORDER TOP_RANGE MIN_RESOLUTION EXACT_RESOLUTIONS RATIOS COLOR API_TIMEOUT; do
        eval "[[ -n \"\${SAVE_${var}+x}\" ]] && ${var}=\"\${SAVE_${var}}\""
    done
fi

validate_parameters

if [[ "$SAVE_MODE" == true ]]; then
    save_config
fi

check_desktop_support

mkdir -p "$WALLPAPER_DIR" "$(dirname "$STATE_FILE")"

cleanup_old_wallpapers

for cmd in curl jq wget notify-send file; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed" >&2
        [[ "$cmd" != "notify-send" ]] && notify_error "Missing dependency: $cmd" 2>/dev/null
        exit 1
    fi
done

API_URL="https://wallhaven.cc/api/v1/search?"

if [[ -n "$SEARCH_QUERY" ]]; then
    PROCESSED_QUERY=$(echo "$SEARCH_QUERY" | sed -E "
        s/-'([^']+)'/-{\1}/g
        s/\+'([^']+)'/+{\1}/g
        s/-\"([^\"]+)\"/-{\1}/g
        s/\+\"([^\"]+)\"/+{\1}/g
        s/\{([^}]*) /{\1%20/g
        s/ ([^}]*)\}/%20\1}/g
    ")
    ENCODED_QUERY=$(printf '%s' "$PROCESSED_QUERY" | sed 's/ /%20/g')
    API_URL="${API_URL}q=${ENCODED_QUERY}"
fi

[[ -n "$CATEGORIES" ]] && API_URL="${API_URL}&categories=${CATEGORIES}"
[[ -n "$PURITY" ]] && API_URL="${API_URL}&purity=${PURITY}"
[[ -n "$SORTING" ]] && API_URL="${API_URL}&sorting=${SORTING}"
[[ -n "$ORDER" ]] && API_URL="${API_URL}&order=${ORDER}"
[[ -n "$TOP_RANGE" && "$SORTING" == "toplist" ]] && API_URL="${API_URL}&topRange=${TOP_RANGE}"
[[ -n "$MIN_RESOLUTION" ]] && API_URL="${API_URL}&atleast=${MIN_RESOLUTION}"
[[ -n "$EXACT_RESOLUTIONS" ]] && API_URL="${API_URL}&resolutions=${EXACT_RESOLUTIONS}"
[[ -n "$RATIOS" ]] && API_URL="${API_URL}&ratios=${RATIOS}"
[[ -n "$COLOR" ]] && API_URL="${API_URL}&colors=${COLOR}"
[[ -n "$API_KEY" ]] && API_URL="${API_URL}&apikey=${API_KEY}"

STATE_KEY=$(echo "${SEARCH_QUERY}_${CATEGORIES}_${PURITY}_${SORTING}_${ORDER}_${MIN_RESOLUTION}_${EXACT_RESOLUTIONS}_${RATIOS}_${COLOR}_${TOP_RANGE}" | md5sum | cut -d' ' -f1)

CURRENT_PAGE=1
SEED=""

if [[ -f "$STATE_FILE" ]]; then
    SAVED_STATE=$(awk -v key="$STATE_KEY" -F: '$1 == key {print; exit}' "$STATE_FILE" 2>/dev/null)
    if [[ -n "$SAVED_STATE" ]]; then
        SAVED_PAGE=$(echo "$SAVED_STATE" | cut -d':' -f2)
        [[ -n "$SAVED_PAGE" && "$SAVED_PAGE" =~ ^[0-9]+$ ]] && CURRENT_PAGE=$SAVED_PAGE
        [[ "$SORTING" == "random" ]] && SEED=$(echo "$SAVED_STATE" | cut -d':' -f3)
    fi
fi

API_URL="${API_URL}&page=${CURRENT_PAGE}"
[[ -n "$SEED" ]] && API_URL="${API_URL}&seed=${SEED}"

API_RESPONSE=$(curl -s --max-time "$API_TIMEOUT" "$API_URL")
CURL_EXIT=$?

if [[ $CURL_EXIT -ne 0 ]]; then
    if [[ $CURL_EXIT -eq 28 ]]; then
        notify_error "API request timed out after ${API_TIMEOUT}s"
    else
        notify_error "Failed to connect to Wallhaven API (network error)"
    fi
    exit 1
fi

if ! echo "$API_RESPONSE" | jq -e '.data[0]' &> /dev/null; then
    if [[ "$CURRENT_PAGE" -gt 1 ]]; then
        local temp_file
        temp_file=$(mktemp) || exit 1
        if [[ -f "$STATE_FILE" ]]; then
            awk -v key="$STATE_KEY" -F: '$1 != key' "$STATE_FILE" > "$temp_file" 2>/dev/null
            if [[ -s "$temp_file" ]]; then
                mv "$temp_file" "$STATE_FILE" 2>/dev/null || rm -f "$temp_file"
            else
                rm -f "$temp_file"
                touch "$STATE_FILE"
            fi
        fi
        notify_success "Reached end of results, restarting from beginning"
        exit 0
    fi
    notify_error "Invalid API response from Wallhaven. Check your search parameters or try again."
    exit 1
fi

TOTAL_RESULTS=$(echo "$API_RESPONSE" | jq -r '.data | length')

if [[ $TOTAL_RESULTS -eq 0 ]]; then
    notify_error "No results found for query. Try different search parameters."
    exit 1
fi

if [[ "$SORTING" == "random" ]]; then
    SEED=$(echo "$API_RESPONSE" | jq -r '.meta.seed // empty')
fi

[[ "$SORTING" == "random" ]] && SELECTED_INDEX=$(shuf -i 0-$((TOTAL_RESULTS - 1)) -n 1) || SELECTED_INDEX=0

declare -A existing_ids
while IFS= read -r id; do
    existing_ids["$id"]=1
done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f -name "*_id*.*" 2>/dev/null | sed -n 's/.*_id\([^.]*\)\..*/\1/p')

found_new=false
for ((i=0; i<TOTAL_RESULTS; i++)); do
    check_index=$(( (SELECTED_INDEX + i) % TOTAL_RESULTS ))
    temp_id=$(echo "$API_RESPONSE" | jq -r ".data[$check_index].id")

    if [[ ! -v existing_ids[$temp_id] ]]; then
        SELECTED_INDEX=$check_index
        found_new=true
        break
    fi
done

if [[ "$found_new" == false ]]; then
    next_page=$((CURRENT_PAGE + 1))
    update_state_file "$STATE_KEY" "$next_page" "$SEED"
    notify_success "All wallpapers on page $CURRENT_PAGE already exist. Try running again for page $next_page"
    exit 0
fi

read -r image_url resolution wallpaper_id file_type category < <(
    echo "$API_RESPONSE" | jq -r ".data[$SELECTED_INDEX] | \"\(.path) \(.resolution) \(.id) \(.file_type) \(.category)\""
)

if [[ -z "$image_url" || "$image_url" == "null" ]]; then
    notify_error "Failed to fetch wallpaper from Wallhaven! Check your search parameters."
    exit 1
fi

only_exclusions=false
if [[ -n "$SEARCH_QUERY" ]]; then
    has_exclusions=false
    [[ "$SEARCH_QUERY" =~ (^|[[:space:]])-[^[:space:]]+ ]] && has_exclusions=true

    has_inclusions=false
    [[ "$SEARCH_QUERY" =~ (^|[[:space:]])\+[^[:space:]]+ ]] && has_inclusions=true
    [[ "$SEARCH_QUERY" =~ (^|[[:space:]])[^-+[:space:]][^[:space:]]* ]] && has_inclusions=true

    [[ "$has_exclusions" == true && "$has_inclusions" == false ]] && only_exclusions=true
elif [[ -z "$SEARCH_QUERY" ]]; then
    only_exclusions=true
fi

fetched_tag=""
if [[ "$only_exclusions" == true ]]; then
    detail_url="https://wallhaven.cc/api/v1/w/${wallpaper_id}"
    [[ -n "$API_KEY" ]] && detail_url="${detail_url}?apikey=${API_KEY}"

    detail_response=$(curl -s --max-time "$API_TIMEOUT" "$detail_url")
    if [[ $? -eq 0 ]]; then
        fetched_tag=$(echo "$detail_response" | jq -r '.data.tags[0].name // empty')
    fi
    [[ -z "$fetched_tag" ]] && fetched_tag="$category"
fi

case "$file_type" in
    *png*) ext="png" ;;
    *) ext="jpg" ;;
esac

if [[ -z "$SEARCH_QUERY" ]] || [[ "$only_exclusions" == true ]]; then
    query_safe=${fetched_tag:-random}
    query_safe=$(echo "$query_safe" | sed 's/[^a-zA-Z0-9+\-]/_/g; s/__*/_/g; s/^_//; s/_$//')
else
    query_safe=$(echo "$SEARCH_QUERY" | sed "s/-[^' ]*//g; s/['{}\"]//g; s/[^a-zA-Z0-9+]/_/g; s/__*/_/g; s/^_//; s/_$//")
fi

query_safe=${query_safe:0:$FILENAME_MAX_LENGTH}
if [[ ${#query_safe} -eq $FILENAME_MAX_LENGTH ]]; then
    query_hash=$(echo "$SEARCH_QUERY" | md5sum | cut -c1-6)
    query_safe="${query_safe}_${query_hash}"
fi

filename_parts="${query_safe}_${resolution}${COLOR:+_color${COLOR}}_id${wallpaper_id}"
wallpaper_file="$WALLPAPER_DIR/${filename_parts}.${ext}"

if ! wget -q --timeout="$API_TIMEOUT" -O "$wallpaper_file" "$image_url"; then
    notify_error "Failed to download wallpaper!"
    rm -f "$wallpaper_file"
    exit 1
fi

if [[ ! -s "$wallpaper_file" ]]; then
    notify_error "Downloaded file is empty!"
    rm -f "$wallpaper_file"
    exit 1
fi

file_output=$(file -b "$wallpaper_file" 2>/dev/null)
if ! echo "$file_output" | grep -qiE '(image|png|jpeg|jpg)'; then
    notify_error "Downloaded file is not a valid image!"
    rm -f "$wallpaper_file"
    exit 1
fi

file_size=$(stat -c %s "$wallpaper_file" 2>/dev/null || stat -f %z "$wallpaper_file" 2>/dev/null || echo 0)
if [[ $file_size -lt $MIN_FILE_SIZE ]]; then
    notify_error "Downloaded file is too small (possible download error)"
    rm -f "$wallpaper_file"
    exit 1
fi

update_state_file "$STATE_KEY" "$((CURRENT_PAGE + 1))" "$SEED"

apply_wallpaper "$wallpaper_file" "$MONITOR" || exit 1

add_to_history "$wallpaper_file"

monitor_text=""
[[ -n "$MONITOR" ]] && monitor_text=" (Monitor $MONITOR)"

if [[ "$only_exclusions" == true ]] && [[ -n "$fetched_tag" ]]; then
    notify_success "Tag: $fetched_tag${monitor_text}\nQuery: $SEARCH_QUERY\nResolution: $resolution\nID: $wallpaper_id" "$wallpaper_file"
elif [[ -z "$SEARCH_QUERY" ]] && [[ -n "$fetched_tag" ]]; then
    notify_success "Tag: $fetched_tag${monitor_text}\nResolution: $resolution\nID: $wallpaper_id" "$wallpaper_file"
else
    notify_success "Query: $SEARCH_QUERY${monitor_text}\nResolution: $resolution\nID: $wallpaper_id" "$wallpaper_file"
fi
