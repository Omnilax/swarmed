-- Coil (millipede): hold right click to curl up into a tight armoured spiral, head tucked in
-- the middle. Coiled it can't move or attack, takes only a fraction of the damage, and oozes
-- toxin that burns every ant pressed against it. Uncurling releases all the stored toxin in one
-- burst; the longer you held, the bigger it is.
-- params: damage (burst at full hold), cooldown, guard (damage taken x, 0.15), radius (burst at
--         full hold, 80), ooze (damage per ooze tick, 3), time (to full, 2), max (hold, 3.5), color
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")

-- lay the chain out as a spiral around the head (rot turns the whole spiral)
local function spiral(player, rot)
    local chain = player.chain
    local sp = player.model.spacing
    local a, r = (rot or 0) + player.wangle + math.pi, 3
    for i, seg in ipairs(chain) do
        a = a - sp / r
        r = r + 0.5
        seg.x, seg.y = player.x + math.cos(a) * r, player.y + math.sin(a) * r
    end
end

local function coiled(p) spiral(p, 0) end

return {
    name = "Coil",
    range = function(params) return params.radius or 80 end,
    spiral = spiral,
    fire = function(player, world, ax, ay, params)
        player.coil = { t = 0, tick = 0 }
        player.guardMul = params.guard or 0.15
        player.moveMul = 0
        if player.chain then player.chainPose = coiled end
        Audio.play("equip", { pitch = 0.5 })
    end,
    update = function(player, world, dt, params, down)
        local c = player.coil
        if not c then return end
        c.t = c.t + dt
        player.attack.timer = math.max(player.attack.timer, 0.1)
        c.tick = c.tick - dt
        if c.tick <= 0 then
            c.tick = 0.4
            for _, e in ipairs(Combat.collect(world, player.x, player.y, 18)) do
                Combat.damage(world, e, params.ooze or 3, { knockback = 60, kbx = e.x - player.x, kby = e.y - player.y, noCrit = true, poison = { 3, 2 } })
            end
            world.particles:burst(player.x, player.y, 4, { params.color or { 0.95, 0.85, 0.35 } }, 30, 20, { glow = true, grav = -15 })
        end
        if down and c.t < (params.max or 3.5) then return end
        -- uncurl: the stored toxin bursts out
        local f = math.min(1, c.t / (params.time or 2))
        player.coil, player.guardMul, player.moveMul, player.chainPose = nil, nil, nil, nil
        local r = (params.radius or 80) * (0.35 + 0.65 * f) * (1 + player.stats:get("area") / 100)
        Combat.explode(world, player.x, player.y, r, params.damage * (0.3 + 0.7 * f), { color = params.color or { 0.95, 0.85, 0.35 },
            knockback = 150 + 100 * f, poison = { 4 + 6 * f, 3 } })
        world.particles:burst(player.x, player.y, 10 + math.floor(16 * f), { { 0.95, 0.85, 0.35 }, { 0.7, 0.8, 0.3 } }, 90 + 80 * f, 40, { glow = true, grav = -10 })
    end,
}
