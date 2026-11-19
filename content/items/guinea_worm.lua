-- Parasite (src/game/parasites.lua). A burning worm under the skin: keep moving and the ground
-- you cross smoulders and burns the ants; stand still and it burns you.
local Parasites = require("src.game.parasites")
local ItemFx = require("src.game.itemfx")

local COL = { 1, 0.45, 0.15 }

return {
    name = "Guinea Worm",
    description = "Fire walker: while you move you leave a trail of burning ground (poison, stronger each wave). +15 Speed. Devours Dew Drops in your bag (+8 Speed each).",
    effect = "Walking leaves burning ground.",
    curse = "Standing still burns you (4 HP/s).",
    rarity = "parasite", category = "cursed", parasite = true,
    size = { 2, 1 },
    stats = { moveSpeed = 15 },
    feeds = { ids = { "dew_drop" }, stats = { moveSpeed = 8 } },
    procs = {
        {
            trigger = "onTick",
            effect = function(ctx)
                local p, w = ctx.player, ctx.world
                if not Parasites.live(w) then return end
                local s = ItemFx.state(p, "guinea_worm")
                if p.moving then
                    s.still = 0
                    if ItemFx.every(ctx, "guinea_worm", 0.22) then
                        local wave = w.spawner and w.spawner.wave or 1
                        ItemFx.patch(w, { x = p.x, y = p.y, r = 14, life = 2.2, dps = 6 + wave * 0.8, color = COL })
                    end
                else
                    s.still = (s.still or 0) + ctx.dt
                    if s.still > 0.4 then
                        Parasites.drain(p, 4 * ctx.dt)
                        if love.math.random() < ctx.dt * 6 then w.particles:burst(p.x, p.y, 2, { COL }, 30, 30, { glow = true, grav = -30 }) end
                    end
                end
            end,
        },
    },
    tags = { "fire", "mobility" },
}
