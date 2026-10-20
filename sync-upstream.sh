#!/usr/bin/env bash
#
# sync-upstream.sh - Regenera el override local de caelestia-shell a partir del
# paquete instalado (/etc/xdg/quickshell/caelestia) y reaplica tus parches
# personalizados desde files/.
#
# Uso:
#   ./sync-upstream.sh            # aplica cambios
#   ./sync-upstream.sh --dry-run  # muestra que haria sin tocar nada
#
# Flujo tras actualizar el sistema:
#   sudo pacman -Syu
#   ~/caelestia_upgrades/sync-upstream.sh
#   qs -c caelestia kill; sleep 0.6; caelestia shell -d
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM="/etc/xdg/quickshell/caelestia"
OVERRIDE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
SHELL_FILES="$REPO_DIR/files"
DRY_RUN=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$UPSTREAM" ]] || die "no existe $UPSTREAM (¿esta instalado caelestia-shell?)"
[[ -d "$SHELL_FILES" ]] || die "no existe $SHELL_FILES"

echo "==> Upstream : $UPSTREAM"
echo "==> Override : $OVERRIDE"
echo "==> Parches  : $SHELL_FILES"
[[ $DRY_RUN -eq 1 ]] && echo "==> MODO DRY-RUN (no se modificara nada)"
echo

# 1. Reemplazar el override por una copia fresca del paquete.
if [[ -d "$OVERRIDE" ]]; then
    TS="$(date +%Y%m%d-%H%M%S)"
    BACKUP="${OVERRIDE}.bak-$TS"
    echo "--> Backup del override actual en: $BACKUP"
    [[ $DRY_RUN -eq 0 ]] && cp -a "$OVERRIDE" "$BACKUP"
fi

echo "--> Copiando paquete actualizado al override"
if [[ $DRY_RUN -eq 1 ]]; then
    echo "    (dry-run) rm -rf '$OVERRIDE' && cp -a '$UPSTREAM' '$OVERRIDE'"
else
    rm -rf "$OVERRIDE"
    mkdir -p "$(dirname "$OVERRIDE")"
    cp -a "$UPSTREAM" "$OVERRIDE"
fi

# 2. Reaplicar los archivos personalizados encima.
echo "--> Reaplicando parches personalizados"
WARN=0
while IFS= read -r -d '' file; do
    rel="${file#"$SHELL_FILES"/}"
    # Solo los archivos del shell (no la carpeta config-caelestia)
    [[ "$rel" == config-caelestia/* ]] && continue
    if [[ ! -e "$UPSTREAM/$rel" ]]; then
        echo "    AVISO: '$rel' ya no existe en upstream (renombrado/eliminado). Revisar manualmente."
        WARN=1
    fi
    echo "    + $rel"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$OVERRIDE/$(dirname "$rel")"
        cp -a "$file" "$OVERRIDE/$rel"
    fi
done < <(find "$SHELL_FILES" -type f \
    -not -path "*/config-caelestia/*" \
    -not -path "*/config-systemd-user/*" \
    -not -path "*/config-local-bin/*" \
    -not -path "*/etc-udev/*" \
    -not -path "*/etc-bluetooth/*" \
    -not -path "*/dots-caelestia/*" -print0)

# 3. Instalar el agente Bluetooth propio y su servicio systemd de usuario.
BT_AGENT="$SHELL_FILES/config-local-bin/caelestia-bt-agent"
BT_SERVICE="$SHELL_FILES/config-systemd-user/caelestia-bt-agent.service"
if [[ -f "$BT_AGENT" ]]; then
    echo "--> Instalando agente Bluetooth (caelestia-bt-agent)"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
        install -m 755 "$BT_AGENT" "$HOME/.local/bin/caelestia-bt-agent"
        install -m 644 "$BT_SERVICE" "$HOME/.config/systemd/user/caelestia-bt-agent.service"
        systemctl --user daemon-reload
        systemctl --user enable --now caelestia-bt-agent.service
    else
        echo "    (dry-run) install agente + servicio y systemctl --user enable --now"
    fi
fi

# 4. Sistema: reglas udev y ajustes de BlueZ (requieren sudo).
UDEV_SRC="$SHELL_FILES/etc-udev/50-bluetooth-no-autosuspend.rules"
UDEV_DST="/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules"
if [[ -f "$UDEV_SRC" ]]; then
    echo "--> Instalando regla udev (bluetooth sin autosuspend)"
    if [[ $DRY_RUN -eq 0 ]]; then
        if [[ -w /etc/udev/rules.d ]] || sudo -n true 2>/dev/null; then
            sudo install -m 644 "$UDEV_SRC" "$UDEV_DST"
            sudo udevadm control --reload-rules
            sudo udevadm trigger --action=add --subsystem-match=usb
        else
            echo "    AVISO: se requiere sudo. Ejecuta manualmente:"
            echo "      sudo install -m 644 '$UDEV_SRC' '$UDEV_DST'"
            echo "      sudo udevadm control --reload-rules"
            echo "      sudo udevadm trigger --action=add --subsystem-match=usb"
        fi
    else
        echo "    (dry-run) install regla udev + udevadm reload/trigger"
    fi
fi

# 5. BlueZ: IdleTimeout = 0 en /etc/bluetooth/main.conf (desactiva cierre por inactividad).
if [[ -f /etc/bluetooth/main.conf ]]; then
    if ! grep -qE '^\s*IdleTimeout\s*=\s*0\b' /etc/bluetooth/main.conf; then
        echo "--> Ajustando BlueZ IdleTimeout = 0"
        if [[ $DRY_RUN -eq 0 ]]; then
            if sudo -n true 2>/dev/null || [[ -w /etc/bluetooth/main.conf ]]; then
                sudo cp -a /etc/bluetooth/main.conf "/etc/bluetooth/main.conf.bak-$(date +%Y%m%d-%H%M%S)"
                if grep -qE '^\s*#?\s*IdleTimeout' /etc/bluetooth/main.conf; then
                    sudo sed -i 's/^\s*#\?\s*IdleTimeout.*/IdleTimeout = 0/' /etc/bluetooth/main.conf
                else
                    sudo sed -i '/^\[General\]/a IdleTimeout = 0' /etc/bluetooth/main.conf
                fi
                sudo systemctl restart bluetooth
            else
                echo "    AVISO: se requiere sudo. Anade 'IdleTimeout = 0' bajo [General] en"
                echo "      /etc/bluetooth/main.conf y ejecuta: sudo systemctl restart bluetooth"
            fi
        else
            echo "    (dry-run) IdleTimeout = 0 + systemctl restart bluetooth"
        fi
    else
        echo "--> BlueZ IdleTimeout ya esta en 0, sin cambios"
    fi
fi

echo
if [[ $WARN -eq 1 ]]; then
    echo "==> AVISO: algunos parches ya no existen en upstream. Fusiona manualmente esos archivos."
fi
echo "==> Listo. Reinicia el shell:"
echo "    qs -c caelestia kill; sleep 0.6; caelestia shell -d"
echo
echo "Nota: las configs de ~/.config/caelestia (hypr-user.conf, shell.json, monitors)"
echo "viven en files/config-caelestia/ pero NO se aplican automaticamente; copialas"
echo "manualmente si hace falta (ya sobreviven a updates porque no son de pacman)."
