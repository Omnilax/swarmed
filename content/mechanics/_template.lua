-- TEMPLATE. Copy to content/mechanics/my_rule.lua. A stage mechanic changes how a stage
-- plays (src/game/director.lua). A stage turns one on with
--   mechanic = { type = "my_rule", ...params... }
-- and m.params is that table. m = { def, params, st (your state), t (seconds) }.
return {
    name = "My Rule",
    description = "What it does (shown nowhere yet; for the catalogue).",
    start = function(world, m) end,
    update = function(world, m, dt) end,
    onWaveStart = function(world, m, wave) end,
    -- env = function(world, m, env) end,                     -- env.playerSpeed, enemySpeed, driftX/Y, inset
    -- field = function(world, m, x, y, who) return 1 end,    -- speed multiplier at a spot (who = "player" or the enemy)
    drawGround = function(world, m) end,
    -- drawAir = function(world, m) end,
}
