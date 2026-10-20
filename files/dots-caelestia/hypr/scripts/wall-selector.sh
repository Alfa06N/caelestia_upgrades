#!/bin/bash
# Carpeta donde tienes tus fotos de GitHub
WALL_DIR="$HOME/Pictures/Wallpapers"

swww-daemon &
sleep 0.5

list_images() {
    for img in "$WALL_DIR"/*.{jpg,jpeg,png,webp}; do
        if [ -f "$img" ]; then
            echo -en "$(basename "$img")\0icon\x1f$img\n"
        fi
    done
}

# 2. Lanzar Rofi con el grid de miniaturas
selection=$(list_images | rofi -dmenu -i -p "🖼️ Galería" \
-theme-str 'configuration { show-icons: true; } 
            window { width: 65%; } 
            listview { columns: 3; lines: 2; spacing: 15px; } 
            element { orientation: vertical; padding: 10px; } 
            element-icon { size: 180px; horizontal-align: 0.5; } 
            element-text { horizontal-align: 0.5; vertical-align: 0.5; }')

# 3. Si hay selección, aplicar la magia
if [ -n "$selection" ]; then
    swww img "$WALL_DIR/$selection" --transition-type grow --transition-pos 0.5,0.5
    wal -i "$WALL_DIR/$selection" -n
    cat ~/.cache/wal/sequences
    pkill -9 quickshell
    sleep 0.4
    quickshell > /dev/null 2>&1 &    
    notify-send "Caelestia" "Wallpaper: $selection"
fi
    

