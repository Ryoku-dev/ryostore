-- DRAGSHIFT-TRIGGER-BEGIN
-- DragShift's Shift+drag trigger (Ryoku plugin "dragshift"). Wayland
-- hides the global mouse/Shift state from apps, so the compositor watches it:
-- Shift while the left button is held asks the plugin to open its radial menu
-- at the cursor. Every bind is non-consuming, so clicks and Shift still reach
-- your apps unchanged. Remove this block to turn the trigger off.
-- The binds are transparent: since Hyprland 0.57 any other input while the
-- button is down (letting go of Shift, a key release) shadows a plain release
-- bind, the release is never seen, and every later Shift opened the menu.
local dragshift = { held = false, shifted = false }

local function dragshift_ipc(args)
    hl.dispatch(hl.dsp.exec_cmd("qs -c shell ipc call dragshift " .. args))
end

-- Games: holding fire + Shift is normal there, so never open over a fullscreen
-- window or a Steam/Proton/gamescope game.
local function dragshift_is_game(w)
    if not w then return false end
    if w.fullscreen ~= 0 then return true end
    local c = tostring(w.class or "")
    return c:find("^steam_app_") ~= nil or c:find("%.exe$") ~= nil
        or c:find("^gamescope") ~= nil or c == "cs2"
end

local function dragshift_shift()
    if not dragshift.held or dragshift_is_game(hl.get_active_window()) then return end
    local p = hl.get_cursor_pos()
    dragshift.shifted = true
    dragshift_ipc("shift " .. math.floor(p.x) .. " " .. math.floor(p.y))
end

hl.bind("mouse:272", function() dragshift.held = true; dragshift.shifted = false end,
    { non_consuming = true, ignore_mods = true, transparent = true })
hl.bind("mouse:272", function()
    dragshift.held = false
    if dragshift.shifted then dragshift.shifted = false; dragshift_ipc("release") end
end, { non_consuming = true, ignore_mods = true, release = true, transparent = true })
hl.bind("SHIFT + Shift_L", dragshift_shift, { non_consuming = true, transparent = true })
hl.bind("SHIFT + Shift_R", dragshift_shift, { non_consuming = true, transparent = true })
hl.bind("Escape", function()
    if dragshift.shifted then dragshift.shifted = false; dragshift_ipc("close") end
end, { non_consuming = true, ignore_mods = true, transparent = true })

-- The menu animates itself; the result cards get Hyprland's live blur behind them.
hl.layer_rule({ name = "dragshift-menu", match = { namespace = "^dragshift-menu$" }, no_anim = true })
hl.layer_rule({ name = "dragshift-toasts", match = { namespace = "^dragshift-toasts$" },
    blur = true, ignore_alpha = 0.05, no_anim = true })
-- The editors (Crop, Annotate, ...) are frameless Qt windows with app_id
-- "dragshift": float and centre them instead of tiling.
hl.window_rule({ name = "float-dragshift", match = { class = "^dragshift$" }, float = true, center = true })
-- DRAGSHIFT-TRIGGER-END
