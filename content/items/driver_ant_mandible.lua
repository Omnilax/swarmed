-- A driver ant's jaw: the column never stops, and neither can you.
local ItemFx = require("src.game.itemfx")

return {
    name = "Driver Ant Mandible",
    description = "+40% Damage, +10% Attack Speed. Cursed: standing still for over a second makes you bleed 5 HP a second.",
    curse = "Standing still for over a second makes you bleed 5 HP a second.",
    rarity = "cursed",
    category = "cursed",
    size = { 1, 2 },
    stats = { damage = 40, attackSpeed = 10 },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx)
                local p = ctx.player
                local s = ItemFx.state(p, "driver_ant_mandible")
                local dx, dy = p.x - (s.x or p.x), p.y - (s.y or p.y)
                s.x, s.y = p.x, p.y
                if dx * dx + dy * dy > 0.01 or (p.dashT or 0) > 0 then s.still = 0 return end
                s.still = (s.still or 0) + ctx.dt
                if s.still > 1 and ctx.world.spawner and ctx.world.spawner.phase == "wave" then
                    s.bleed = (s.bleed or 0) + ctx.dt * 5
                    if s.bleed >= 1 then
                        local n = math.floor(s.bleed)
                        s.bleed = s.bleed - n
                        p.hp = math.max(1, p.hp - n)
                        ctx.world.particles:spawn(p.x, p.y, 3, 0, 0, 20, 0.4, { 0.8, 0.15, 0.1 }, 1, {})
                    end
                end
            end,
        },
    },
    tags = { "cursed", "offense", "bug" },
}
