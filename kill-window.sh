#!/bin/bash
# ============================================================================
# KDE Plasma Window Kill
# ============================================================================
# Version: 0.1
# AUTHOR: bile
# Last Updated: 2025-11-09
# Tested on: CachyOS, KDE Plasma 6.5.2, Wayland
#
# Description:
#   Gracefully closes the active window via keyboard shortcut.
#   This is the ONLY reliable keyboard-only window kill method on KDE with Wayland.
#
# Why no force-kill option?
#   Wayland's security model prevents keyboard-only force killing.
#   Ctrl+Alt+Esc exists but requires clicking the window (by design).
#   This is a security feature, not a limitation we can work around.
#
# Installation:
#   1. chmod +x kill-window.sh
#   2. System Settings > Keyboard > Shortcuts > Add Command
#      Command: /path/to/kill-window.sh
#      use whatever keybind you want
#
# Usage:
#   kill-window.sh
#
# Dependencies:
#   - qdbus or qdbus-qt6 (comes with KDE)
#   - qt5-tools / sudo pacman -S qt5-tools
#   - KWin
#
# ============================================================================

# Find available qdbus
QDBUS=$(command -v qdbus-qt6 || command -v qdbus)

if [ -z "$QDBUS" ]; then
    exit 1
fi

# Create inline KWin script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
workspace.activeWindow?.closeWindow();
EOF

# Execute and cleanup
SCRIPT_ID=$($QDBUS org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$TEMP_SCRIPT" 2>/dev/null | tail -n1)
[ -n "$SCRIPT_ID" ] && $QDBUS org.kde.KWin "/Scripting/Script${SCRIPT_ID}" org.kde.kwin.Script.run &>/dev/null
rm -f "$TEMP_SCRIPT"

exit 0
