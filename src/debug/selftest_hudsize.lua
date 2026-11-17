-- HUD Size: the in-run HUD draws at Theme.hudZoom() (Settings "HUD Size"), text everywhere at
-- Theme.TEXT_SCALE, and the species a wave introduces gets the compact card at the left edge.
--   love . --selftest --hudsize   (saves selftest_hud_*.png)
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Records = require("src.game.records")
local Theme = require("src.ui.theme")

return function(wait, shot)
    Records.noSave = true
    -- the zoom scales text and layout units together, and nests
    local f1, u1 = Theme.font(20):getHeight(), Theme.u(100)
    Theme.pushZoom(0.5)
    assert(math.abs(Theme.u(100) - u1 * 0.5) < 0.01, "zoom does not scale layout units")
    assert(Theme.font(20):getHeight() < f1, "zoom does not shrink text")
    Theme.pushZoom(0.5)
    assert(math.abs(Theme.u(100) - u1 * 0.25) < 0.01, "zoom does not nest")
    Theme.popZoom()
    Theme.popZoom()
    assert(Theme.zoom == 1 and Theme.u(100) == u1, "zoom not restored")

    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "scorpion", seed = 777 }))
    wait(0.2)
    local world = game.world
    world.flags.god = true
    game:nextWave()
    local sp = world.spawner
    -- wait (in game time) for the wave's new species to walk in and its card to come up
    local st
    for _ = 1, 600 do
        wait(1 / 60)
        st = world._runHud
        if st and st.cur and st.cur.label and (st.cur.wait or 0) <= 0 and st.cur.t > 0.5 then break end
    end
    assert(st and st.cur and st.cur.label, "the wave's new species got no card")
    assert(sp.newSpecies == st.cur.def, "card is not the wave's species")
    print("[selftest] intro card: " .. st.cur.label .. " / " .. st.cur.def.name)
    assert(Theme.zoom == 1, "HUD zoom leaked out of Game:draw")
    for _, pct in ipairs({ 75, 100 }) do
        Settings.set("hudScale", pct)
        wait(0.05)
        shot("hud_" .. pct)
    end
    Settings.set("hudScale", 75)
    -- a phone in landscape (the web build passes --mobile): bigger reference, touch buttons
    local Touch = require("src.core.touch")
    local ww, wh, wflags = love.window.getMode()
    local ref, mobile = Theme.refHeight, Touch.mobile
    Theme.refHeight, Touch.mobile = 480, true
    Settings.set("touchControls", "on")
    love.window.setMode(844, 390, wflags)
    wait(0.1)
    shot("hud_phone")
    love.window.setMode(ww, wh, wflags)
    Theme.refHeight, Touch.mobile = ref, mobile
    Settings.set("touchControls", "auto")
    print("[selftest] hud size OK")
end
