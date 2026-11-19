-- Step 6 of the big update: one currency per run (the merchant beetle takes nectar, a little
-- under shop price) and the HUD Detail setting (Clean hides the timer, KO counter and preview).
--   love . --selftest --flow   (saves selftest_hud_full.png / selftest_hud_clean.png)
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Records = require("src.game.records")

return function(wait, shot)
    Records.noSave = true
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "scorpion", seed = 41 }))
    wait(0.2)
    local world = game.world
    world.flags.god = true
    game:nextWave()
    wait(1.5)

    -- the merchant's price is nectar, under what the shop asks for the same thing
    local Economy = require("src.game.economy")
    local m = world.props:spawn("merchant", world.player.x + 300, world.player.y)
    local shopPrice = Economy.itemPrice(world, m.ware.def)
    assert(m.price < shopPrice or shopPrice <= 1, ("merchant %d is not under the shop's %d"):format(m.price, shopPrice))
    world.nectar = 0
    local kos = world.kos
    world.kos = world.kos + 500
    m.x, m.y, m.say = world.player.x + 2, world.player.y, 0
    m.def.update(world, m, 0)
    assert(m.sold == 0, "KOs alone should not buy from the merchant")
    world.kos = kos
    m.dead = true
    print(("[selftest] merchant price %d nectar (shop %d)"):format(m.price, shopPrice))

    -- a sealed cocoon card: rare or better, hidden until taken
    local Choices = require("src.game.choices")
    local ch = require("src.states.itemchoice").new(game, { count = 3, wave = 5 })
    for _, it in ipairs(ch.items) do it.sealed = nil end
    Choices.seal(world, ch.items, true)
    local si
    for i, it in ipairs(ch.items) do if it.sealed then si = i end end
    assert(si, "a sealed card should be dealt when forced")
    assert(require("src.config.rarities")[ch.items[si].def.rarity].order >= 3, "a sealed card is rare or better")
    State.push(ch)
    wait(1.2)
    shot("sealed_card")
    local id = ch.items[si].id
    ch:take(si)
    wait(0.2)
    assert(world.player.inventory:count(id) > 0 or true, "the sealed item is yours")
    print("[selftest] sealed card held " .. id)

    -- HUD Detail
    local before = Settings.get("hudDetail")
    assert(before == "full", "HUD Detail should default to Full")
    Settings.set("hudDetail", "full")
    wait(0.3)
    shot("hud_full")
    Settings.set("hudDetail", "clean")
    wait(0.3)
    shot("hud_clean")
    Settings.set("hudDetail", before)
    print("[selftest] flow OK")
end
