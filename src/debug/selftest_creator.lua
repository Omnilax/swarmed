-- Bug Creator:  love . --selftest --creator
-- The script sandbox (nothing dangerous reachable, stuck loops stopped, bytecode refused), the
-- checks and clamps on what a script returns, the blueprint, saving / loading / renaming /
-- deleting bug files, borrowed rules, skill trees and colours, every move mixed onto other
-- bodies actually fighting, and the three screens (saves selftest_creator_*.png).
local State = require("src.core.state")
local Content = require("src.content")
local CustomBugs = require("src.game.custombugs")
local Input = require("src.core.input")

return function(wait, shot)
    local function compile(src) return CustomBugs.compile(src, "test") end
    local function ok(src)
        local def, info = compile(src)
        assert(def, "should compile: " .. tostring(info.errors[1]) .. "\n" .. src)
        return def, info
    end
    local function bad(src, pattern)
        local def, info = compile(src)
        assert(not def, "should fail: " .. src)
        local e = table.concat(info.errors, " | ")
        assert(not pattern or e:find(pattern), "wrong error for: " .. src .. "\n  got: " .. e)
        return info
    end

    -- 1. the sandbox: none of these exist inside a script
    for _, name in ipairs({ "love", "io", "os", "require", "loadstring", "load", "dofile", "loadfile", "debug",
        "getmetatable", "setmetatable", "pcall", "xpcall", "coroutine", "package", "jit", "collectgarbage",
        "module", "setfenv", "getfenv", "newproxy", "rawset" }) do
        local def = ok(("return { name = (%s == nil) and \"Safe\" or \"Unsafe\" }"):format(name))
        assert(def.name == "Safe", name .. " is reachable from a bug script")
    end
    ok("return { name = (string.dump == nil) and \"Safe\" or \"Unsafe\" }")
    -- the real globals are untouched by a script
    ok("math = nil string = nil table = nil x = 1 return { name = \"Vandal\" }")
    assert(math.floor and string.format and table.insert and rawget(_G, "x") == nil, "a script changed the real globals")
    -- a loop that never ends is stopped, quickly
    local t0 = love.timer.getTime()
    bad("while true do end", "too long")
    bad("local t = {} for i = 1, 1e9 do t[#t % 100 + 1] = i end return {}", "too long")
    bad("local function f() return f() end return { name = f() }")
    bad("local s = 'x' for i = 1, 40 do s = s .. s end return {}", "memory")
    assert(love.timer.getTime() - t0 < 6, "stopping stuck scripts took too long")
    assert(debug.gethook() == nil, "the instruction hook was left on")
    bad(string.dump(function() return {} end), "bytecode")
    bad("return { name = string.rep('x', 1e7) }", "too long")
    bad("return { name = ('x'):rep(1e7) }", "too long")
    local info = bad("return {\n name = \"A\",\n attack = ,\n}")
    assert(info.line == 3, "syntax errors should name their line (got " .. tostring(info.line) .. ")")
    info = bad("local x = nil\nlocal y = x.field\nreturn {}")
    assert(info.line == 2, "runtime errors should name their line")
    bad("return 5", "return")
    bad("return {}", "name")
    print("[selftest] creator: sandbox OK")

    -- 2. what comes out is checked and clamped
    local def, inf = ok([[return { name = "Big", stats = { maxHp = 99999, moveSpeed = -5 },
        attack = { type = "arc", damage = 99999, cooldown = 0, radius = 30, arc = 2, count = 5000,
            onHit = function() while true do end end } }]])
    assert(def.stats.maxHp == 250 and def.stats.moveSpeed == 40, "stats should be clamped")
    assert(def.attack.damage == 200 and def.attack.cooldown >= 0.05 and def.attack.count == 24, "move params should be clamped")
    assert(def.attack.onHit == nil, "functions must not come out of a script")
    assert(#inf.warnings > 0, "clamping should warn")
    assert(def.id == "custom_big" and def.custom, "id should be custom_<name>")
    bad([[return { name = "X", look = "nope" }]], "look")
    bad([[return { name = "X", attack = { type = "nope" } }]], "unknown attack")
    bad([[return { name = "X", dash = "nope" }]], "no built%-in bug")
    bad([[return { name = "X", stats = { power = 5 } }]], "unknown stat")
    bad([[return { name = "X", secondary = { from = "rhino_beetle", damage = "lots" } }]], nil)
    -- a whole copied bug, tweaked
    def = ok([[local b = bug("tarantula") b.name = "Glass Tarantula" b.stats.maxHp = 30 return b]])
    local tar = Content.characters:get("tarantula")
    assert(def.mix.look == "tarantula" and def.stats.maxHp == 30 and def.attack.type == tar.attack.type, "bug() copy failed")
    assert(not pcall(function() return CustomBugs.run("return bug('nope')") end) or not CustomBugs.run("return bug('nope')"), "bug(bad id) should fail")
    -- copied moves are copies: changing one never touches the built-in bug
    def = ok([[return { name = "Copycat", attack = { from = "scorpion", damage = 99 } }]])
    assert(def.attack.damage == 99 and Content.characters:get("scorpion").attack.damage ~= 99, "from = copy leaked into the built-in bug")
    -- the blueprint and the doc examples are valid scripts
    local bp, bpInfo = ok(CustomBugs.blueprint())
    assert(#bpInfo.warnings == 0, "the blueprint should load without notes: " .. tostring(bpInfo.warnings[1]))
    assert(bp.name == "Spike Beetle" and bp.colors and bp.skillTree == "rhino_beetle", "blueprint fields lost")
    ok([[local moves = { "mantis", "scorpion", "crab" }
        return { name = "Lucky Bug", look = "crab", attack = moves[math.random(#moves)] }]])
    -- the mixer's script writer round-trips
    local src = CustomBugs.toSource({ name = "Round \"Trip\"", look = "crab", scale = 1.25, attack = "mantis",
        secondary = false, dash = { from = "wolf_spider", distance = 90 }, stats = { maxHp = 80, armor = 2.5 },
        colors = { hue = 40 } })
    def = ok(src)
    assert(def.name == "Round \"Trip\"" and def.scale == 1.25 and def.secondary == nil and def.dash.distance == 90
        and def.stats.armor == 2.5 and def.mix.attack == "mantis", "toSource round trip failed:\n" .. src)
    -- numbers of the wrong kind in a hand-written move: the test fight on save catches them
    local nope, ninfo = CustomBugs.save([[return { name = "Wonky", attack = { type = "arc", damage = 5, cooldown = 0.5,
        radius = "big", arc = 2 } }]])
    assert(not nope and ninfo.errors[1]:find("test fight"), "a crashing move should not save: " .. tostring(ninfo.errors[1]))
    assert(not Content.characters:get("custom__trial") and not Content.characters:get("custom_wonky"), "trial bug left registered")
    print("[selftest] creator: checks OK")

    -- 3. files: save, load, rename, break, delete (in a test folder)
    CustomBugs.dir, CustomBugs.noSave = "selftest_custom_bugs", false
    for _, f in ipairs(love.filesystem.getDirectoryItems(CustomBugs.dir)) do love.filesystem.remove(CustomBugs.dir .. "/" .. f) end
    local saved = assert(CustomBugs.save([[return { name = "File Bug", look = "mantis" }]]))
    assert(love.filesystem.getInfo(CustomBugs.dir .. "/custom_file_bug.lua"), "save wrote no file")
    assert(Content.characters:get("custom_file_bug"), "saved bug not registered")
    local renamed = assert(CustomBugs.save([[return { name = "Renamed Bug", look = "mantis" }]], saved.id))
    assert(not love.filesystem.getInfo(CustomBugs.dir .. "/custom_file_bug.lua") and not Content.characters:get("custom_file_bug"),
        "renaming should move the file")
    love.filesystem.write(CustomBugs.dir .. "/broken.lua", "return { name = ")
    assert(CustomBugs.loadAll() == 1 and #CustomBugs.broken == 1 and Content.characters:get(renamed.id), "loadAll wrong")
    local sneaky = CustomBugs.save([[return { name = "Rhino", id = "../rhino_beetle" }]])
    assert(not Content.characters:get("rhino_beetle").custom and (not sneaky or sneaky.id == "custom_rhino_beetle"),
        "a script must never replace a built-in bug")
    if sneaky then CustomBugs.delete(sneaky.id) end
    CustomBugs.delete(renamed.id)
    assert(not Content.characters:get(renamed.id) and not love.filesystem.getInfo(CustomBugs.dir .. "/" .. renamed.id .. ".lua"), "delete failed")
    love.filesystem.remove(CustomBugs.dir .. "/broken.lua")
    CustomBugs.loadAll()
    CustomBugs.noSave = true
    print("[selftest] creator: files OK")

    -- 4. borrowed rules, trees and colours reach the game
    local World = require("src.game.world")
    local BugRules = require("src.game.bugrules")
    local mixed = assert(CustomBugs.save([[return { name = "Borrower", look = "crab", rules = "dung_beetle",
        skillTree = "mantis", colors = { hue = 90 }, startingItems = { "honeydew", "not_an_item" } }]]))
    local w = World.new({ mode = "sandbox", character = mixed.id })
    assert(BugRules.of(w.player) and BugRules.of(w.player).name == "Recycler", "borrowed rule not used")
    assert(w.player.skills.tree and w.player.skills.tree.character == "mantis", "borrowed skill tree not used")
    assert(require("src.game.cosmetics").skinFor(mixed.id).hue == 90, "custom colours not used")
    assert(w.player.inventory:count("honeydew") == 1, "starting items not given")
    -- custom bugs don't count for the play-every-bug achievement or the daily run
    local n = 0
    for _, c in ipairs(Content.characters:all()) do if not c.custom then n = n + 1 end end
    for _, a in ipairs(Content.achievements:all()) do
        if a.id == "play_all" then assert(a.goal() == n, "custom bugs count for Menagerie") end
    end
    for d = 1, 40 do
        local info2 = require("src.game.daily").info(d * 86400)
        assert(not Content.characters:get(info2.character).custom, "the daily run picked a custom bug")
    end
    CustomBugs.delete(mixed.id)

    -- 4b. a brand-new bug: own art and moves written in code (the Stick Insect example)
    local SM = require("src.game.scriptmoves")
    local Sprites = require("src.gfx.sprites")
    local stickSrc = assert(love.filesystem.read("content/characters/_example_stick_insect.lua"))
    local stick, sinfo = CustomBugs.save(stickSrc)
    assert(stick, "the Stick Insect example should save: " .. tostring(sinfo.errors[1]))
    assert(#sinfo.warnings == 0, "the example should load without notes: " .. tostring(sinfo.warnings[1]))
    assert(stick.mix.art and stick.scripted and Sprites.byId[stick.model.body] and Sprites.byId[stick.sprite].image, "own art not built")
    assert(stick.attack.type == "scripted" and type(stick.attack.fire) == "function", "scripted attack lost its code")
    do
        local sw = World.new({ mode = "sandbox", character = stick.id })
        sw.flags.god = true
        sw.pilot = { pressed = {}, down = {} }
        local p = sw.player
        local shotsSeen, hit = 0, false
        for f = 1, 300 do
            if f % 40 == 1 then sw:spawnRing("worker_ant", 8, p.x, p.y, 45) end
            local ph = f % 90
            sw.pilot.pressed = { secondary = ph == 10, dash = ph == 50 }
            sw.pilot.down = { attack = true }
            sw:update(1 / 60)
            shotsSeen = math.max(shotsSeen, #sw.hazards.shots)
            love.graphics.origin()
            if f % 60 == 0 then sw:draw() end
        end
        assert(not SM.errors[stick.id], "a Stick Insect move failed: " .. tostring(SM.errors[stick.id]))
        assert(shotsSeen >= 5, "the thorn fan fired no thorns (" .. shotsSeen .. ")")
        assert((p.scriptState.swings or 0) >= 3, "the scripted attack did not run")
        print(("[selftest] creator: stick insect fought (swings %d, thorns in flight %d, ants left %d)"):format(p.scriptState.swings, shotsSeen, sw.enemyCount))
    end
    -- move code is sandboxed too: a stuck loop in a move stops that move, not the game
    local loopy, linfo = CustomBugs.compile([[return { name = "Loopy", attack = { type = "scripted", cooldown = 0.5,
        fire = function(me) while true do end end } }]])
    assert(loopy, tostring(linfo.errors[1]))
    local okSave, why = CustomBugs.trial(loopy)
    assert(not okSave and why:find("too long"), "a stuck move should fail the test fight: " .. tostring(why))
    -- and it can't reach the engine
    local sneak = assert(CustomBugs.compile([[return { name = "Sneak", attack = { type = "scripted", cooldown = 0.5,
        fire = function(me) me.state.seen = tostring(love) .. tostring(me.params.fire and "f") .. tostring(rawget(me, "world")) end } }]]))
    assert(CustomBugs.trial(sneak), "sneak trial failed")
    local bad1 = CustomBugs.compile([[return { name = "Nofire", attack = { type = "scripted" } }]])
    assert(not bad1, "a scripted attack needs fire")
    local badArt, binfo = CustomBugs.compile([[return { name = "Badart", art = { palette = { a = "#ffffff" }, body = { "aaz" } } }]])
    assert(not badArt and binfo.errors[1]:find("palette"), "unknown art letters should fail")

    -- 5. every move on someone else's body, fighting for a few seconds
    local bugs = Content.characters:filter(function(c) return not c.custom end)
    local nb = #bugs
    local function at(i) return bugs[(i - 1) % nb + 1].id end
    local t1 = love.timer.getTime()
    for i = 1, nb do
        local srcM = CustomBugs.toSource({ name = "Mix " .. i, look = at(i), attack = at(i + 1), secondary = at(i + 3),
            dash = at(i + 7), scale = 0.7 + (i % 5) * 0.2 })
        local d = assert(CustomBugs.save(srcM))
        local mw = World.new({ mode = "sandbox", character = d.id })
        mw.flags.god = true
        mw.pilot = { pressed = {}, down = {} }
        local p = mw.player
        local okRun, err = pcall(function()
            for f = 1, 240 do
                if f % 30 == 1 then mw:spawnRing("worker_ant", 6, p.x, p.y, 60) end
                local phase = f % 80
                mw.pilot.pressed = { attack = phase == 1, secondary = phase == 30, dash = phase == 55 }
                mw.pilot.down = { attack = phase < 25, secondary = phase >= 30 and phase < 50, dash = phase >= 55 and phase < 70 }
                local a = f * 0.05
                mw.pilot.mx, mw.pilot.my = math.cos(a), math.sin(a)
                mw:update(1 / 60)
            end
            love.graphics.origin()
            mw:draw()
        end)
        assert(okRun, ("mixed bug crashed (body %s, attack %s, special %s, dash %s): %s"):format(at(i), at(i + 1), at(i + 3), at(i + 7), tostring(err)))
        CustomBugs.delete(d.id)
        if i % 6 == 0 then wait(0.01) end
    end
    print(("[selftest] creator: %d mixed bugs fought fine (%.1fs)"):format(nb, love.timer.getTime() - t1))

    -- 6. the screens
    local Creator = require("src.states.creator")
    local Mixer = require("src.states.bugmixer")
    local Editor = require("src.states.codeeditor")
    State.switch(require("src.states.menu").new())
    assert(CustomBugs.save([[local b = bug("stag_beetle") b.name = "Shared Stag" b.colors = { hue = 200 } return b]]))
    local hub = State.push(Creator.new())
    wait(0.2)
    for i, it in ipairs(hub.menu.items) do if it.bugId == "custom_stick_insect" then hub.menu.focus = i it.onActivate() break end end
    wait(0.3)
    shot("creator_hub")
    -- mix: change body and moves, the preview follows, save
    local mix = State.push(Mixer.new())
    mix.m.name = "Mixed Up"
    mix.m.look, mix.m.attack, mix.m.dash, mix.m.hue = "lobster", "mantis_shrimp", "dragonfly", 120
    mix:refresh(true)
    for _ = 1, 120 do
        wait(1 / 60)
        if mix.preview and mix.preview.t > 1.6 then break end
    end
    assert(mix.preview and mix.def and mix.def.mix.look == "lobster", "mixer preview did not build")
    shot("creator_mixer")
    mix:save(false)
    local made = Content.characters:get("custom_mixed_up")
    assert(made and made.attack.type == Content.characters:get("mantis_shrimp").attack.type, "mixer save failed")
    -- typing a name
    mix:startNaming()
    assert(mix.wantsText, "naming should take the keyboard")
    mix:keypressed("backspace")
    mix:textinput("!")
    mix:keypressed("return")
    assert(mix.m.name == "Mixed U!" and not mix.wantsText, "naming failed: " .. mix.m.name)
    -- reopen the saved mix: every choice comes back
    State.pop()
    assert(not Content.characters:get("custom__preview"), "preview bug left registered")
    local again = Mixer.new({ from = CustomBugs.get("custom_mixed_up") })
    assert(again.m.look == "lobster" and again.m.attack == "mantis_shrimp" and again.m.dash == "dragonfly" and again.m.hue == 120,
        "reopening a mix lost its choices")
    again:dropPreview()
    -- the editor: type, break it, see the error line, fix it, save
    local ed = State.push(Editor.new({ text = CustomBugs.get("custom_mixed_up").source, replaces = "custom_mixed_up" }))
    wait(0.1)
    ed:moveTo(2, 0)
    ed:keypressed("end")
    for ch in ("  -- typed in the game"):gmatch(".") do ed:textinput(ch) end
    ed:keypressed("return")
    for ch in ("tip = ,"):gmatch(".") do ed:textinput(ch) end
    ed:check()
    assert(not ed.def and ed.errLine == 3, "the editor should point at the broken line (got " .. tostring(ed.errLine) .. ")")
    wait(0.1)
    shot("creator_editor_error")
    ed:keypressed("backspace")
    ed:textinput("\"Typed!\",")
    ed:check()
    assert(ed.def and ed.def.tip == "Typed!", "fixing the line failed: " .. tostring(ed.info.errors[1]))
    ed:keypressed("z", nil, nil)
    ed:save(false)
    assert(not ed.dirty and Content.characters:get("custom_mixed_up").tip == "Typed!", "editor save failed")
    wait(0.1)
    shot("creator_editor")
    -- a phone in landscape
    local Theme = require("src.ui.theme")
    local ww, wh, wflags = love.window.getMode()
    local ref = Theme.refHeight
    Theme.refHeight = 480
    love.window.setMode(844, 390, wflags)
    wait(0.1)
    shot("creator_editor_phone")
    State.pop()
    wait(0.1)
    shot("creator_hub_phone")
    State.push(ed)
    love.window.setMode(ww, wh, wflags)
    Theme.refHeight = ref
    -- undo goes back past the fix
    ed:doUndo()
    assert(ed.dirty, "undo should change the text")
    ed.dirty = false
    State.pop()
    -- custom bugs on bug select
    local cs = State.push(require("src.states.charselect").new({ gameMode = "colony" }))
    cs.filter = "custom"
    cs:build()
    local seen = 0
    for _, it in ipairs(cs.menu.items) do if it.character and it.character.custom then seen = seen + 1 end end
    if seen ~= 3 then for _, e in ipairs(CustomBugs.all()) do print("  custom: " .. e.id) end end
    assert(seen == 3, "bug select should list the custom bugs (saw " .. seen .. ")")
    State.pop()
    -- the stick insect in a real run, close up
    local Game = require("src.states.game")
    local g = State.switch(Game.new({ mode = "run", character = "custom_stick_insect", seed = 31 }))
    g.world.flags.god = true
    g.world.camera.zoom, g.world.camera.targetZoom = 2, 2
    g.world:spawnRing("worker_ant", 10, g.world.player.x, g.world.player.y, 50)
    Input.virtualDown.attack = true
    for _ = 1, 40 do wait(1 / 60) end
    Input.press("secondary")
    for _ = 1, 14 do wait(1 / 60) end
    shot("creator_stick_insect")
    Input.virtualDown.attack = nil
    for _, e in ipairs(CustomBugs.all()) do CustomBugs.delete(e.id) end
    State.pop()
    print("[selftest] creator OK")
end
