#!/bin/bash
TARGET_DIR="$HOME/.local/state/caelestia/wallpaper"
TARGET_File="$TARGET_DIR/path.txt"

while inotifywait -e modify "$TARGET_File" >/dev/null 2>&1; do
    if [ -f "$TARGET_File" ]; then
        CURRENT_WALL=$(cat "$TARGET_File")
        if [ -f "$CURRENT_WALL" ]; then
            awww img "$CURRENT_WALL" --transition-type fade --transition-duration 0.5
        fi
    fi
done