-- Menus, settings and controls:  love . --selftest --qol
-- Controller icons and button prompts, character select sort / filter / favourites and the live
-- move preview, save and resume, practice mode, settings presets, the left-handed touch layout,
-- quick restart, pause on focus loss / controller unplug, first-pick bug tips.
local State = require("src.core.state")
local Content = require("src.content")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Theme = require("src.ui.theme")
local Prefs = require("src.game.prefs")
local RunSave = require("src.game.runsave")
local Playstyles = require("src.config.playstyles")

return function(wait, shot)
    local Game = require("src.states.game")
    local util = require("src.core.util")

    -- every playable bug has a known playstyle and a tip
    for _, d in ipairs(Content.characters:all()) do
        assert(Playstyles.byId[d.playstyle or ""], d.id .. " has no playstyle")
        assert(type(d.tip) == "string" and #d.tip > 20, d.id .. " has no tip")
    end

    -- prompts: tokens become key caps / icons on every device, and wrap
    for _, dev in ipairs({ "keyboard", "gamepad", "touch" }) do
        Input.lastDevice = dev
        love.graphics.setFont(Theme.font("body"))
        local w, n = Theme.richSize("Press {dash} to dash, {secondary} for the special, {pad:a} or {key:Esc} or {pad:leftshoulder}", 200)
        assert(w <= 200 and n >= 2, "rich text should wrap (" .. dev .. ")")
        Theme.rich("Hold {dash} and {attack}", 10, 10, 400, "center")
        Theme.hints({ { "A", "Play" }, { "LB/RB", "Tab" }, { "D-pad", "Browse" }, { "Esc", "Back" } }, 300, 300)
    end
    Input.lastDevice = "gamepad"
    assert(Input.glyph("dash").pad == "a" and Input.glyph("ui_back").pad == "b", "pad glyphs")
    Input.lastDevice = "keyboard"
    assert(Input.glyph("dash").key == "SPACE" and Input.glyph("secondary").mouse == 2, "keyboard glyphs")
    print("[qol] prompts OK")

    -- character select: sort by speed, filter tanks, favourites pinned on top
    Prefs.data = nil
    Prefs.load()
    Prefs.get().favourites = {}
    local cs = State.push(require("src.states.charselect").new())
    local function bugs()
        local out = {}
        for _, it in ipairs(cs.menu.items) do if it.character then out[#out + 1] = it.character end end
        return out
    end
    assert(#bugs() == #Content.characters:all(), "every bug listed")
    cs.menu.items[1].set("speed")
    local b = bugs()
    for i = 2, #b do assert((b[i - 1].stats.moveSpeed or 100) >= (b[i].stats.moveSpeed or 100), "speed sort") end
    assert(cs.menu.items[3].value() == tostring(b[1].stats.moveSpeed), "sorted value on the row")
    cs.menu.items[2].set("tank")
    for _, d in ipairs(bugs()) do assert(d.playstyle == "tank", "tank filter let " .. d.id .. " through") end
    cs.menu.items[2].set("all")
    cs.menu.items[1].set("hp")
    local last = bugs()[#bugs()]
    cs.menu.focus = #cs.menu.items - 1
    Input.press("ui_favourite")
    cs:update(1 / 60)
    assert(bugs()[1] == last and cs.menu.items[3].star, "favourite should pin to the top")
    cs.menu.items[2].set("favourites")
    assert(#bugs() == 1, "favourites filter")
    cs.menu.items[2].set("all")
    -- the live preview: the special and the dash both fire for every bug, without errors
    for _, d in ipairs(Content.characters:all()) do
        local pv = require("src.ui.movepreview").new(d.id)
        local seen = {}
        for _ = 1, 7 * 30 do
            pv:update(1 / 30)
            if pv.caption then seen[pv.caption[1]] = true end
        end
        assert(seen.DASH and (seen.SPECIAL or not d.secondary), d.id .. " preview did not show its moves")
        love.graphics.setCanvas()
        pv:draw(0, 0, 200, 120)
        pv:release()
    end
    print("[qol] preview OK for " .. #Content.characters:all() .. " bugs")
    for i, it in ipairs(cs.menu.items) do if it.character and it.character.id == "rhino_beetle" then cs.menu.focus = i end end
    cs.menu.items[1].set("speed")
    for i, it in ipairs(cs.menu.items) do if it.character and it.character.id == "mantis" then cs.menu.focus = i end end
    wait(2.2)
    shot("qol_charselect")
    Input.lastDevice = "gamepad"
    wait(0.2)
    shot("qol_charselect_pad")
    Input.lastDevice = "keyboard"
    cs.menu.items[1].set("default")
    Prefs.get().favourites = {}
    State.pop()

    -- save and resume: the bag, skills, wave, HP and species come back
    local game = State.switch(Game.new({ mode = "run", character = "scorpion", gameMode = "colony" }))
    local w = game.world
    w.flags.god = true
    local sp = w.spawner
    for _, id in ipairs({ "chitin_plate", "honeydew", "mantis_forelimb" }) do w:giveItem(id) end
    sp:startWave(6)
    w.time, w.kos = 321, 456
    w.player.hp = 17
    w.player.skills:gainXP(400, true)
    local tree = w.player.skills.tree
    local bought
    for id in pairs(tree and tree.nodes or {}) do if w.player.skills:buy(id) then bought = id break end end
    local snap = util.deepcopy(RunSave.snapshot(game))
    assert(snap.wave == 5, "a wave in progress should be replayed (saved wave " .. tostring(snap.wave) .. ")")
    -- through text and back, like the save file
    local chunk = assert(loadstring("return " .. util.serialize(snap)))
    snap = chunk()
    local g2 = State.switch(Game.new(RunSave.params(snap)))
    local w2 = g2.world
    assert(w2.spawner.wave == 5 and w2.spawner.phase == "break", "resume wave")
    assert(#w2.spawner.knownList == #sp.knownList, "species met")
    assert(w2.kos == 456 and math.abs(w2.time - 321) < 0.01 and w2.player.hp == 17, "time / KOs / HP")
    assert(#w2.player.inventory.bag == #w.player.inventory.bag, "bag size")
    for i, e in ipairs(w.player.inventory.bag) do
        local e2 = w2.player.inventory.bag[i]
        assert(e2.item.id == e.item.id and e2.x == e.x and e2.y == e.y, "bag layout")
    end
    if bought then assert(w2.player.skills:rank(bought) == 1, "skill node") end
    assert(w2.player.skills.xp == w.player.skills.xp, "skill xp")
    assert(math.abs(w2.player.stats:get("armor") - w.player.stats:get("armor")) < 0.01, "stats from items + skills")
    assert(w2.seed == w.seed, "the run's seed should survive a save (" .. tostring(w2.seed) .. " vs " .. tostring(w.seed) .. ")")
    assert(w2.choice == nil or w.choice == nil or w2.choice.rerolls == w.choice.rerolls, "item choice rerolls")
    -- restart from a resumed run starts over
    g2:restart()
    assert(State.top().world.spawner.wave == 0 and State.top().world.kos == 0, "restart starts fresh")
    print("[qol] save / resume OK")

    -- pause: save & quit for real runs, quick restart key, focus loss and unplugged pads pause
    game = State.top()
    local pause = State.push(require("src.states.pause").new(game))
    local labels = {}
    for _, it in ipairs(pause.menu.items) do labels[it.label] = true end
    assert(labels["Save & Quit"] and labels["Abandon Run"] and labels.Restart, "pause menu")
    wait(0.2)
    shot("qol_pause")
    Input.press("quick_restart")
    pause:update(1 / 60)
    assert(getmetatable(State.top()) == Game and State.top() ~= game, "quick restart")
    game = State.top()
    game:focus(false)
    assert(State.top() ~= game, "focus loss should pause")
    State.pop()
    Input.lastDevice = "gamepad"
    game:joystickremoved({}, true)
    assert(State.top() ~= game, "unplugging the pad should pause")
    State.pop()
    Input.lastDevice = "keyboard"

    -- practice: one species only, a boss every wave, nothing recorded
    local Practice = require("src.states.practice")
    local opts = Practice.speciesOptions()
    assert(#opts > 20, "species list")
    local runsBefore = require("src.game.records").get().runs
    local pg = State.switch(Game.new({ mode = "run", character = "rhino_beetle", gameMode = "colony",
        practice = { wave = 8, species = "bullet_ant", items = "run", god = true } }))
    assert(require("src.game.records").get().runs == runsBefore, "practice should not count as a run")
    local psp = pg.world.spawner
    assert(#pg.world.player.inventory.bag > 0, "practice items")
    psp:startWave()
    assert(psp.wave == 8, "practice starts at its wave")
    for _, gq in ipairs(psp.queue) do assert(gq.def.id == "bullet_ant", "practice sent " .. gq.def.id) end
    assert(not RunSave.allowed(pg), "practice is never saved")
    local queen
    for _, d in ipairs(Content.enemies:all()) do if d.boss and d.family == "ant" then queen = d break end end
    if queen then
        local qg = State.switch(Game.new({ mode = "run", character = "rhino_beetle", practice = { wave = 3, species = queen.id } }))
        qg.world.spawner:startWave()
        local found = false
        for _, gq in ipairs(qg.world.spawner.queue) do if gq.def == queen then found = true end end
        assert(found, "a boss practice should send that boss")
    end
    local ps = State.switch(require("src.states.practice").new())
    wait(0.3)
    shot("qol_practice")
    print("[qol] practice OK")

    -- settings presets
    local SS = require("src.states.settings")
    local Presets = require("src.config.settings_presets")
    for _, p in ipairs(Presets) do
        SS.applyPreset(p)
        assert(SS.current() == p, "preset " .. p.id)
    end
    Settings.resetCategory("Video")
    assert(SS.current() and SS.current().id == "balanced", "defaults should read as Balanced")
    Settings.set("particles", 1)
    assert(SS.current() == nil, "a changed option makes it Custom")
    Settings.resetCategory("Video")
    local st = State.push(SS.new())
    wait(0.2)
    shot("qol_settings_video")
    State.pop()

    -- left-handed touch layout mirrors the buttons and the stick
    local Touch = require("src.core.touch")
    local g3 = State.switch(Game.new({ mode = "run", character = "rhino_beetle" }))
    Settings.set("touchControls", "on")
    local W = love.graphics.getWidth()
    local right = {}
    for _, bt in ipairs(Touch.buttons()) do right[bt.id] = bt.x end
    Settings.set("touchLayout", "left")
    for _, bt in ipairs(Touch.buttons()) do assert(math.abs(bt.x - (W - right[bt.id])) < 0.5, "mirrored " .. bt.id) end
    assert(Touch.onStickSide(W * 0.9) and not Touch.onStickSide(W * 0.1), "stick side")
    wait(0.3)
    shot("qol_touch_left")
    Settings.set("touchLayout", "right")
    Settings.set("touchControls", "auto")

    -- first-pick tip: shows once per bug
    local Tutorial = require("src.game.tutorial")
    Tutorial.off = false
    Tutorial.seen = { move = true }
    Tutorial.attach(g3.world)
    g3.world.time = 2
    Tutorial.update(g3.world, 0.1)
    assert(Tutorial.current and Tutorial.current.title == "Rhino Beetle", "bug tip")
    Input.lastDevice = "gamepad"
    wait(0.5)
    shot("qol_bug_tip_pad")
    Input.lastDevice = "keyboard"
    Tutorial.current = nil
    Tutorial.update(g3.world, 0.1)
    assert(not (Tutorial.current and Tutorial.current.title), "bug tip only once")
    Tutorial.off = true

    -- title screen: play again + practice
    Prefs.get().last = { character = "mantis", gameMode = "swarm" }
    local menu = State.switch(require("src.states.menu").new())
    local found = {}
    for _, it in ipairs(menu.menu.items) do found[it.label:match("^[^:]+")] = true end
    assert(found["Play Again"] and found.Practice, "title shortcuts")
    wait(0.3)
    shot("qol_title")
    print("[qol] all OK")
end
