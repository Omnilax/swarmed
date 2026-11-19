-- TEMPLATE. Copy to content/bosses/my_boss.lua. A boss encounter: on every 5th wave (not the
-- run's final wave) something big joins the queen (src/game/director.lua, Settings "Boss
-- Encounters"). Dev console: `encounter <id>` (`encounter off` sends a hazard away).
--
-- Two kinds:
--   * A bug you can fight: a real enemy from content/enemies (give it `encounter = true` and
--     spawn weight 0, see content/enemies/predators.lua), so the wave lasts until it is
--     killed; its own behaviour does the fighting. Set `enemy`.
--   * A stage hazard (`hazard = true`): an animal far too big to fight (content/bosses/sparrow.lua,
--     anteater.lua). No enemy, nothing to hit, it doesn't hold the wave up: its hooks attack the
--     arena (ants and player alike) until the wave is cleared, then `leave` plays it off.
--     Hooks get (world, h): h.st is its state, h.t its age, h.label / h.danger the HUD line.
return {
    name = "The Anteater",              -- banner title (and its health bar unless `title`)
    description = "Banner line under it.",
    enemy = "antlion",                  -- id from content/enemies (fightable kind)
    -- hazard = true,                   -- stage hazard kind instead (no `enemy`)
    -- pictures = { "anteater" },       -- src/gfx/beasts.lua pictures to paint before it arrives
    -- start = function(world, h) end, update = function(world, h, dt) end,      (hazards)
    -- leave = function(world, h, dt) end, leaveTime = 3, survived = "IT WANDERS OFF",
    weight = 10, minWave = 5,           -- picked by weight, ones not met yet first
    -- arrive = 5,                      -- seconds into the wave it comes in
    -- entry = function(world) return x, y end,     -- where it appears (default: well away from the player)
    xp = 25,                            -- bonus XP when it falls
    -- slain = "ANTEATER DRIVEN OFF",   -- popup when it falls
    -- start = function(world, e, enc) end, update = function(world, e, enc, dt) end, finish = function(world, enc) end,
    -- drawGround / drawAir = function(world, e, enc) end,
}
