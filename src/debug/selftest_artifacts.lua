-- Artifacts (content/artifacts, src/game/artifacts.lua, src/states/artifactpicker.lua).
--   love . --selftest --artifacts
-- Not bought: can't be switched on. Bought and on: each one changes the run as it says; a saved
-- run keeps its own list; the daily run and practice ignore them; the Burrow sells them.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Content = require("src.content")

return function(wait, shot)
    local A = require("src.game.artifacts")
    local Amber = require("src.game.amber")
    local Unlocks = require("src.game.unlocks")
    local Records = require("src.game.records")
    local savedFree = Unlocks.free
    Unlocks.free = false
    Settings.set("unlockAll", false)
    local p = Records.get()
    local saved = { p.amber, p.amberOwned, p.amberStarted }
    p.amberStarted, p.amber, p.amberOwned = true, 10000, {}
    assert(#Content.artifacts:all() >= 8, "artifacts missing")
    assert(Amber.get("artifact_glass") and Amber.get("artifact_glass").kind == "artifact", "the Burrow sells artifacts")
    assert(not A.set("glass", true) and not A.isOn("glass"), "an artifact not bought can't go on")
    for _, a in ipairs(Content.artifacts:all()) do assert(Amber.buy(A.unlockId(a.id)), "buy " .. a.id) end

    local Game = require("src.states.game")
    local function run(list, extra)
        for _, a in ipairs(Content.artifacts:all()) do A.set(a.id, false) end
        for _, id in ipairs(list) do assert(A.set(id, true)) end
        local params = { mode = "run", character = "rhino_beetle" }
        for k, v in pairs(extra or {}) do params[k] = v end
        local g = State.switch(Game.new(params))
        wait(0.2)
        return g.world, g
    end
    local base = run({})
    local hp0, fmax0 = base.player.stats:get("maxHp"), base.rewards.frenzy.max
    local d0 = base.danger
    local w = run({ "glass" })
    assert(math.abs(w.player.stats:get("maxHp") - hp0 * 0.4) < 1 and w.player.stats:get("damage") >= 100, "Glass Carapace")
    w = run({ "teeming", "giants" })
    assert(math.abs(w.danger.groupMul - 0.9) < 0.01 and math.abs(w.danger.hpMul - 0.6 * 2.2) < 0.01, "Teeming + Giants multiply")
    w = run({ "royal_guard", "twin_queens", "heatwave", "frenzy_tide" })
    assert(w.danger.eliteMul == 4 and w.danger.twinQueens == 1 and w.danger.extraQueens == 1, "Royal Guard / Twin Queens")
    assert(w.danger.speedMul > 1.29 and w.rewards.frenzy.max == fmax0 * 0.5 and w.danger.damageMul == 1.25, "Heatwave / Frenzy Tide")
    -- twin queens: a boss wave queues two queens
    local sp = w.spawner
    sp.wave = 4
    sp.onlyQueen = Content.enemies:get("queen_worker")
    sp:startWave(5)
    local queens = 0
    for _, q in ipairs(sp.queue) do if q.def.boss then queens = queens + 1 end end
    assert(queens == 2, "Twin Queens: two queens on a boss wave (" .. queens .. ")")
    -- metamorphosis picks some other unlocked bug now and then
    local chars = {}
    for _ = 1, 8 do
        w = run({ "metamorphosis" })
        chars[w.player.def.id] = true
        assert(Unlocks.bug(w.player.def.id), "metamorphosis must pick an unlocked bug")
    end
    local n = 0 for _ in pairs(chars) do n = n + 1 end
    assert(n >= 2, "metamorphosis should vary the bug")
    -- a saved run keeps its own list; the daily run and practice take none
    w = run({ "glass" })
    local RunSave = require("src.game.runsave")
    local snap = RunSave.snapshot and RunSave.snapshot(State.find(Game)) or nil
    if snap then
        local params = RunSave.params(snap)
        assert(params.artifacts[1] == "glass", "saved run keeps its artifacts")
    end
    w = run({ "glass" }, { daily = "2026-11-18", seed = 20261118 })
    assert(#w.artifacts == 0, "the daily run ignores artifacts")
    w = run({ "glass" }, { practice = { wave = 1 } })
    assert(#w.artifacts == 0, "practice ignores artifacts")
    -- the picker
    A.set("glass", true) A.set("giants", true)
    local pk = State.push(require("src.states.artifactpicker").new())
    pk.menu.focus = 2
    wait(0.2)
    shot("artifacts_picker")
    State.pop()
    for _, a in ipairs(Content.artifacts:all()) do A.set(a.id, false) end
    p.amber, p.amberOwned, p.amberStarted = saved[1], saved[2], saved[3]
    Unlocks.free = savedFree
    print("[selftest] artifacts ok")
end
