-- Overrides de variables de Caelestia (no lo tocan las actualizaciones).
-- Referencia completa: hypr/variables.lua del repo de dots.

return {
    -- Apps por defecto
    terminal     = "foot",
    browser      = "brave",
    editor       = "code",
    fileExplorer = "thunar",

    -- Touchpad
    touchpadDisableTyping = true,
    touchpadScrollFactor  = 0.5,

    -- Apariencia (persistente; HyprMod escribe hyprland-gui.lua que no se carga)
    windowBorderSize = 2,
    blurEnabled      = false,

    -- Launcher (Super + Space propio)
    kbLauncher            = "SUPER + Space",
}
