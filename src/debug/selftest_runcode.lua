-- Run codes (src/game/runcode.lua): a run's code starts the same run again.
--   love . --selftest --runcode
local State = require("src.core.state")
local Records = require("src.game.records")

return function(wait, shot)
    Records.noSave = true
    local RunCode = require("src.game.runcode")
    local Game = require("src.states.game")
    local g = State.switch(Game.new({ mode = "run", character = "rhino_beetle", stage = "dune_field", gameMode = "colony",
        seed = 1763481234567, danger = 2, artifacts = { "giants" }, shared = true }))
    wait(0.1)
    local code = RunCode.encode(g.world)
    print("[selftest] code: " .. code)
    local p = assert(RunCode.decode("  " .. code .. "\n"))
    assert(p.character == "rhino_beetle" and p.stage == "dune_field" and p.gameMode == "colony", "bug, map, mode")
    assert(p.seed == 1763481234567 and p.danger == 2, "seed and danger survive the code")
    assert(p.artifacts[1] == "giants", "artifacts survive the code")
    local g2 = State.switch(Game.new(p))
    wait(0.1)
    assert(g2.world.seed == g.world.seed and g2.world.artifacts[1] == "giants", "the code starts the same run")
    assert(RunCode.encode(g2.world) == code, "a code's run gives the same code")
    assert(not RunCode.decode("hello"), "junk is refused")
    assert(not RunCode.decode("swarmed1.nobug.backyard.colony.d0.abc"), "unknown bugs are refused")
    print("[selftest] runcode OK")
end
