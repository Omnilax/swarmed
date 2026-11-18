-- TEMPLATE. Copy to content/artifacts/my_artifact.lua. Artifacts are run rules switched on
-- before a run (mode select > Artifacts), like Risk of Rain 2's: each one bends any mode a
-- little. They are bought once with amber in the Burrow (src/game/amber.lua), then toggled freely.
-- src/game/artifacts.lua applies them; the daily run, practice and the tutorial ignore them.
return {
    name = "My Artifact",
    description = "One or two short sentences: what changes.",
    cost = 60,                  -- amber in the Burrow
    color = "#c0a070",
    order = 50,
    -- Before the world is made: change the Game params (e.g. pick the bug).
    params = nil,               -- function(params) end
    -- Once the world is made: world.danger holds run multipliers (hpMul, damageMul, speedMul,
    -- eliteMul, healMul, groupMul, extraQueens); player stats take modifiers.
    apply = nil,                -- function(world) end
}
