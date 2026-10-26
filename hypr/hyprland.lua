-- ~/.config/hypr/hyprland.lua

-- hl.config({ debug = { disable_logs = false } })

local MOD   = "SUPER"   -- modkey = Mod4
local ALT   = "ALT"     -- altkey = Mod1
local NTAGS = 9         

local terminal = "alacritty"   
local browser  = "librewolf"
local scripts  = os.getenv("HOME") .. "/.config/hypr/scripts"

local colors = {
    white      = "FFFFFF",
    red        = "913831",
    pink       = "CC9393",
    black      = "1A1A1A",
    black_less = "313131",
    gray       = "3F3F3F",
}

-- MONITORS
local INTERN = "eDP-1"
local EXTERN = "HDMI-A-1"

hl.monitor({ output = EXTERN, mode = "1920x1080", position = "0x0",    scale = 1 })
hl.monitor({ output = INTERN, mode = "preferred", position = "1920x0", scale = 2 })
hl.monitor({ output = "",     mode = "preferred", position = "auto",   scale = "auto" })

local function check_extern(m)
    if m.name ~= EXTERN then return end
    for _, md in ipairs(m.available_modes or {}) do
        if md.width == 1920 and md.height == 1080 then return end
    end
    hl.monitor({ output = EXTERN, disabled = true })
end
hl.on("monitor.added", check_extern)
for _, m in ipairs(hl.get_monitors({ all = true }) or {}) do check_extern(m) end


-- ENVIRONMENT VARIABLES 
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_SCALE", "2")                        
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")  
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")      
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-igpu:/dev/dri/nvidia-dgpu")


-- AUTOSTART 
-- run_once 
hl.on("hyprland.start", function()
    hl.exec_cmd("[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources")  -- Xft.dpi: 192 for XWayland-apps
    hl.exec_cmd("waybar")                     
    hl.exec_cmd("hyprpaper")                 
    hl.exec_cmd("mako")                       
    hl.exec_cmd("hypridle")                   -- light-locker --lock-on-suspend
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("sunshine")
end)


