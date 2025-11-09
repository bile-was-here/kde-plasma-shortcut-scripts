# kde-plasma-shortcuts
some of my kde plasma shortcut scripts for keybinds on KDE Plasma 6.5.2

# Volume Control
Volume control script with smooth fading, auto-unmute logic,
and notifications. Supports volumes >100% for amplification.

# Display Scaling Control
Display scaling control script for KDE Plasma.

# Wallpaper Changer
Download and set wallpapers from Wallhaven API or local folder
full history navigation and favorites management with multi monitor support

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
