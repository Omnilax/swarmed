-- A lobbed cone that bursts where it lands, throwing its scales in every direction.
-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.5, 0.32, 0.16 }
local PFX_2 = { 0.7, 0.5, 0.3 }
local PFX_LIST_1 = { PFX_1, PFX_2 }

return {
    name = "Pine Cone",
    description = "Hits have a 6% chance to lob a pine cone that bursts into 6 scales, each hitting for 8 damage (+8 per stack).",
    rarity = "rare",
    category = "elemental",
    size = { 2, 2 },
    procs = {
        {
            trigger = "onHit",
            chance = 0.06,
            effect = function(ctx, stacks)
                local w, p = ctx.world, ctx.player
                local dx, dy = ctx.x - p.x, ctx.y - p.y
                w.hazards:shoot({ bomb = true, x = p.x, y = p.y, z = 8, vx = dx * 1.1, vy = dy * 1.1, vz = 65, grav = 130,
                    r = 3, damage = 0, life = 3, pebble = true, color = { 0.55, 0.35, 0.18 },
                    onEnd = function(world, s)
                        for i = 1, 6 do
                            local a = i / 6 * math.pi * 2
                            world.hazards:friendlyShot({ x = s.x, y = s.y, z = 4, vx = math.cos(a) * 160, vy = math.sin(a) * 160,
                                r = 2, damage = 8 * stacks, pierce = 1, life = 0.4, knockback = 60, color = { 0.75, 0.5, 0.25 }, procDepth = 1 })
                        end
                        world.particles:burst(s.x, s.y, 8, PFX_LIST_1, 80, 50)
                    end })
            end,
        },
    },
    tags = { "proc", "explosive", "plant" },
}
