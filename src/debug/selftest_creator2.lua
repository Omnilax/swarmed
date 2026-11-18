-- Bug Creator round 3 and the tidied menus:  love . --selftest --creator2
-- Saves selftest_c2_*.png.
local State = require("src.core.state")
local Content = require("src.content")

return function(wait, shot)
    -- 1. main menu: short main page, Collection page, Continue on top when a run is saved
    local RunSave = require("src.game.runsave")
    local peek, describe = RunSave.peek, RunSave.describe
    RunSave.peek = function() return { fake = true } end
    RunSave.describe = function() return "Mantis, wave 7" end
    local mm = State.switch(require("src.states.menu").new())
    wait(0.4)
    shot("c2_menu_saved")
    local labels = {}
    for _, it in ipairs(mm.menu.items) do labels[#labels + 1] = it.label end
    assert(labels[1]:find("^Continue"), "a saved run should be the first row")
    assert(labels[2] == "New Run", "Play reads New Run when a run is saved")
    assert(#mm.menu.items <= 9, "the main page should stay short, has " .. #mm.menu.items)
    RunSave.peek, RunSave.describe = peek, describe
    mm:buildItems()
    assert(mm.menu.items[1].label == "Play", "no save -> Play first")
    local col
    for _, it in ipairs(mm.menu.items) do if it.label:find("^Collection") then col = it end end
    col.onActivate()
    wait(0.3)
    shot("c2_menu_collection")
    local names = {}
    for _, it in ipairs(mm.menu.items) do names[it.label] = true end
    assert(names["Bug Catalogue"] and names["Item Catalogue"] and names["Records"] and names["Cosmetics"] and names["Back"],
        "Collection lists the catalogues, records and cosmetics")
    mm.menu.opts.onBack()
    assert(mm.menu:focused().label:find("^Collection"), "Back lands on the Collection row")

    -- 2. mode select: grouped under headings
    local ms = State.push(require("src.states.modeselect").new())
    wait(0.3)
    shot("c2_modeselect")
    local heads = 0
    for _, it in ipairs(ms.menu.items) do if it.type == "header" then heads = heads + 1 end end
    assert(heads == 3, "three mode headings, got " .. heads)
    assert(ms.menu:focused() and ms.menu:focused().mode, "focus starts on a mode")
    State.pop()

    -- 3. hitbox shapes: pure geometry first
    local HS = require("src.game.hitshapes")
    local CustomBugs = require("src.game.custombugs")
    local SM = require("src.game.scriptmoves")
    local World = require("src.game.world")
    local function inside(t, f, sd) return (HS.inside(HS.shape(t), f, sd, 0)) end
    assert(inside({ shape = "circle", radius = 20 }, 10, 10) and not inside({ shape = "circle", radius = 20 }, 20, 20), "circle")
    assert(inside({ shape = "arc", radius = 40, degrees = 90 }, 30, 5) and not inside({ shape = "arc", radius = 40, degrees = 90 }, 5, 30), "arc")
    assert(not inside({ shape = "arc", radius = 40, degrees = 90, inner = 20 }, 10, 0), "arc inner")
    assert(inside({ shape = "ring", radius = 40, inner = 20 }, 0, -30) and not inside({ shape = "ring", radius = 40, inner = 20 }, 5, 0), "ring")
    assert(inside({ shape = "box", length = 60, width = 20 }, 50, 9) and not inside({ shape = "box", length = 60, width = 20 }, 50, 12), "box")
    assert(not inside({ shape = "box", length = 60, width = 20 }, -5, 0) and inside({ shape = "box", length = 60, width = 20, back = 10 }, -5, 0), "box back")
    local tri = { shape = "poly", points = { { 0, -10 }, { 40, 0 }, { 0, 10 } } }
    assert(inside(tri, 10, 0) and not inside(tri, 35, 8), "poly")

    -- 4. me.hit in a real fight: every shape, wind-ups, active sweeps, sweet spots, callbacks
    local hb = assert(CustomBugs.compile([[return { name = "Hitbox Bug", look = "mantis",
        hitFx = { number = "#80ff80", sparks = { color = "#80ff80", count = 3 } },
        attack = { type = "scripted", cooldown = 0.25, fire = function(me)
            me.state.n = (me.state.n or 0) + 1
            local k = me.state.n % 7
            local cb = function(me, ev) me.state.cb = (me.state.cb or 0) + 1 if ev.sweet then me.state.sweet = true end end
            if k == 0 then me.hit({ shape = "arc", radius = 60, degrees = 160, damage = 4, sweet = { from = 0.6, mult = 2, text = "TIP" }, onHit = cb, hitstop = 0.03, shake = 0.05 })
            elseif k == 1 then me.hit({ shape = "box", length = 70, width = 30, damage = 4, kb = "side", onHit = cb })
            elseif k == 2 then me.hit({ shape = "ring", radius = 60, inner = 20, damage = 4, onHit = cb, number = "#ff60ff" })
            elseif k == 3 then me.hit({ shape = "poly", points = { { -10, -20 }, { 60, 0 }, { -10, 20 } }, damage = 4, onHit = cb, stagger = 0.3 })
            elseif k == 4 then me.hit({ shape = "circle", radius = 30, ahead = 30, windup = 0.2, damage = 4, onHit = cb, kb = "in" })
            elseif k == 5 then me.hit({ shape = "arc", radius = 60, degrees = 30, active = 0.3, sweep = { -1.5, 1.5 }, follow = true, damage = 3, onHit = cb })
            else me.hit({ shape = "line", length = 90, width = 5, active = 0.4, rehit = 0.1, damage = 1, onHit = cb, debug = true }) end
        end } } ]]))
    assert(hb.hitLook and hb.hitLook.number, "hitFx lost")
    CustomBugs.register(hb, "")
    local w = World.new({ mode = "sandbox", character = hb.id })
    w.flags.god = true
    w.pilot = { pressed = {}, down = {} }
    local p = w.player
    for f = 1, 600 do
        if f % 30 == 1 then w:spawnRing("worker_ant", 10, p.x, p.y, 40) end
        w.pilot.down = { attack = true }
        w:update(1 / 60)
        if f == 200 or f == 260 then love.graphics.origin() w:draw() end
    end
    assert(not SM.errors[hb.id], "me.hit failed: " .. tostring(SM.errors[hb.id]))
    local st = p._me.state
    assert((st.n or 0) >= 14 and (st.cb or 0) > 20 and st.sweet, ("me.hit did not land (%s swings, %s hits, sweet %s)"):format(tostring(st.n), tostring(st.cb), tostring(st.sweet)))
    print(("[selftest] creator2: me.hit ok (%d swings, %d contacts)"):format(st.n, st.cb))
    CustomBugs.unregister(hb.id)

    -- 5. everything else in one bug: move blocks, combos, forms, molt, pets, statuses, ultimate,
    -- hit look, sound pack, poses, card, challenges, wings and feelers
    local big, binfo = CustomBugs.compile([[
local PAL = { o = "#201810", a = "#6a8a40", b = "#9ac060", c = "#d0f090" }
return { name = "Kitchen Sink", playstyle = "brawler",
  art = { palette = PAL, body = { ".oooo.", "obbbbo", "obccbo", "obbbbo", ".oooo." },
          legs = { { 0, 1, 1, 3, 2, 5 } }, wings = { size = 4, color = "#d0e8ff" }, antennae = { length = 6 } },
  stats = { maxHp = 80 },
  hitFx = { number = "#90ff90", crit = "#ffe060", sparks = { color = "#90ff90", count = 3 }, sound = "zap" },
  soundPack = { attack = "swing", hurt = { wave = "square", freq = 300, to = 100, duration = 0.1 }, dash = { sound = "dash", pitch = 1.4 },
                kill = "pickup", death = "boom", special = "special" },
  statuses = { burn = { name = "Burn", color = "#ff7030", dps = 6, time = 2, stacks = 3, spread = 30 },
               daze = { color = "#c0a0ff", confuse = true, time = 1.5 }, love = { color = "#ff80c0", charm = true, time = 2, charmDamage = 6 } },
  attack = { name = "Leap Slash", cooldown = 0.3, blocks = {
      { "lunge", distance = 20 }, { "wait", time = 0.05 },
      { "arc", radius = 50, degrees = 140, damage = 6, status = "burn" }, { "pool", radius = 14, life = 1, dps = 2 } } },
  secondary = { name = "Three Hit", cooldown = 0.4, combo = { window = 1,
      { { "box", length = 60, width = 18, damage = 5 } },
      { { "circle", radius = 40, damage = 5, status = "daze" } },
      function(me) me.statusArea({ status = "love", radius = 60 }) me.state.finisher = (me.state.finisher or 0) + 1 end } },
  forms = { { name = "Spiky", say = "Spikes out!", stats = { armor = 3 },
              attack = { name = "Spike Ring", cooldown = 0.3, blocks = { { "ring", radius = 60, inner = 10, damage = 6 } } } } },
  molt = { kills = 15, name = "Adult", say = "All grown up!", stats = { maxHp = 40, damage = 20 },
           art = { palette = PAL, body = { "..oooo..", ".obbbbo.", "obccccbo", ".obbbbo.", "..oooo.." } } },
  pets = { { name = "Mite", ai = "hunt", count = 2, damage = 3, art = { ".a.", "aba", ".a." }, palette = { a = "#a06030", b = "#ffd080" } },
           { name = "Guard", ai = "guard", damage = 4 }, { name = "Moon", ai = "orbit", damage = 2, status = "burn" },
           { name = "Gunner", ai = "shooter", damage = 3, rate = 0.4 } },
  ultimate = { name = "Big Burn", color = "#ff6020", duration = 0.5, charge = 2,
      fire = function(me) me.statusArea({ status = "burn", radius = 120 }) me.state.ult = true end,
      buff = { stats = { damage = 30 }, time = 3 } },
  poses = { idle = { time = 0.6, keys = { { 0 }, { 0.5, rear = 2 }, { 1 } } },
            death = { time = 0.5, keys = { { 0 }, { 1, spin = 1.5, stretch = -0.3 } } },
            victory = { time = 0.6, keys = { { 0 }, { 0.5, rear = 5 }, { 1, rear = 3 } } } },
  card = { motto = "Everything at once.", color = "#90ff90", frame = "leaf" },
  challenges = { { goal = "kills", n = 300 }, { goal = "ultimate", n = 3 } },
} ]])
    assert(big, "kitchen sink: " .. tostring(binfo.errors[1]))
    for _, wmsg in ipairs(binfo.warnings) do print("[selftest] warn: " .. wmsg) end
    assert(#binfo.warnings == 0, "kitchen sink warned: " .. tostring(binfo.warnings[1]))
    assert(big.forms and #big.forms == 2 and big.molt and big.molt.def and big.pets and #big.pets == 4 and big.statuses.burn
        and big.ownFrenzy and big.card and big.soundPack.hurt and big.anims.death and big.anims.death.hold, "extras lost")
    assert(#big.challenges >= 8, "challenges")
    assert(big.dash.type == "scripted_hold", "forms take the Shift key")
    local wings = 0
    for _, l in ipairs(big.model.restLimbs or {}) do if l.wave then wings = wings + 1 end end
    assert(wings >= 2, "wings / antennae should move")
    CustomBugs.register(big, "")
    local bw = World.new({ mode = "sandbox", character = big.id })
    bw.flags.god = true
    bw.pilot = { pressed = {}, down = {} }
    local bp = bw.player
    local sawForm, sawStatus, sawCharm, sawPets = false, false, false, 0
    for f = 1, 900 do
        if f % 40 == 1 then bw:spawnRing("worker_ant", 10, bp.x, bp.y, 50) end
        bw.pilot.down = { attack = f % 120 < 80, secondary = f % 120 >= 80, dash = f > 300 and f < 360 }
        bw.pilot.pressed = { secondary = f % 120 >= 80 }
        if f == 500 then bw.rewards.frenzy.charge = bw.rewards.frenzy.max bw.rewards.frenzy:unleash() end
        bw:update(1 / 60)
        sawForm = sawForm or bp.formIndex == 2
        if bp.statusTargets and #bp.statusTargets > 0 then sawStatus = true end
        for _, e in ipairs(bp.statusTargets or {}) do if e.cst and e.cst.love then sawCharm = true end end
        sawPets = math.max(sawPets, bp.pets and #bp.pets or 0)
        if f == 340 or f == 700 then love.graphics.origin() bw:draw() shot(f == 340 and "c2_sink_form" or "c2_sink_molt") end
    end
    assert(not SM.errors[big.id], "kitchen sink code failed: " .. tostring(SM.errors[big.id]))
    local bst = bp._me.state
    assert(sawForm and bp.formIndex == 1, "holding Shift should switch to form 2 and back")
    assert(sawStatus and sawCharm, ("statuses did not land (any %s, charm %s)"):format(tostring(sawStatus), tostring(sawCharm)))
    assert(sawPets == 5, "pets: expected 5, saw " .. sawPets)
    assert(bp.molted, "the molt did not happen after 15 kills (" .. tostring(bp.killsRun) .. ")")
    assert(bst.ult and bp.ultUses == 1, "the ultimate did not fire")
    assert((bst.finisher or 0) > 0, "the combo never reached its 3rd step")
    print(("[selftest] creator2: kitchen sink ok (%d kills, molted, pets %d)"):format(bp.killsRun or 0, sawPets))
    -- death pose holds
    bp.hp = 1 bw.flags.god = false
    bp:hurt(50, nil)
    assert(bp.dead and bp._anims and bp._anims.pose_death, "death pose")
    CustomBugs.unregister(big.id)


    -- 6. the template gallery: every template compiles without warnings and plays a short fight
    local Creator = require("src.states.creator")
    Creator._templates = nil
    local files = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems("content/bugtemplates")) do if f:match("%.lua$") then files[#files + 1] = f end end
    assert(#files >= 10, "expected 10 templates, found " .. #files)
    for _, f in ipairs(files) do
        local src = love.filesystem.read("content/bugtemplates/" .. f)
        assert(src:match("%-%-%s*KIND:"), f .. " has no KIND line")
        local d, info = CustomBugs.compile(src, f)
        assert(d, f .. ": " .. tostring(info.errors[1]) .. " (line " .. tostring(info.line) .. ")")
        for _, wm in ipairs(info.warnings) do print("[selftest] " .. f .. " warn: " .. wm) end
        assert(#info.warnings == 0, f .. " warned: " .. tostring(info.warnings[1]))
        CustomBugs.register(d, src)
        local tw = World.new({ mode = "sandbox", character = d.id })
        tw.flags.god = true
        tw.pilot = { pressed = {}, down = {} }
        local tp = tw.player
        local hits = 0
        tw.events:on("enemy_hit", function() hits = hits + 1 end)
        for fr = 1, 420 do
            if fr % 60 == 1 then tw:spawnRing("worker_ant", 8, tp.x, tp.y, 45) end
            local ph = fr % 140
            tw.pilot.down = { attack = ph < 70, secondary = ph >= 70 and ph < 100, dash = ph >= 110 and ph < 130 }
            tw.pilot.pressed = { secondary = ph == 70, dash = ph == 110, attack = ph % 10 == 0 and ph < 70 }
            if fr == 300 then tw.rewards.frenzy.charge = tw.rewards.frenzy.max tw.rewards.frenzy:unleash() end
            tw:update(1 / 60)
            if fr == 200 then love.graphics.origin() tw:draw() end
        end
        assert(not SM.errors[d.id], f .. " code failed: " .. tostring(SM.errors[d.id]))
        assert(hits > 5, f .. " barely hit anything (" .. hits .. ")")
        tw.events.handlers = {}
        CustomBugs.unregister(d.id)
        print(("[selftest] creator2: template %s ok (%d hits)"):format(d.name, hits))
    end
    CustomBugs.noSave = true
    local cr = State.switch(Creator.new())
    cr.page = "templates" cr:build()
    wait(0.3)
    shot("c2_templates")
    assert(#cr.menu.items >= 12, "the gallery lists the templates")

    -- 7. share codes round trip, and a bad one
    local src0 = love.filesystem.read("content/bugtemplates/10_spark_wasp.lua")
    local code = CustomBugs.shareCode(src0)
    assert(code and code:find("^SWARMED%-BUG:") and #code < #src0, "share code")
    assert(CustomBugs.fromShareCode("look: " .. code .. " !") == src0, "share code round trip")
    assert(CustomBugs.fromShareCode("SWARMED-BUG:abc") == nil, "a broken code is refused")
    print(("[selftest] creator2: share code ok (%d -> %d letters)"):format(#src0, #code))

    -- 8. the mixer's new rows: status, pet, molt, hit look, sounds, card, ultimate survive a save
    local Mixer = require("src.states.bugmixer")
    local mx = State.push(Mixer.new())
    local mm2 = mx.m
    mm2.name = "Mixed Extras"
    mm2.status, mm2.statusChance = "burn", 50
    mm2.pet, mm2.petCount = "mite", 2
    mm2.moltWave = 5
    mm2.hitNum = "#ff4040"
    mm2.cardColor, mm2.cardFrame, mm2.motto = "#40ff40", "gold", "Hello there."
    mx:build(true) mx:refresh(true)
    wait(0.3)
    shot("c2_mixer_extras")
    local msrc = mx:source()
    local md, minfo = CustomBugs.compile(msrc)
    assert(md, "mixer script broke: " .. tostring(minfo.errors[1]) .. "\n" .. msrc)
    assert(md.statuses and md.statuses.burn, "mixer: status lost")
    assert(md.pets and #md.pets >= 1, "mixer: pet lost")
    assert(md.molt and md.molt.wave == 5, "mixer: molt lost")
    assert(md.hitLook and md.hitLook.number, "mixer: hit look lost")
    assert(md.card and md.card.motto == "Hello there." and md.card.frame == "gold", "mixer: card lost")
    -- block editor from the mixer
    mx:openBlocks("attack")
    local be = State.top()
    assert(be.steps and #be.steps[1] > 0, "block editor opens with a starter move")
    be.steps[2] = { { "lunge", distance = 20 }, { "circle", radius = 40, damage = 9 } }
    be:build(true) be:refresh(true)
    wait(0.5)
    shot("c2_blockeditor")
    local bv = be:value()
    assert(bv.combo and #bv.combo == 2, "two steps make a combo")
    be:done()
    assert(State.top() == mx and mm2.attackOwn and mm2.attackOwn.combo, "block editor hands the move back")
    local md2 = CustomBugs.compile(mx:source())
    assert(md2 and md2.attack and not md2.scripted, "a block move stays a plain mix")
    State.pop()
    print("[selftest] creator2: mixer extras + block editor ok")

    -- 9. painter: kit parts, a limb, save as a new bug, then tweak its art
    local Painter = require("src.states.painter")
    local pt = State.push(Painter.new())
    for tab = 1, 5 do pt.tab = tab wait(0.15) shot("c2_painter_" .. tab) end
    local psrc = pt:source()
    local pd, pinfo = CustomBugs.compile(psrc)
    assert(pd and pd.art, "painter script: " .. tostring(pinfo and pinfo.errors[1]))
    pt:save()
    assert(pt.entry and pt.entry.def.art, "painter save: " .. tostring(pt.flash and pt.flash[1]))
    local pid = pt.entry.id
    local pt2 = Painter.new({ entry = pt.entry })
    local d3 = CustomBugs.compile(pt2:source())
    assert(d3 and d3.id == pid, "painting over a saved bug keeps it")
    State.pop()
    print("[selftest] creator2: painter ok")

    -- 10. title card on bug select
    local cs = State.push(require("src.states.charselect").new({}))
    wait(0.3)
    shot("c2_charselect")
    State.pop()

    -- 11. test arena: dummies, hitboxes shown, back to the creator from pause
    State.switch(Creator.new())
    local ag = State.push(require("src.states.game").new({ mode = "sandbox", character = pid, arena = true }))
    wait(0.6)
    assert(HS.show, "the arena shows hitboxes")
    assert(#ag.world.enemies >= 6, "the arena has dummies")
    shot("c2_arena")
    local ps = State.push(require("src.states.pause").new(ag))
    local backRow
    for _, it in ipairs(ps.menu.items) do if (it.label or ""):find("Bug Creator") then backRow = it end end
    assert(backRow, "pause has Back to the Bug Creator")
    backRow.onActivate()
    assert(getmetatable(State.top()) == Creator and not HS.show, "back in the creator")

    -- 12. rating: a short run
    local Rating = require("src.game.bugrating")
    local keepT = Rating.TIME
    Rating.TIME = 6
    local rt = Rating.new(pid)
    local guard = 0
    while not rt.score and guard < 5000 do rt:step(200) guard = guard + 1 end
    Rating.TIME = keepT
    assert(rt.score and not rt.error, "rating: " .. tostring(rt.error))
    local rs = State.push(require("src.states.rating").new(pt.entry.def))
    rs.rating = rt
    wait(0.2)
    shot("c2_rating")
    State.pop()
    assert(require("src.game.records").get().characters[pid].power == rt.score, "the power level is saved")
    print("[selftest] creator2: rating ok (" .. rt.score .. ")")
    CustomBugs.delete(pid)
    CustomBugs.noSave = nil

    if _G.CREATOR2_MORE then _G.CREATOR2_MORE(wait, shot) end
    State.switch(require("src.states.menu").new())
end