-- LOOK
-- Logical sizes: 
hl.config({
    general = {
        gaps_in     = 0,   -- useless_gap = dpi(0)
        gaps_out    = 0,
        border_size = 1,   -- border_width = dpi(1)
        col = {
            active_border   = "rgb(" .. colors.red .. ")",
            inactive_border = "rgb(" .. colors.gray .. ")",
        },
        resize_on_border = false,
        allow_tearing    = false,
        layout           = "master",  -- awful.layout.suit.tile
    },

    decoration = {
        rounding    = 0,
        shadow      = { enabled = false },
        blur        = { enabled = false },
        dim_special = 0,  
    },

    animations = { enabled = false },  

    master = {
        new_status  = "slave",  -- callback = awful.client.setslave
        mfact       = 0.5,      -- master_width_factor 
        orientation = "left",
    },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = 0xff1a1a1a,
        font_family              = "Cantarell",
        key_press_enables_dpms   = true,  -- for scripts/turn_off_screen.sh
        mouse_move_enables_dpms  = true,
    },

    cursor   = { inactive_timeout = 5 },         -- unclutter -root
    xwayland = { force_zero_scaling = true },

    input = {
        kb_layout    = "us,ru",
        kb_options   = "grp:alt_shift_toggle",
        follow_mouse = 1,                         -- sloppy focus
        touchpad     = { natural_scroll = false },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- "No borders when rearranging only 1 non-floating or maximized client"
hl.window_rule({ match = { float = false, workspace = "w[tv1]s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1]s[false]" },   border_size = 0 })


-- LAYOUTS 
-- awful.layout.layouts.
local LAYOUTS = {
    { name = "floating", floating = true },
    { name = "tile",       layout = "master", orientation = "left" },
    { name = "tileleft",   layout = "master", orientation = "right" },
    { name = "tilebottom", layout = "master", orientation = "top" },
    { name = "tiletop",    layout = "master", orientation = "bottom" },
    { name = "spiral",     layout = "dwindle" },
}

local DEFAULT_LAYOUT = 2

local ws_layout, ws_rule = {}, {}
local LAYOUT_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-awm-layout"

local function ws_key(ws)
    if ws.id and ws.id > 0 then return tostring(ws.id) end
    return ws.special and ws.name or ("name:" .. ws.name)
end

local function cur_ws()
    return hl.get_active_special_workspace() or hl.get_active_workspace()
end

local function layout_of(ws)
    return LAYOUTS[ws_layout[ws_key(ws)] or DEFAULT_LAYOUT]
end

local function publish_layout()
    local ws = cur_ws()
    if not ws then return end
    local ok, f = pcall(function() return io.open(LAYOUT_FILE, "w") end)
    if ok and f then
        f:write(layout_of(ws).name, "\n")
        f:close()
    end
    hl.exec_cmd("pkill -RTMIN+8 waybar")
end

local function set_floating_all(ws, on)
    for _, w in ipairs(hl.get_windows({ workspace = ws }) or {}) do
        hl.dispatch(hl.dsp.window.float({ action = on and "set" or "unset", window = w }))
    end
end

local function set_layout(ws, idx)
    local key, prev = ws_key(ws), layout_of(ws)
    local L = LAYOUTS[idx]
    ws_layout[key] = idx
    if L.floating then
        set_floating_all(ws, true)
    else
        if prev.floating then set_floating_all(ws, false) end
        if ws_rule[key] then ws_rule[key]:set_enabled(false) end
        ws_rule[key] = hl.workspace_rule({
            workspace   = key,
            layout      = L.layout,
            layout_opts = L.orientation and { orientation = L.orientation } or nil,
        })
        hl.exec_scheduled_prop_refresh_immediately()
        if L.orientation then hl.dispatch(hl.dsp.layout("orientation" .. L.orientation)) end
    end
    publish_layout()
end

-- awful.layout.inc(d); d == 0 → awful.layout.set(layouts[1]). global call from waybar.
function awm_layout_inc(d)
    local ws = cur_ws()
    if not ws then return end
    if d == 0 then return set_layout(ws, 1) end
    local cur = ws_layout[ws_key(ws)] or DEFAULT_LAYOUT
    set_layout(ws, (cur - 1 + d) % #LAYOUTS + 1)
end

hl.on("window.open", function(w)
    local ws = w and w.workspace
    if ws and layout_of(ws).floating and not w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    end
end)

hl.on("workspace.active", publish_layout)
hl.on("workspace.special_active", publish_layout)
hl.on("monitor.focused", publish_layout)
publish_layout()

local function by_layout(t)
    return function()
        local ws = cur_ws()
        if not ws then return end
        local f = (layout_of(ws).floating and t.floating) or t[ws.tiled_layout] or t.default
        if f then f() end
    end
end

local function D(dsp) return function() hl.dispatch(dsp) end end

local function focus_cycle(next)
    return function()
        hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
    end
end


-- HELPERS 
-- Monitor Workarea
local function workarea(m)
    local r = m.reserved or {}
    local l, t, rr, b = r.left or 0, r.top or 0, r.right or 0, r.bottom or 0
    return m.x + l, m.y + t, m.width / m.scale - l - rr, m.height / m.scale - t - b
end

function awm_view_rel(d)
    local ws = hl.get_active_workspace()
    if ws and ws.id >= 1 and ws.id <= NTAGS then
        hl.dispatch(hl.dsp.focus({ workspace = tostring((ws.id - 1 + d) % NTAGS + 1), on_current_monitor = true }))
    else
        hl.dispatch(hl.dsp.focus({ workspace = d > 0 and "r+1" or "r-1" }))
    end
end

-- lain.util.move_tag: 
local function move_tag(d)
    return function()
        local a = hl.get_active_workspace()
        if not a or a.id < 1 or a.id > NTAGS then return end
        local t = tostring((a.id - 1 + d) % NTAGS + 1)
        local b = hl.get_workspace(t)
        local wa = hl.get_windows({ workspace = a }) or {}
        local wb = b and hl.get_windows({ workspace = b }) or {}
        for _, w in ipairs(wa) do hl.dispatch(hl.dsp.window.move({ window = w, workspace = t, follow = false })) end
        for _, w in ipairs(wb) do hl.dispatch(hl.dsp.window.move({ window = w, workspace = tostring(a.id), follow = false })) end
        hl.dispatch(hl.dsp.focus({ workspace = t, on_current_monitor = true }))
    end
end

-- "minimized" + awful.client.restore
local minimized = {}

local function minimize(w)
    w = w or hl.get_active_window()
    if not w then return end
    table.insert(minimized, w.address)
    hl.dispatch(hl.dsp.window.move({ window = w, workspace = "special:minimized", follow = false }))
end

local function restore_minimized()
    local ws = hl.get_active_workspace()
    while #minimized > 0 do
        local w = hl.get_window("address:" .. table.remove(minimized))
        if w and w.workspace and w.workspace.special then
            hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws }))
            hl.dispatch(hl.dsp.focus({ window = w }))
            return
        end
    end
