-- Bug Creator round 4:  love . --selftest --creator4
-- The creator menus no longer slide under the mouse (deleting a bug with clicks works), and the
-- round 4 API: resources (ammo), stances, abilities, evolution, traits, the read API, parry,
-- onDeath revive, onHud / onDraw. Saves selftest_c4_*.png.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    local CustomBugs = require("src.game.custombugs")
    local SM = require("src.game.scriptmoves")
    local World = require("src.game.world")
    local Menu = require("src.ui.menu")

    -- 1. a hovered row that is cut off at the bottom no longer scrolls the list
    local items = {}
    for i = 1, 40 do items[i] = { type = "button", label = "Row " .. i, onActivate = function() end } end
    local m = Menu.new({ items = items, rect = function() return 0, 0, 300, 380 end })
    local rh = m:rowH()
    local lastY = math.floor(380 / rh) * rh + 2          -- inside the half-shown last row
    m:mousemoved(10, lastY)
    for _ = 1, 5 do m:update(1 / 60) end
    assert(m.scroll == 0, "hovering the cut-off row scrolled the menu (" .. m.scroll .. ")")
    m:move(1)                                             -- the keys still scroll to the focus
    for _ = 1, 20 do m:move(1) end
    m:update(1 / 60)
    assert(m.scroll > 0, "keyboard focus should still scroll")
    print("[selftest] creator4: hover keeps the list still")

    -- 2. deleting a custom bug with two clicks in the Bug Creator
    local oldDir, oldNo = CustomBugs.dir, CustomBugs.noSave
    CustomBugs.dir, CustomBugs.noSave = "selftest_custom_bugs4", false
    love.filesystem.createDirectory(CustomBugs.dir)
    for _, f in ipairs(love.filesystem.getDirectoryItems(CustomBugs.dir)) do love.filesystem.remove(CustomBugs.dir .. "/" .. f) end
    for i = 1, 6 do assert(CustomBugs.save(([[return { name = "Click Bug %d", look = "mantis" }]]):format(i))) end
    local hub = State.switch(require("src.states.creator").new())
    wait(0.2)
    local function rowY(pred)
        local x, y = hub.menu:rect()
        for i, it in ipairs(hub.menu.items) do
            if pred(it) then return x + 20, y + (i - 1) * hub.menu:rowH() - hub.menu.scroll + hub.menu:rowH() / 2, i end
        end
    end
    local function click(pred)
        local _, top, _, hgt = hub.menu:rect()
        local x, y = rowY(pred)
        -- scrolled out of view: wheel it in, as a player would
        while x and y > top + hgt - 10 do hub:wheelmoved(0, -1) x, y = rowY(pred) end
        if not x then for _, it in ipairs(hub.menu.items) do print("ROW", it.label, it.bugId) end end
        assert(x, "row not found")
        hub:mousemoved(x, y)
        hub:mousepressed(x, y, 1)
        hub:update(1 / 60)
        hub:mousemoved(x, y)
        hub:update(1 / 60)
        return x, y
    end
    local target = "custom_click_bug_6"
    hub:wheelmoved(0, -20)              -- scroll to the bottom with the wheel, as a player would
    click(function(it) return it.bugId == target end)
    local cx, cy = click(function(it) return it.entry and it.entry.id == target and it.label:find("Delete") end)
    local under = hub.menu.items[hub.menu:itemAt(cx, cy) or 0]
    assert(under and under.label:find("Press again"), "the confirm row should stay under the cursor")
    shot("c4_delete_confirm")
    click(function(it) return it.entry and it.entry.id == target and it.label:find("Press again") end)
    assert(not Content.characters:get(target), "two clicks on Delete should delete the bug")
    print("[selftest] creator4: delete by mouse works")
    for i = 1, 5 do CustomBugs.delete("custom_click_bug_" .. i) end
    CustomBugs.dir, CustomBugs.noSave = oldDir, oldNo

    -- 3. the Gunner Beetle example builds with no warnings
    local src = love.filesystem.read("content/characters/_example_gunner_beetle.lua")
    local def, info = CustomBugs.compile(src, "gunner")
    assert(def, "gunner: " .. tostring(info.errors and info.errors[1]))
    for _, w in ipairs(info.warnings or {}) do print("[selftest] warn: " .. w) end
    assert(#info.warnings == 0, "gunner warned: " .. tostring(info.warnings[1]))
    assert(def.evolution and #def.evolution == 3 and def.stances and #def.stances == 2 and def.abilities and #def.abilities == 2
        and def.resources and def.resources.ammo and def.traits and #def.traits == 2, "gunner systems missing")
    CustomBugs.prepareArt(def)
    CustomBugs.register(def, src)

    -- 4. fight with it: ammo, reload, stance key, ability buttons, evolution by level
    local w = World.new({ mode = "sandbox", character = def.id })
    w.pilot = { pressed = {}, down = {} }
    local p = w.player
    w.flags.god = true
    local limbs0 = #(p.model and p.model.restLimbs or {})
    local sawEmpty, sawReload, sawBrawl, sawAbility = false, false, false, false
    for f = 1, 900 do
        if f % 45 == 1 then w:spawnRing("worker_ant", 8, p.x, p.y, 90) end
        w.pilot.down = { attack = true, ability = f == 500 or f == 501, g = f == 600 }
        w.pilot.pressed = { stance = f == 300 or f == 400 }
        w:update(1 / 60)
        local r = p.res and p.res.ammo
        if r and r.cur < 1 then sawEmpty = true end
        if r and r.reloadT then sawReload = true end
        if p.stanceIndex == 2 then sawBrawl = true end
        if p.abil and p.abil[1] and p.abil[1].cd > 0 then sawAbility = true end
        if f == 200 then love.graphics.origin() w:draw() end
    end
    assert(not SM.errors[def.id], "gunner script error: " .. tostring(SM.errors[def.id]))
    assert(sawEmpty and sawReload, "ammo should run out and reload")
    assert(sawBrawl and p.stanceIndex == 1, "the stance key should switch to Brawl and back")
    assert(sawAbility, "the ability button should fire")
    assert(p.parryT == nil or p.parryT <= 0.35, "parry window")
    -- level up: horns at 3, claws at 6, the cannon at 10
    local Skills = require("src.game.skills")
    while p.skills.level < 10 do p.skills:gainXP(Skills.xpFor(p.skills.level + 1), true) w:update(1 / 60) end
    w:update(1 / 60)
    assert(p.evoStage == 3, "evolution should reach stage 3 at level 10 (got " .. tostring(p.evoStage) .. ")")
    assert(p.def.secondary and p.def.secondary.name == "Cannon", "stage 3 brings the cannon")
    local limbs1 = #(p.model and p.model.restLimbs or {})
    assert(limbs1 > limbs0, ("evolving should add limbs (%d -> %d)"):format(limbs0, limbs1))
    assert(p.def.scale > 1.1, "stage 2 grows the bug")
    print(("[selftest] creator4: gunner fought, reloaded, switched stance, evolved (limbs %d -> %d)"):format(limbs0, limbs1))

    -- 5. parry and revive
    w.flags.god = false
    p.iframes = 0
    p.parryT = 0.3
    local hp = p.hp
    p:hurt(30, { x = p.x + 10, y = p.y })
    assert(p.hp == hp, "a parried hit should do nothing")
    p.iframes = 0
    p:hurt(99999, { x = p.x + 10, y = p.y })
    assert(not p.dead and p.hp > 0, "Last Stand should revive once")
    p.iframes = 0
    p:hurt(99999, { x = p.x + 10, y = p.y })
    assert(p.dead, "only once")
    print("[selftest] creator4: parry and revive OK")
    State.switch(require("src.states.game").new({ mode = "sandbox", character = def.id }))
    wait(1.2)
    shot("c4_gunner_hud")
    CustomBugs.unregister(def.id)

    -- 6. the read API: every field and function answers from a hook
    local probe = assert(CustomBugs.compile([[return { name = "Probe Bug", look = "mantis",
        resources = { heat = { max = 50, start = 0, regen = 5 } },
        hooks = { onTick = function(me, dt)
            local s = me.state
            s.n = (s.n or 0) + 1
            s.ok = type(me.vx) == "number" and type(me.speedNow) == "number" and type(me.facing) == "number"
                and type(me.facingX) == "number" and type(me.kills) == "number" and type(me.combo) == "number"
                and type(me.nectar) == "number" and type(me.spree) == "number" and type(me.level) == "number"
                and type(me.hpFrac) == "number" and type(me.stage) == "number" and type(me.xp) == "number"
            local cx, cy = me.cursor()
            s.cursor = type(cx) == "number" and type(cy) == "number"
            s.facing = type(me.isFacing(me.x + 10, me.y)) == "boolean" and type(me.facingCursor()) == "boolean"
            local wv = me.waveInfo()
            s.wave = type(wv.number) == "number" and type(wv.alive) == "number"
            local run = me.run()
            s.run = type(run.kills) == "number" and type(run.frenzy) == "number"
            s.near = type(me.enemiesNear(200)) == "table" and type(me.propsNear(200)) == "table" and type(me.pickupsNear(200)) == "table"
            s.stat = me.stat("maxHp") ~= nil and me.stat("nope") == nil
            s.items = type(me.items()) == "table" and type(me.status()) == "table" and type(me.cooldowns()) == "table"
            s.heat = me.res("heat")
            s.input = type(me.keyDown("1")) == "boolean" and type(me.action("attack")) == "boolean"
            me.buff("moveSpeed", 10, 0, 0.5, "probe")
            s.emit = me.emit("onMine", { a = 1 })
        end, onMine = function(me, ev) return ev.a + 1 end,
        onKill = function(me, ev) me.state.killId = ev.id end } } ]]))
    CustomBugs.register(probe, "")
    local pw = World.new({ mode = "sandbox", character = probe.id })
    pw.flags.god = true
    pw.pilot = { pressed = {}, down = { attack = true } }
    for f = 1, 240 do
        if f % 40 == 1 then pw:spawnRing("worker_ant", 6, pw.player.x, pw.player.y, 30) end
        pw:update(1 / 60)
    end
    assert(not SM.errors[probe.id], "probe error: " .. tostring(SM.errors[probe.id]))
    local s = pw.player._me.state
    for _, k in ipairs({ "ok", "cursor", "facing", "wave", "run", "near", "stat", "items", "input" }) do
        assert(s[k] == true, "read API: " .. k)
    end
    assert(s.heat and s.heat > 5, "heat should regen")
    assert(s.emit == 2, "me.emit should call the bug's own hook and return its value")
    assert(s.killId, "onKill ev.id")
    print(("[selftest] creator4: read API OK (%d ticks)"):format(s.n))
    CustomBugs.unregister(probe.id)
    print("[selftest] creator4 OK")
end
