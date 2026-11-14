-- Flip (centipede): hold Shift to swing the body round and aim the rear end where you point,
-- hooked tail pincers first. The head trails behind and your jabs stab out from the tail
-- (content/attacks/jabs.lua). Let go and the centipede whips itself back over in one sweep that
-- hits everything around it and throws the ants clear, with a short hop forward.
-- Uses a dash charge (refilled by Dash Cooldown).
-- params: damage (flip sweep, 14), radius (36), knockback (260), distance (hop, 30),
--         slow (move speed x while reversed, 0.85), charges
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Anim = require("src.gfx.anim")
local Charge = require("content.dashes._charge")

local FLIP_TIME = 0.2

-- reversed: the body stretches out ahead toward the aim, swinging there smoothly
local function reversedPose(p)
    local sp = p.model.spacing
    local ax, ay = math.cos(p.wangle), math.sin(p.wangle)
    for i, seg in ipairs(p.chain) do
        local bend = math.sin(p.world.time * 3 + i * 0.4) * math.min(1, i / 6) * 1.5
        local tx, ty = p.x + ax * (i * sp + 2) - ay * bend, p.y + ay * (i * sp + 2) + ax * bend
        seg.x, seg.y = seg.x + (tx - seg.x) * 0.3, seg.y + (ty - seg.y) * 0.3
    end
end

-- the flip: the body sweeps round from in front to behind
local function flipPose(p)
    local f = p.flip
    if not f then p.chainPose = nil return end
    local k = math.min(1, (p.world.time - f.t0) / FLIP_TIME)
    local a = f.a + f.dir * math.pi * k
    local sp = p.model.spacing
    for i, seg in ipairs(p.chain) do
        seg.x, seg.y = p.x + math.cos(a) * (i * sp + 2), p.y + math.sin(a) * (i * sp + 2)
    end
    if k >= 1 then p.flip, p.chainPose = nil, nil end
end

return {
    name = "Flip",
    description = "Hold to aim your rear end and jab with the tail; let go to whip back over, hitting everything around you and throwing the ants clear.",
    hold = true,
    update = function(player, world, dt, params, held)
        local r = player.reversed
        if r and (player.stunT > 0 or player.dead) then held = false end
        if held and not r then
            if not Charge.ready(player) or player.flip then return end
            player.reversed = { t = 0 }
            player.moveMul = params.slow or 0.85
            if player.chain then player.chainPose = reversedPose end
            Audio.play("dash", { pitch = 0.7, volume = 0.5 })
        elseif held then
            r.t = r.t + dt
        elseif r then
            player.reversed, player.moveMul = nil, nil
            Charge.spend(player)
            local ax, ay = player.aimX, player.aimY
            local rad = (params.radius or 36) * (1 + player.stats:get("area") / 100)
            for _, e in ipairs(Combat.collect(world, player.x, player.y, rad)) do
                local dx, dy = e.x - player.x, e.y - player.y
                local l = math.sqrt(dx * dx + dy * dy) + 0.001
                Combat.damage(world, e, params.damage or 14, { knockback = params.knockback or 260, kbx = dx / l, kby = dy / l })
            end
            world:addFx({ kind = "ring", x = player.x, y = player.y, r = rad, life = 0.25, color = { 0.9, 1, 0.5 } })
            world:addFx({ kind = "arc", x = player.x, y = player.y, r = rad * 0.8, a = player.wangle, arc = 6, life = 0.2, color = { 1, 0.85, 0.45 } })
            world.camera:shake(0.08)
            Audio.play("hit", { pitch = 0.8 })
            if player.chain then
                player.flip = { t0 = world.time, a = player.wangle, dir = love.math.random() < 0.5 and -1 or 1 }
                player.chainPose = flipPose
            end
            player:lunge(ax, ay, params.distance or 30, 1)
            Charge.fired(player, world, params)
        end
    end,
}