end

-- CLick taskbar
function awm_tasklist_click(addr, button)
    if button ~= 1 then return end
    local w = hl.get_window("address:" .. addr)
    if not w then return end
    local a = hl.get_active_window()
    if a and a.address == w.address then
        minimize(w)
    else
        hl.dispatch(hl.dsp.focus({ window = w }))
        hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = w }))
    end
end

local function magnify()
    local w = hl.get_active_window()
    if not w then return end
    if w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "unset", window = w }))
        return
    end
    local _, _, aw, ah = workarea(w.monitor)
    local f = math.sqrt(0.5)
    hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    hl.dispatch(hl.dsp.window.resize({ window = w, x = math.floor(aw * f), y = math.floor(ah * f) }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
end

-- c.maximized_vertical / c.maximized_horizontal 
local saved_geom = {}
local function maximize_axis(vertical)
    return function()
        local w = hl.get_active_window()
        if not w then return end
        local key = w.address .. (vertical and "v" or "h")
        local g = saved_geom[key]
        if g then
            saved_geom[key] = nil
            hl.dispatch(hl.dsp.window.resize({ window = w, x = g.w, y = g.h }))
            hl.dispatch(hl.dsp.window.move({ window = w, x = g.x - w.at.x, y = g.y - w.at.y, relative = true }))
            return
        end
        if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = w })) end
        local at, size = w.at, w.size
        saved_geom[key] = { x = at.x, y = at.y, w = size.x, h = size.y }
        local ax, ay, aw, ah = workarea(w.monitor)
        if vertical then
            hl.dispatch(hl.dsp.window.resize({ window = w, x = size.x, y = math.floor(ah) }))
            hl.dispatch(hl.dsp.window.move({ window = w, x = 0, y = ay - at.y, relative = true }))
        else
            hl.dispatch(hl.dsp.window.resize({ window = w, x = math.floor(aw), y = size.y }))
            hl.dispatch(hl.dsp.window.move({ window = w, x = ax - at.x, y = 0, relative = true }))
        end
    end
end

local function ontop()
    local w = hl.get_active_window()
    if not w then return end
    if not w.floating then hl.dispatch(hl.dsp.window.float({ action = "set", window = w })) end
    hl.dispatch(hl.dsp.window.pin({ window = w }))
end

local function quake()
    if #(hl.get_windows({ class = "quake" }) or {}) == 0 then
        hl.exec_cmd(terminal .. " --class quake")
    end
    hl.dispatch(hl.dsp.workspace.toggle_special("quake"))
end


-- KEYBINDINGS
local function bind(keys, action, desc, flags)
    flags = flags or {}
    flags.description = desc
    return hl.bind(keys, action, flags)
end
local exec = hl.dsp.exec_cmd

