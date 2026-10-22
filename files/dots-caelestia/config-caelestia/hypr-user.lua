-- Configuración personal de Hyprland (Caelestia). Se carga al final y NO la
-- tocan las actualizaciones de los dotfiles.
-- Sintaxis: API Lua `hl.*` (ver https://wiki.hypr.land/Configuring/).
--
-- Contenido de este archivo:
--   * Monitores + redetección de HDMI
--   * Input (teclado us,latam / touchpad / device)
--   * Env extra (WLR / AMD / GL)
--   * misc / debug
--   * window rule de Discord
--   * Binds personales

--------------------
---- MONITORES -----
--------------------

-- Laptop (derecha)
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})

-- Externo (izquierda)
hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@180",
    position = "-1920x0",
    scale    = 1,
})

-- Redetección de HDMI al arrancar (fiabilidad del hotplug)
hl.on("hyprland.start", function()
    hl.exec_cmd("sleep 1 && hyprctl keyword monitor HDMI-A-1,disable")
    hl.exec_cmd("sleep 1.2 && hyprctl keyword monitor HDMI-A-1,1920x1080@180,-1920x0,1")
    hl.exec_cmd("sleep 1.2 && hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1")
end)

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout   = "us,latam",
        kb_options  = "grp:alt_shift_toggle",
        sensitivity = 0,

        follow_mouse = 1,

        touchpad = {
            scroll_factor  = 0.5,
            natural_scroll = false,
            tap_to_click   = true,
        },
    },

    debug = {
        vfr = false,
    },

    misc = {
        vrr                    = 0,
        animate_manual_resizes = false,
        always_follow_on_dnd   = true,
    },
})

-- Touchpad físico: sensibilidad
hl.device({
    name        = "syna2ba6:00-06cb:ce2c-touchpad",
    sensitivity = 0.5,
})

-------------
---- ENV ----
-------------

hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "0")
hl.env("__GL_GSYNC_ALLOWED", "0")
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("WLR_DRM_NO_ATOMIC", "1")
hl.env("AMD_DEBUG", "use_glthread")

--------------------------
---- WINDOW RULES --------
--------------------------

-- Fix de tiling para Discord en el special workspace de comunicación
hl.window_rule({
    name  = "discord-tiling-fix",
    match = {
        class     = "^(discord)$",
        workspace = "name:special:communication",
    },
})

----------------------------
---- BINDS PERSONALES ------
----------------------------

-- Quitar binds por defecto que reemplazamos
hl.unbind("SUPER + V")          -- editor -> code
hl.unbind("SUPER + ALT + S")    -- special ws -> baobab
hl.unbind("SUPER + W")          -- browser -> captura de ventana
hl.unbind("SUPER + S")          -- special ws -> captura de región
hl.unbind("SUPER + ALT + T")
hl.unbind("SUPER + ALT + W")
hl.unbind("SUPER + ALT + D")
hl.unbind("SUPER + J")
for i = 1, 9 do
    hl.unbind("SUPER + " .. i)
end

-- Kill activo (sin repetición)
hl.bind("SUPER + Q", hl.dsp.window.close())

-- VS Code
hl.bind("SUPER + V", hl.dsp.exec_cmd("code"))

-- Almacenamiento (baobab)
hl.bind("SUPER + ALT + Space", hl.dsp.exec_cmd("baobab"))

-- Apps principales
hl.bind("SUPER + B", hl.dsp.exec_cmd("brave"))
hl.bind("SUPER + ALT + T", hl.dsp.exec_cmd("Telegram"))
hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("brave --app=https://web.whatsapp.com"))
hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("spotify"))
hl.bind("SUPER + ALT + D", hl.dsp.exec_cmd("discord"))

-- Captura de región -> portapapeles
hl.bind("SUPER + S", hl.dsp.exec_cmd(
    [[grim -g "$(slurp)" - | wl-copy && notify-send "Captura" "Imagen en portapapeles"]]))

-- Captura de ventana activa -> portapapeles
hl.bind("SUPER + W", hl.dsp.exec_cmd(
    [[grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | wl-copy && notify-send "Captura" "Ventana copiada al portapapeles"]]))

-- Alternar flotante/mosaico
hl.bind("SUPER + ALT + F", hl.dsp.window.float())
hl.bind("SUPER + J", hl.dsp.window.float())

-- Mover ventanas entre workspaces
for i = 1, 5 do
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end

-- Cambiar de workspace (nativo, instantáneo)
for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
end
