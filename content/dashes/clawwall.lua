-- Claw wall (emperor scorpion): hold Shift to brace both huge claws out in front, burning
-- stamina (src/game/stamina.lua). Bites and shots from the front glance off the claws, and the
-- ants in front get bulldozed along ahead of you. Letting go throws the claws apart, shoving
-- everything nearby away (Player:releaseShove).
-- params: stamina (3), regen (1), speed (walk speed x while braced, 0.6), guard (front arc
--         half-width in radians, 1.1), ram (damage per shove, 3), every (seconds between
--         shoves on the same ant, 0.45), push (how hard ants are pushed ahead, 160),
--         releaseRadius (46), releaseShove (320)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local function inFront(player, x, y, arc)
    local dx, dy, l = util.normalize(x - player.x, y - player.y)
    if l < 1 then return true end
    return dx * player.aimX + dy * player.aimY >= math.cos(arc)
end

local function ward(player, amount, source)
    local params = player.dashParams
    if type(source) == "table" and source.x and inFront(player, source.x, source.y, params.guard or 1.1) then
        if player.blockFxT <= 0 then
            player.blockFxT = 0.15
            local world = player.world
            world.particles:sparks(player.x + player.aimX * 12, player.y + player.aimY * 12, 4, { 0.75, 0.82, 1 }, player.aimX, player.aimY, 2.5, 90)
            Audio.play("hit", { pitch = 1.7 })
        end
        return true
    end
    return player.clawWard and player.clawWard(player, amount, source)
end

return Stamina.mode({
    name = "Claw Wall",
    description = "Hold to brace your claws in front: hits from the front glance off and ants ahead are bulldozed along. Let go to throw them back.",
    speed = 0.6,
    iframes = 0.1,
    enter = function(player, world, params)
        player.clawWard, player.ward = player.ward, ward
        player.wallHit = setmetatable({}, { __mode = "k" })
        Audio.play("equip", { pitch = 0.6 })
    end,
    tick = function(player, world, dt, params)
        local now = world.time
        local ax, ay = player.aimX, player.aimY
        local cx, cy = player.x + ax * (player.radius + 8), player.y + ay * (player.radius + 8)
        for _, e in ipairs(Combat.collect(world, cx, cy, 12)) do
            if inFront(player, e.x, e.y, 1.2) then
                local push = (params.push or 160) / math.max(0.5, e.mass) ^ 0.5
                e.kvx, e.kvy = e.kvx + ax * push * dt * 8, e.kvy + ay * push * dt * 8
                if (player.wallHit[e] or -1) < now then
                    player.wallHit[e] = now + (params.every or 0.45)
                    Combat.damage(world, e, params.ram or 3, { knockback = 60, kbx = ax, kby = ay })
                end
            end
        end
    end,
    exit = function(player, world, params)
        if player.ward == ward then player.ward = player.clawWard end
        player.clawWard, player.wallHit = nil, nil
        if not player.dead then player:releaseShove(params) end
    end,
})
