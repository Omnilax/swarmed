-- Tail stab (centipede): the last pair of legs are long, hooked pincers. It whips its rear end
-- up and stabs backwards, wherever its tail is pointing, skewering a line of ants with venom
-- and yanking the first one back toward the body.
-- params: damage, cooldown, range (60), width (7), poison ({dps, seconds}), knockback, color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

return {
    name = "Tail Stab",
    range = function(params) return params.range or 60 end,
    fire = function(player, world, ax, ay, params)
        -- from the tail, pointing away from the body (straight behind if there is no chain)
        local tx, ty, dx, dy = player.x - ax * 20, player.y - ay * 20, -ax, -ay
        local ch = player.chain
        if ch and #ch >= 4 then
            local a, b = ch[#ch], ch[#ch - 3]
            tx, ty = a.x, a.y
            dx, dy = util.normalize(a.x - b.x, a.y - b.y)
        end
        local reach = (params.range or 60) * (1 + player.stats:get("area") / 100)
        local x2, y2 = tx + dx * reach, ty + dy * reach
        local hits = Combat.collectLine(world, tx, ty, x2, y2, params.width or 7)
        table.sort(hits, function(p, q) return (p.x - tx) ^ 2 + (p.y - ty) ^ 2 < (q.x - tx) ^ 2 + (q.y - ty) ^ 2 end)
        for i, e in ipairs(hits) do
            -- the first one is hooked and dragged back; the rest are run through
            local kx, ky = i == 1 and -dx or dx, i == 1 and -dy or dy
            Combat.damage(world, e, params.damage * (i == 1 and 1.5 or 1), { knockback = params.knockback or 120, kbx = kx, kby = ky,
                poison = params.poison })
            world.particles:burst(e.x, e.y, 3, { { 0.75, 1, 0.3 } }, 40, 30, { glow = true })
        end
        world:addFx({ kind = "stab", x = tx, y = ty, x2 = x2, y2 = y2, w = 4, z = 7, life = 0.16, color = params.color or { 0.75, 1, 0.3 } })
        player.tailStab = { t = 0.22, dx = dx, dy = dy, reach = reach }
        Audio.play("zap", { pitch = 0.6 })
        if #hits >= 4 then world.camera:shake(0.05 + #hits * 0.004) end
    end,
    update = function(player, world, dt)
        local s = player.tailStab
        if s then
            s.t = s.t - dt
            if s.t <= 0 then player.tailStab = nil end
        end
    end,
}
