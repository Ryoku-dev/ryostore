-- UTSURI-TRIGGER-BEGIN
-- Utsuri's Shift+drag trigger (Ryoku plugin "utsuri"). Wayland
-- hides the global mouse/Shift state from apps, so the compositor watches it:
-- Shift while the left button is held asks the plugin to open its radial menu
-- at the cursor. Every bind is non-consuming, so clicks and Shift still reach
-- your apps unchanged. Remove this block to turn the trigger off.
-- The binds are transparent: since Hyprland 0.57 any other input while the
-- button is down (letting go of Shift, a key release) shadows a plain release
-- bind, the release is never seen, and every later Shift opened the menu.
local utsuri = { held = false, shifted = false }

local function utsuri_ipc(args)
    hl.dispatch(hl.dsp.exec_cmd("qs -c shell ipc call utsuri " .. args))
end

-- Games: holding fire + Shift is normal there, so never open over a fullscreen
-- window or a Steam/Proton/gamescope game.
local function utsuri_is_game(w)
    if not w then return false end
    if w.fullscreen ~= 0 then return true end
    local c = tostring(w.class or "")
    return c:find("^steam_app_") ~= nil or c:find("%.exe$") ~= nil
        or c:find("^gamescope") ~= nil or c == "cs2"
end

local function utsuri_shift()
    if not utsuri.held or utsuri_is_game(hl.get_active_window()) then return end
    local p = hl.get_cursor_pos()
    utsuri.shifted = true
    utsuri_ipc("shift " .. math.floor(p.x) .. " " .. math.floor(p.y))
end

hl.bind("mouse:272", function() utsuri.held = true; utsuri.shifted = false end,
    { non_consuming = true, ignore_mods = true, transparent = true })
hl.bind("mouse:272", function()
    utsuri.held = false
    if utsuri.shifted then utsuri.shifted = false; utsuri_ipc("release") end
end, { non_consuming = true, ignore_mods = true, release = true, transparent = true })
hl.bind("SHIFT + Shift_L", utsuri_shift, { non_consuming = true, transparent = true })
hl.bind("SHIFT + Shift_R", utsuri_shift, { non_consuming = true, transparent = true })
hl.bind("Escape", function()
    if utsuri.shifted then utsuri.shifted = false; utsuri_ipc("close") end
end, { non_consuming = true, ignore_mods = true, transparent = true })

-- The menu animates itself; the result cards get Hyprland's live blur behind them.
hl.layer_rule({ name = "utsuri-menu", match = { namespace = "^utsuri-menu$" }, no_anim = true })
hl.layer_rule({ name = "utsuri-toasts", match = { namespace = "^utsuri-toasts$" },
    blur = true, ignore_alpha = 0.05, no_anim = true })
-- The editors (Crop, Annotate, ...) are frameless Qt windows with app_id
-- "utsuri": float and centre them instead of tiling.
hl.window_rule({ name = "float-utsuri", match = { class = "^utsuri$" }, float = true, center = true })
-- Super+Shift+U opens Utsuri's Customize window (theme and menu options), so
-- no bar icon is needed. Change the keys here if they clash with yours.
hl.bind("SUPER + SHIFT + U", function() utsuri_ipc("customize") end)
-- UTSURI-TRIGGER-END
