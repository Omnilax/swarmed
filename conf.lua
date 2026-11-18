-- LÖVE configuration. Window size and mode are re-applied from saved settings in main.lua.
function love.conf(t)
    t.identity = "swarmed"
    t.version = "11.4"
    t.console = false

    t.window.title = "Swarmed"
    t.window.icon = "assets/icon/icon_256.png"   -- taskbar / dock / window icon (tools/make_icons.py)
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.vsync = 1
    t.window.highdpi = false

    t.modules.physics = false
    t.modules.video = false
end
