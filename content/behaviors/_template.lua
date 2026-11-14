-- TEMPLATE (ignored because the file name starts with "_"). Copy to my_behavior.lua.
-- The id is the file name. Enemies pick it with  behavior = "my_behavior".
return {
    name = "My Behaviour",
    -- Optional: called when an enemy spawns. Store per-enemy state in e.st (cleared on reuse).
    init = function(e, world, params) end,
    -- Required: set e.mx, e.my to the desired velocity (world units per second).
    -- Useful fields: e.x, e.y, e.speed, e.radius, e.hp, world.player.x/y, world:queryEnemies(x, y, r)
    update = function(e, world, dt, params)
        e.mx, e.my = 0, 0
    end,
    -- Optional: draw a telegraph/warning (projected space; see content/behaviors/charge.lua).
    draw = function(e, world) end,
}
