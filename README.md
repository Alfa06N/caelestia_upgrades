# caelestia_upgrades

Backup y gestión de mis personalizaciones de [Caelestia](https://github.com/caelestia-dots)
sobre Arch Linux, para que sobrevivan a las actualizaciones del sistema.

## Contenido

| Ruta | Qué es |
|------|--------|
| `files/*.qml` | Los 9 archivos del shell (`caelestia-shell`) que he modificado. |
| `files/config-caelestia/` | Mis configs de usuario (`~/.config/caelestia`: `hypr-user.conf`, `shell.json`, `monitors/`, etc.). |
| `files/dots-caelestia/` | Respaldo de los dotfiles de Hyprland tocados (`btop`, `fish`, `hypr`, scripts). Repo completo en `caelestia_dots`. |
| `files/config-systemd-user/` | Servicios systemd de usuario (`caelestia-bt-agent.service`). |
| `files/config-local-bin/` | Scripts propios (`caelestia-bt-agent`, agente BlueZ en Python). |
| `sync-upstream.sh` | Regenera el override del shell desde el paquete + reaplica mis parches. |

## Repos relacionados

| Repo | Ruta local | Qué contiene |
|------|-----------|--------------|
| [caelestia_dots](https://github.com/Alfa06N/caelestia_dots) | `~/.local/share/caelestia` (symlink desde `~/.config/hypr`) | Mirror de los dotfiles completos de Caelestia. `origin` = mi repo, `upstream` = oficial. |
| `~/.config/caelestia` | — | Configs de usuario; repo git local (sin remoto). |

Para actualizar los dotfiles desde el upstream oficial:

```bash
cd ~/.local/share/caelestia
git fetch upstream
git merge upstream/main   # resolver conflictos si los hay
git push origin main      # subir a mi repo
```

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
- `modules/nexus/pages/bluetooth/BluetoothPairing.qml` — conexión + `trusted` automático tras emparejar (con fallback).

## Gestión de energía (perfiles)

Los botones de "Modos de Rendimiento" del shell usan `Quickshell.Services.UPower`
→ **power-profiles-daemon** (ppd) por D-Bus. Por eso **TLP se desactivó** (ambos
no pueden coexistir: pelean por `platform_profile` y los governors).

Estado actual del sistema (no versionado, es config de root):

```bash
sudo systemctl disable --now tlp                 # TLP apagado
sudo systemctl unmask power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
powerprofilesctl list                            # performance/balanced/power-saver
```

Respaldo local: `~/tlp.conf.bak-<fecha>` y `~/tlp-migration.log`.

Revertir (si hiciera falta):

```bash
sudo systemctl disable --now power-profiles-daemon
sudo systemctl enable --now tlp
sudo cp ~/tlp.conf.bak-<fecha> /etc/tlp.conf
```

## Agente Bluetooth

`caelestia-bt-agent` (Python/dbus, capacidad `NoInputNoOutput`) permite emparejar
dispositivos "just works" desde la GUI de Caelestia, que no trae agente propio.
Se instala como servicio systemd de usuario (`caelestia-bt-agent.service`), se
habilita en el login y `sync-upstream.sh` lo reinstala. Cero dependencias nuevas
(usa `python-dbus`/`python-gobject` ya presentes).

Al confirmar el emparejamiento, el agente escribe `Trusted=true` vía D-Bus, así
los dispositivos reconectan solos sin marcarlos a mano.

## Bluetooth: evitar desconexiones en reposo (Opcion C)

Sintoma: el teclado/raton se "desconectaban" a los ~20s de inactividad y
reconectaban al usarlos. Dos causas:

1. **Autosuspend del radio USB.** El adaptador Realtek `0bda:c123` tenia
   `power/control = auto` con `autosuspend_delay_ms = 2000` (2s), y
   `btusb enable_autosuspend=Y`. En reposo el stack USB suspendia el radio y
   cortaba el enlace.

   Fix por regla udev `files/etc-udev/50-bluetooth-no-autosuspend.rules`:

   ```bash
   sudo install -m 644 files/etc-udev/50-bluetooth-no-autosuspend.rules \
        /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
   sudo udevadm control --reload-rules
   sudo udevadm trigger --action=add --subsystem-match=usb
   cat /sys/bus/usb/devices/1-2/power/control   # -> on
   ```

2. **Cierre por inactividad de BlueZ.** `IdleTimeout` sin fijar. Se pone a `0`
   (nunca cerrar enlaces) en `/etc/bluetooth/main.conf` bajo `[General]`:

   ```bash
   sudo cp -a /etc/bluetooth/main.conf /etc/bluetooth/main.conf.bak-$(date +%F-%H%M%S)
   sudo sed -i '/^\[General\]/a IdleTimeout = 0' /etc/bluetooth/main.conf
   sudo systemctl restart bluetooth
   ```

`sync-upstream.sh` aplica ambos si hay sudo disponible (o imprime los comandos
a mano). Ver `files/etc-bluetooth/main.conf.README`.

## Restaurar desde cero (equipo nuevo)

```bash
git clone https://github.com/Alfa06N/caelestia_upgrades.git ~/caelestia_upgrades
sudo pacman -S caelestia-shell caelestia-cli caelestia-meta quickshell-git hyprland
~/caelestia_upgrades/sync-upstream.sh
cp -a ~/caelestia_upgrades/files/config-caelestia/. ~/.config/caelestia/
qs -c caelestia kill; sleep 0.6; caelestia shell -d
```
