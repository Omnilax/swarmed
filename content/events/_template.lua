-- TEMPLATE. Copy to content/events/my_event.lua. Mid-wave events and moving hazards
-- (src/game/director.lua): a few are lined up in each wave from wave 2 (Settings "Mid-Wave
-- Events"), picked by weight. They never hold a wave up; anything still going ends with it.
-- Shared helpers for hurting ants / the player and drawing warnings: src/game/envfx.lua.
-- Dev console: `event <id>` starts one now.
return {
    name = "My Event",                  -- banner title
    description = "What is happening.", -- banner line under it
    -- color = { 1, 0.85, 0.45 },       -- banner colour; banner = false for none
    kind = "hazard",                    -- "hazard" (hurts) or "event" (helps / neutral); for the catalogue
    weight = 10,                        -- how often it is picked
    minWave = 2,                        -- maxWave = 9,
    -- stages = { "backyard" },         -- only on these stages (a stage's `events = { id = weight }` overrides)
    -- allowed = function(world) return true end,
    duration = 12,                      -- seconds; nil = until it sets ev.done = true
    start = function(world, ev) end,    -- ev = { def, t, st (your state), opts, life }
    update = function(world, ev, dt) end,
    -- env = function(world, ev, env) end,          -- change env.playerSpeed / enemySpeed / driftX / driftY / inset
    -- field = function(world, ev, x, y, who) return 1 end,   -- speed multiplier at a spot (who = "player" or the enemy)
    drawGround = function(world, ev) end,   -- under everything (projected coords)
    drawAir = function(world, ev) end,      -- over the crowd
    finish = function(world, ev) end,       -- also runs when the wave ends early
}
