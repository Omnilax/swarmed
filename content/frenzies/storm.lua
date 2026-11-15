-- Flyers' super move: a storm of lightning that strikes the swarm all over the screen and
-- jumps from ant to ant.
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

return {
    name = "Thunderstorm",
    description = "Lightning strikes all over the screen and jumps through the swarm.",
    color = "#8fd8ff",
    tags = { "flying" },
    params = { time = 1.6, rate = 0.05, radius = 260, damage = 22, jumps = 5, range = 60, bossShare = 0.025 },
    buff = { time = 5, stats = { attackSpeed = { 30, 0 }, moveSpeed = { 25, 0 } } },
    start = function(ctx)
        ctx.next = 0
        ctx.world.camera:shake(0.5)
        Audio.play("zap", { pitch = 0.6 })
    end,
    update = function(ctx, dt)
        local w, p, pr = ctx.world, ctx.player, ctx.params
        ctx.next = ctx.next - dt
        while ctx.next <= 0 do
            ctx.next = ctx.next + pr.rate
            local list = Combat.collect(w, p.x, p.y, pr.radius)
            local e = list[love.math.random(math.max(1, #list))]
            if e then
                -- a bolt from the sky, then it arcs on through the crowd
                w:addFx({ kind = "bolt", x = e.x, y = e.y - 1, x2 = e.x + (love.math.random() - 0.5) * 6, y2 = e.y - 60, life = 0.15, color = { 0.7, 0.9, 1 } })
                w:addFx({ kind = "ring", x = e.x, y = e.y, r = 14, life = 0.2, color = { 0.6, 0.85, 1 } })
                local base = pr.damage + (e.def.boss and e.maxHp * pr.bossShare or e.maxHp * 0.6)
                Combat.damage(w, e, base, { noCrit = true, procDepth = 1, ignoreShield = true, source = "frenzy" })
                Combat.chain(w, e, pr.jumps, pr.range, pr.damage, { procDepth = 1, noCrit = true, color = { 0.7, 0.9, 1 } })
            end
        end
        return ctx.t >= pr.time
    end,
}
