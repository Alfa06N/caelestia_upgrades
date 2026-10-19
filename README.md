# caelestia_upgrades

Backup y gestión de mis personalizaciones de [Caelestia](https://github.com/caelestia-dots)
sobre Arch Linux, para que sobrevivan a las actualizaciones del sistema.

## Contenido

| Ruta | Qué es |
|------|--------|
| `files/*.qml` | Los 9 archivos del shell (`caelestia-shell`) que he modificado. |
| `files/config-caelestia/` | Mis configs de usuario (`~/.config/caelestia`: `hypr-user.conf`, `shell.json`, `monitors/`, etc.). |
| `sync-upstream.sh` | Regenera el override del shell desde el paquete + reaplica mis parches. |

## Por qué es necesario

Quickshell carga el shell desde `<XDG_CONFIG_HOME>/quickshell/caelestia`
(mi override) **con prioridad sobre** `/etc/xdg/quickshell/caelestia` (el
paquete AUR) y **no fusiona** directorios: mi copia reemplaza al paquete por
completo. Si solo copio el paquete una vez, me quedo congelado y no recibo las
novedades.

Este repo resuelve eso: guarda **solo mis diferencias** y regenera la copia
completa a partir del paquete actualizado cuando toque.

```
~/.config/quickshell/caelestia/     <- override activo (copia completa, se regenera)
/etc/xdg/quickshell/caelestia/      <- paquete caelestia-shell (lo actualiza pacman)
~/caelestia_upgrades/files/         <- MIS parches (este repo, versionado)
```

## Flujo tras actualizar el sistema

```bash
sudo pacman -Syu                      # actualiza caelestia-shell, quickshell, hyprland, etc.
~/caelestia_upgrades/sync-upstream.sh # paquete nuevo + mis parches encima
qs -c caelestia kill; sleep 0.6; caelestia shell -d
```

Antes de aplicar, se puede probar sin tocar nada:

```bash
~/caelestia_upgrades/sync-upstream.sh --dry-run
```

El script hace un backup del override actual en `~/.config/quickshell/caelestia.bak-<fecha>`
antes de regenerarlo.

### Fusionar si hay conflictos

Si upstream cambió un archivo que yo también modifiqué, el script **sobrescribe
con mi versión** (pierdo la mejora upstream en ese archivo concreto). El script
avisa si alguno de mis parches ya no existe en upstream (renombrado/eliminado).

Para revisar qué cambió upstream en mis archivos:

```bash
# comparar mi parche con el paquete actual
diff ~/caelestia_upgrades/files/services/Nmcli.qml \
     /etc/xdg/quickshell/caelestia/services/Nmcli.qml
```

Y editar `files/...` a mano para integrar la mejora, luego commit + push.

## Configs de Hyprland / usuario

- `~/.config/caelestia/hypr-user.conf` es **mío** y se carga **al final** en
  `hyprland.conf`, así que mis binds ganan sobre los dotfiles oficiales sin
  tocarlos. Ejemplo: el bind `Super+Space` (launcher) vive ahí.
- Estas configs **no las toca pacman ni los dotfiles oficiales**, así que
  sobreviven a las actualizaciones sin hacer nada. Se guardan aquí como respaldo.
- El keybind oficial en `~/.local/share/caelestia/hypr/hyprland/keybinds.conf`
  se dejó idéntico a upstream (sin mis cambios) para que `git pull` de los
  dotfiles no dé conflictos.

## Archivos del shell personalizados

- `services/Nmcli.qml` — `forgetNetwork` por SSID (soporta perfiles duplicados), callbacks de resultado.
- `services/Notifs.qml` — limpieza O(n) y tope de notificaciones persistidas.
- `services/Wallpapers.qml` — debounce del preview de color y del fondo.
- `utils/NetworkConnection.qml` — fixes del flujo de conexión WiFi.
- `modules/bar/popouts/Network.qml` — prompt de contraseña para redes sin PSK.
- `modules/bar/popouts/WirelessPassword.qml` — cierre inmediato al conectar (fix "Connecting...").
- `modules/nexus/pages/network/NetworkDetailPage.qml` — estado de error al "Forget".
- `modules/nexus/pages/network/AddNetworkPage.qml` — callbacks de limpieza.
- `modules/sidebar/NotifDock.qml` — limpieza masiva de notificaciones.

## Restaurar desde cero (equipo nuevo)

```bash
git clone https://github.com/Alfa06N/caelestia_upgrades.git ~/caelestia_upgrades
sudo pacman -S caelestia-shell caelestia-cli caelestia-meta quickshell-git hyprland
~/caelestia_upgrades/sync-upstream.sh
cp -a ~/caelestia_upgrades/files/config-caelestia/. ~/.config/caelestia/
qs -c caelestia kill; sleep 0.6; caelestia shell -d
```