-- hotkeys
bind("CTRL + space",       exec("makoctl dismiss --all"),        "hotkeys: destroy all notifications")
bind(ALT .. " + P",        exec(scripts .. "/screenshot.sh"),    "hotkeys: take a screenshot (area)")
bind("Print",              exec(scripts .. "/screenshot.sh full"), "hotkeys: take a screenshot (screen)")
bind(ALT .. " + CTRL + L", exec("loginctl lock-session"),        "hotkeys: lock screen")
bind(MOD .. " + C",        exec("wl-paste --primary --no-newline | wl-copy"), "hotkeys: copy terminal to gtk")
bind(MOD .. " + V",        exec("wl-paste --no-newline | wl-copy --primary"), "hotkeys: copy gtk to terminal")
-- #123/#122/#121
bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "hotkeys: volume up",   { locked = true, repeating = true })
bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "hotkeys: volume down", { locked = true, repeating = true })
bind("XF86AudioMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "hotkeys: toggle mute", { locked = true })
-- brightness
bind("XF86MonBrightnessUp",   exec("brightnessctl -e4 -n2 set 5%+"), "hotkeys: brightness +5%", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", exec("brightnessctl -e4 -n2 set 5%-"), "hotkeys: brightness -5%", { locked = true, repeating = true })

-- awesome
bind(MOD .. " + S",          exec(scripts .. "/hotkeys.sh"), "awesome: show help")
bind(MOD .. " + W",          exec("rofi -show drun"),        "awesome: show main menu")
bind(MOD .. " + B",          exec("pkill -SIGUSR1 waybar"),  "awesome: toggle wibox")
bind(MOD .. " + CTRL + R",   exec("hyprctl reload"),         "awesome: reload")
bind(MOD .. " + SHIFT + Q",  exec("command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), "awesome: quit")

-- tag
bind(MOD .. " + left",   function() awm_view_rel(-1) end,                 "tag: view previous")
bind(MOD .. " + right",  function() awm_view_rel(1) end,                  "tag: view next")
bind(MOD .. " + Escape", hl.dsp.focus({ workspace = "previous" }),        "tag: go back")
bind(MOD .. " + SHIFT + N",     hl.dsp.focus({ workspace = "emptynm" }),  "tag: add new tag")
bind(MOD .. " + SHIFT + R",     exec(scripts .. "/rename-workspace.sh"),  "tag: rename tag")
bind(MOD .. " + SHIFT + left",  move_tag(-1),                             "tag: move tag to the left")
bind(MOD .. " + SHIFT + right", move_tag(1),                              "tag: move tag to the right")
-- root.buttons 4/5 
bind(MOD .. " + mouse_up",   function() awm_view_rel(1) end,  "tag: view next")
bind(MOD .. " + mouse_down", function() awm_view_rel(-1) end, "tag: view previous")

-- Теги по keycode (#i+9), как в rc.lua — работают в любой раскладке.
-- Нет аналогов: MOD+CTRL+i (показать несколько тегов) и MOD+CTRL+SHIFT+i (окно на нескольких тегах).
for i = 1, NTAGS do
    local code = "code:" .. (i + 9)
    bind(MOD .. " + " .. code,           hl.dsp.focus({ workspace = tostring(i), on_current_monitor = true }), "tag: view tag #" .. i)
    bind(MOD .. " + SHIFT + " .. code,   hl.dsp.window.move({ workspace = tostring(i), follow = false }),      "tag: move focused client to tag #" .. i)
end

-- client
bind(MOD .. " + J", by_layout({ master = D(hl.dsp.layout("cyclenext")), default = focus_cycle(true) }),  "client: focus next by index")
bind(MOD .. " + K", by_layout({ master = D(hl.dsp.layout("cycleprev")), default = focus_cycle(false) }), "client: focus previous by index")
bind(MOD .. " + SHIFT + J", by_layout({ master = D(hl.dsp.layout("swapnext")), default = D(hl.dsp.window.swap({ next = true })) }), "client: swap with next client by index")
bind(MOD .. " + SHIFT + K", by_layout({ master = D(hl.dsp.layout("swapprev")), default = D(hl.dsp.window.swap({ prev = true })) }), "client: swap with previous client by index")
bind(MOD .. " + U",          hl.dsp.focus({ urgent_or_last = true }), "client: jump to urgent client")
bind(MOD .. " + Tab", function()
    hl.dispatch(hl.dsp.focus({ last = true }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end, "client: cycle with previous/go back")
bind(MOD .. " + CTRL + N",       restore_minimized,                                "client: restore minimized")
bind(ALT .. " + SHIFT + M",      magnify,                                          "client: magnify client")
bind(MOD .. " + F",              hl.dsp.window.fullscreen({ mode = "fullscreen" }), "client: toggle fullscreen")
bind(MOD .. " + SHIFT + C",      hl.dsp.window.close(),                            "client: close")
bind(MOD .. " + CTRL + space",   hl.dsp.window.float(),                            "client: toggle floating")
bind(MOD .. " + CTRL + Return",  by_layout({ master = D(hl.dsp.layout("swapwithmaster")) }), "client: move to master")
bind(MOD .. " + O",              hl.dsp.window.move({ monitor = "+1" }),           "client: move to screen")
bind(MOD .. " + CTRL + T",       ontop,                                            "client: toggle keep on top")
bind(MOD .. " + N",              function() minimize() end,                        "client: minimize")
bind(MOD .. " + M",              hl.dsp.window.fullscreen({ mode = "maximized" }), "client: (un)maximize")
bind(MOD .. " + CTRL + M",       maximize_axis(true),                              "client: (un)maximize vertically")
bind(MOD .. " + SHIFT + M",      maximize_axis(false),                             "client: (un)maximize horizontally")
-- clientbuttons
bind(MOD .. " + mouse:272", hl.dsp.window.drag(),   "client: move (mouse)",   { mouse = true })
bind(MOD .. " + mouse:273", hl.dsp.window.resize(), "client: resize (mouse)", { mouse = true })

-- screen
bind(MOD .. " + CTRL + J", hl.dsp.focus({ monitor = "+1" }), "screen: focus the next screen")
bind(MOD .. " + CTRL + K", hl.dsp.focus({ monitor = "-1" }), "screen: focus the previous screen")

-- layout (incncol for MOD+CTRL+H/L no in Hyprland)
bind(MOD .. " + L", by_layout({ master = D(hl.dsp.layout("mfact +0.05")), dwindle = D(hl.dsp.layout("splitratio +0.05")) }), "layout: increase master width factor")
bind(MOD .. " + H", by_layout({ master = D(hl.dsp.layout("mfact -0.05")), dwindle = D(hl.dsp.layout("splitratio -0.05")) }), "layout: decrease master width factor")
bind(MOD .. " + SHIFT + H", by_layout({ master = D(hl.dsp.layout("addmaster")) }),    "layout: increase the number of master clients")
bind(MOD .. " + SHIFT + L", by_layout({ master = D(hl.dsp.layout("removemaster")) }), "layout: decrease the number of master clients")
bind(MOD .. " + space",         function() awm_layout_inc(1) end,  "layout: select next")
bind(MOD .. " + SHIFT + space", function() awm_layout_inc(-1) end, "layout: select previous")

-- launcher
bind(MOD .. " + T", exec(terminal),                       "launcher: open a terminal")
bind(MOD .. " + Z", quake,                                "launcher: dropdown application")
bind(MOD .. " + Q", exec(browser),                        "launcher: run browser")
bind(MOD .. " + R", exec("rofi -modes run -show run"),    "launcher: show rofi")
bind(MOD .. " + X", exec("rofi -show run -p 'Run:'"),     "launcher: run prompt")


-- WINDOWS AND WORKSPACES 
-- Floating clients из awful.rules (Arandr → nwg-displays, Sxiv → nsxiv/imv, xev → wev)
hl.window_rule({
    name  = "awesome-floating",
    match = { class = [[^(arandr|nwg-displays|[Bb]lueman-manager|\.blueman-manager-wrapped|[Gg]pick|kruler|[Ss]xiv|nsxiv|imv|[Pp]inentry.*|gcr-prompter|[Ww]pa_gui|xtightvncviewer|com\.github\.hluk\.copyq|org\.pulseaudio\.pavucontrol|nm-connection-editor)$]] },
    float = true,
})
hl.window_rule({ name = "event-tester", match = { title = "^Event Tester$" }, float = true })

hl.window_rule({
    name      = "quake",
    match     = { class = "^quake$" },
    float     = true,
    size      = { "monitor_w", "monitor_h * 0.25" },
    move      = { 0, 18 },
    workspace = "special:quake",
})

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
