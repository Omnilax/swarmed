-- The default super move: the bug slams the ground and a shockwave rolls out across the whole
-- screen. Ordinary ants are blown apart, queens lose a chunk of their health.
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Quake",
    description = "A shockwave that rolls across the whole screen and blows the swarm apart.",
    color = "#ffb040",
    params = { radius = 300, time = 0.6, damage = 30, bossShare = 0.12, knockback = 380 },
    buff = { time = 5, stats = { attackSpeed = { 35, 0 }, moveSpeed = { 15, 0 } } },
    start = function(ctx)
        local w, p = ctx.world, ctx.player
        ctx.r, ctx.ringT, ctx.hit = 0, 0, {}
        w.camera:shake(0.8)
        Audio.play("boom", { pitch = 0.5 })
        Audio.play("rumble", { pitch = 0.8 })
        w.particles:burst(p.x, p.y, 40, { { 1, 0.85, 0.4 }, { 1, 0.6, 0.2 }, { 1, 1, 0.8 } }, 220, 120, { glow = true, grav = 80 })
    end,
    update = function(ctx, dt)
        local w, p, pr = ctx.world, ctx.player, ctx.params
        local r0 = ctx.r
        ctx.r = math.min(pr.radius, pr.radius * (ctx.t / pr.time) ^ 0.7)
        ctx.ringT = ctx.ringT - dt
        if ctx.ringT <= 0 then
            ctx.ringT = 0.07
            w:addFx({ kind = "ring", x = p.x, y = p.y, r = ctx.r, life = 0.25, color = { 1, 0.75, 0.3 } })
        end
        -- everything the front has just passed over
        for _, e in ipairs(Combat.collect(w, p.x, p.y, ctx.r)) do
            if not ctx.hit[e] then
                local dx, dy = e.x - p.x, e.y - p.y
                if dx * dx + dy * dy >= (r0 - 12) ^ 2 or r0 == 0 then
                    ctx.hit[e] = true
                    local nx, ny = util.normalize(dx, dy)
                    local base = e.def.boss and (pr.damage + e.maxHp * pr.bossShare) or (pr.damage + e.maxHp * 1.5)
                    Combat.damage(w, e, base, { noCrit = true, knockback = pr.knockback, kbx = nx, kby = ny,
                        coefficient = 1, procDepth = 1, ignoreShield = true, source = "frenzy" })
                end
            end
        end
        return ctx.t >= pr.time
    end,
}
