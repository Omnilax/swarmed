-- Amber and the Burrow (src/game/amber.lua, src/states/burrow.lua).
--   love . --selftest --amber
-- A run pays amber by what it did, once; packs, maps and modes stay locked until bought; a
-- bought pack's items join the item choices; veterans get a head start; the Burrow buys on the
-- second press; the defeat screen shows what the run paid.
local State = require("src.core.state")
local Settings = require("src.core.settings")

return function(wait, shot)
    local Amber = require("src.game.amber")
    local Unlocks = require("src.game.unlocks")
    local Records = require("src.game.records")
    local Cosmetics = require("src.game.cosmetics")
    local savedFree = Unlocks.free
    Unlocks.free = false
    Settings.set("unlockAll", false)
    local p = Records.get()
    local saved = { p.amber, p.amberEarned, p.amberOwned, p.amberStarted, p.runs, p.modes }
    p.amberStarted, p.amber, p.amberEarned, p.amberOwned, p.runs, p.modes = false, 0, 0, {}, 0, {}

    -- a fresh save starts with none; a run pays by what it did
    assert(Amber.balance() == 0, "a new save starts with no amber")
    local run = { wavesCleared = 6, queens = 1, elites = 25, kills = 450, won = false, mode = "colony" }
    assert(Amber.earned(run) == 6 * 2 + 4 + 2 + 2, "amber for a run: " .. Amber.earned(run))
    assert(Amber.earned({ wavesCleared = 15, queens = 3, elites = 0, kills = 0, won = true, mode = "colony" }) == 30 + 12 + 20, "a win pays the bonus")
    assert(Amber.earned({ wavesCleared = 1, queens = 0, elites = 0, kills = 3, mode = "colony" }) == 2, "one wave")
    assert(Amber.earned({ wavesCleared = 10, mode = "custom" }) == 10, "custom waves pay half")
    assert(Amber.award(run) == 20 and Amber.award(run) == 20 and Amber.balance() == 20, "a run pays once")

    -- locked until bought
    assert(not Amber.itemOpen("lichen") and not Unlocks.inPool("lichen"), "Fungal Finds items start locked")
    assert(Unlocks.inPool("chitin_plate"), "items in no pack are open")
    assert(not Amber.stageOpen("sandstone_wash") and Amber.stageOpen("backyard"), "maps: backyard open, sandstone locked")
    for _, s in ipairs(Cosmetics.locations()) do assert(Amber.stageOpen(s.id), "a locked map is offered: " .. s.id) end
    assert(Amber.stageOpen(Cosmetics.location()), "the run location must be an open map")
    assert(not Amber.modeOpen("endless") and Amber.modeOpen("colony"), "modes: colony open, endless locked")
    p.modes.endless = { runs = 2, wins = 0, bestWave = 4 }
    assert(Amber.modeOpen("endless"), "a mode played before amber stays open")
    p.modes.endless = nil
    assert(Amber.next() and Amber.next().id == "pack_thorns", "cheapest next: " .. tostring(Amber.next() and Amber.next().id))

    -- buying
    assert(not Amber.buy("pack_microbes"), "can't buy with too little")
    p.amber = 100
    assert(Amber.buy("pack_fungus") and Amber.balance() == 70, "bought Fungal Finds")
    assert(not Amber.buy("pack_fungus"), "can't buy twice")
    assert(Unlocks.inPool("lichen") and Unlocks.inPool("mycelium"), "bought items join the pool")
    assert(Unlocks.free == false)
    Settings.set("unlockAll", true)
    assert(Amber.modeOpen("mayhem") and Amber.stageOpen("forest_floor"), "Unlock Everything opens it all")
    Settings.set("unlockAll", false)

    -- veterans get a head start, once
    p.amberStarted, p.amber, p.amberEarned, p.runs = false, 0, 0, 40
    assert(Amber.balance() == 200, "40 runs: 200 amber head start (" .. Amber.balance() .. ")")
    assert(Amber.balance() == 200, "only once")

    -- the Burrow: first press asks, second buys, with its moment
    local B = State.push(require("src.states.burrow").new())
    local item
    for i, it in ipairs(B.menu.items) do if it.unlock and it.unlock.id == "stage_forest_floor" then item, B.menu.focus = it, i end end
    wait(0.2)
    shot("burrow")
    item.onActivate()
    assert(B.confirm and not Amber.owns("stage_forest_floor"), "first press only asks")
    item.onActivate()
    assert(Amber.owns("stage_forest_floor") and Amber.balance() == 150, "second press buys")
    wait(0.4)
    shot("burrow_unlocked")
    State.pop()

    -- the defeat screen names what the run paid
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    wait(0.3)
    local r = Records.run
    r.wavesCleared, r.queens, r.kills = 4, 0, 1
    game.world.player.hp = 0
    Records.endRun("died")
    assert(r.amber == 8, "the run should pay 8 amber (" .. tostring(r.amber) .. ")")
    local line = Amber.runLine(game.world)
    assert(line and line:find("+8 amber"), "results line: " .. tostring(line))
    State.push(require("src.states.gameover").new(game))
    wait(0.8)
    shot("amber_gameover")

    State.switch(require("src.states.menu").new())
    wait(0.5)
    shot("amber_menu")
    p.amber, p.amberEarned, p.amberOwned, p.amberStarted, p.runs, p.modes = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
    Unlocks.free = savedFree
    print("[selftest] amber ok")
end
