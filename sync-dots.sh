#!/usr/bin/env bash
#
# sync-dots.sh - Gestiona la capa C: los dotfiles de Hyprland de Caelestia
# (~/.local/share/caelestia, symlink ~/.config/hypr) junto con las
# personalizaciones del usuario que sobreviven a las actualizaciones.
#
# Modos:
#   ./sync-dots.sh            # restaura tus personalizaciones sobre el dots actual
#   ./sync-dots.sh --save     # guarda (snapshot) tus personalizaciones en files/dots-caelestia/
#   ./sync-dots.sh --dry-run  # muestra que haria sin tocar nada
#
# Personalizaciones gestionadas (NO las tocan las actualizaciones de los dots):
#   ~/.config/caelestia/hypr-vars.lua      (overrides de variables)
#   ~/.config/caelestia/hypr-user.lua      (configs personales de Hyprland)
#   ~/.config/hypr/hypridle.conf           (idle daemon personalizado)
#   ~/.config/systemd/user/hypridle.service.d/override.conf
#   ~/.config/btop/btop.conf
#   ~/.config/fish/config.fish
#
# Flujo tras actualizar el sistema:
#   sudo pacman -Syu
#   caelestia update          # (actualiza los dots ~/.local/share/caelestia)
#   ~/caelestia_upgrades/sync-dots.sh
#   ~/caelestia_upgrades/sync-upstream.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/files/dots-caelestia"
HOME_DIR="${HOME}"

DRY_RUN=0
MODE="restore"
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --save)    MODE="save" ;;
        *) echo "Opcion desconocida: $arg" >&2; exit 1 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
[[ -d "$SRC" ]] || die "no existe $SRC"

# Mapeo: ruta relativa dentro de files/dots-caelestia  ->  ruta real en $HOME
map_path() {
    case "$1" in
        config-caelestia/*)   echo "$HOME_DIR/.config/caelestia/${1#config-caelestia/}" ;;
        config-hypr/*)        echo "$HOME_DIR/.config/hypr/${1#config-hypr/}" ;;
        config-systemd-user/*) echo "$HOME_DIR/.config/systemd/user/${1#config-systemd-user/}" ;;
        btop/*)               echo "$HOME_DIR/.config/btop/${1#btop/}" ;;
        fish/*)               echo "$HOME_DIR/.config/fish/${1#fish/}" ;;
        *)                    echo "" ;;
    esac
}

echo "==> Repo    : $SRC"
echo "==> Modo    : $MODE"
[[ $DRY_RUN -eq 1 ]] && echo "==> DRY-RUN (no se modifica nada)"
echo

if [[ "$MODE" == "save" ]]; then
    TS="$(date +%Y%m%d-%H%M%S)"
    echo "--> Guardando personalizaciones actuales en files/dots-caelestia/"
    while IFS= read -r -d '' file; do
        rel="${file#"$SRC"/}"
        dst="$(map_path "$rel")"
        [[ -z "$dst" ]] && continue
        if [[ -f "$dst" ]]; then
            if [[ $DRY_RUN -eq 0 ]]; then
                mkdir -p "$(dirname "$file")"
                cp -a "$dst" "$file"
            fi
            echo "    = $rel"
        else
            echo "    AVISO: no existe $dst (se omite)"
        fi
    done < <(find "$SRC" -type f -print0)
    echo
    echo "==> Snapshot $TS listo. Revisa 'git -C $REPO_DIR status' y haz commit."
    exit 0
fi

# --- Modo restore -----------------------------------------------------------
echo "--> Restaurando personalizaciones (con backup .bak-<ts> de los actuales)"
TS="$(date +%Y%m%d-%H%M%S)"
while IFS= read -r -d '' file; do
    rel="${file#"$SRC"/}"
    dst="$(map_path "$rel")"
    [[ -z "$dst" ]] && continue
    if [[ -f "$dst" ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
            cp -a "$dst" "$dst.bak-$TS"
        fi
    fi
    echo "    + $rel"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$file" "$dst"
    fi
done < <(find "$SRC" -type f -print0)

# Recargar hypridle si cambio su config.
if [[ $DRY_RUN -eq 0 ]]; then
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user try-restart hypridle.service 2>/dev/null || true
fi

echo
echo "==> Listo. Aplica los cambios de Hyprland con:"
echo "    hyprctl reload"
echo
echo "Nota: los dots base viven en ~/.local/share/caelestia (repo caelestia_dots)."
echo "Este script NO los reemplaza; solo restaura tus personalizaciones encima."
