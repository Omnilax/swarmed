-- TEMPLATE. Copy to content/props/my_prop.lua. Props are things in the arena that are neither
-- the player nor an enemy (src/game/props.lua): they never hold a wave up and ants ignore them.
-- Spawn one with world.props:spawn(id, x, y, opts) (opts fields are copied onto the instance);
-- a stage lists the shovable ones it starts with in `props = { pebble = 6, twig = 2 }`.
return {
    name = "My Prop",
    radius = 6,
    -- Pushable props: walk into them to roll them along, dash or attack to launch them; moving
    -- faster than crushSpeed they flatten every ant they roll over (damage, scaled by speed).
    pushable = true, mass = 2, friction = 2.5, crushSpeed = 55, damage = 14,
    batSpeed = 230, dashSpeed = 280, roll = true,
    -- max = 8, life = 60,      -- at most this many at once (the oldest goes); seconds before it goes
    -- length = 40,              -- a long prop (a stick): collides as a line and rolls side-on
    -- hp = 3, onHit = function(world, o, hits, dx, dy) end,   -- the player's attacks / dashes
    -- init = function(world, o) end, update = function(world, o, dt) end, remove = function(world, o) end,
    -- label = function(world, o) return "text", color end,     -- text above it (HUD)
    -- labels = function(world, o) return { { text = "a", x = o.x, y = o.y, z = 20, align = "left" } } end,
    -- A map gamble (src/game/gambles.lua): the director may place it in a wave and it goes when
    -- the next wave starts unless o.busy. leave(world, o) is called to send it off.
    -- gamble = { weight = 10, minWave = 2, allowed = function(world) return true end, text = "banner line", color = { 1, 1, 1 } },
    draw = function(world, o, sx, sy) end,     -- on the ground, under the crowd (projected coords)
    -- drawAir = function(world, o, sx, sy) end,
}
