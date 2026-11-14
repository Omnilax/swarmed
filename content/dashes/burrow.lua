-- Burrow (camel spider): hold Shift to dive under the sand and tunnel along, burning stamina
-- (src/game/stamina.lua). Underground it can't be bitten or attack, and the ants lose track of it
-- (player.cloakT, as camouflage). Let go, or run out of breath, and it erupts beneath the swarm,
-- flinging the ants above into the air.
-- params: stamina (2 s), regen (1/s), speed (x walk speed underground, 1.25), damage (eruption, 16),
--         radius (40)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")

local SAND = { { 0.72, 0.64, 0.5 }, { 0.55, 0.48, 0.38 } }

return Stamina.mode({
    name = "Burrow",
    description = "Hold to tunnel under the sand: untouchable and unseen. Let go to erupt beneath the swarm and throw them into the air.",
    speed = 1.25,
    iframes = 0.2,
    enter = function(player, world, params)
        player.hidden = true
        player.burrowT = 0
        player.cloakT = {}
        player.burrowId = player.cloakT
        world.particles:burst(player.x, player.y, 12, SAND, 90, 50, { grav = 300 })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = 14, life = 0.2, color = { 0.9, 0.8, 0.6 } })
        Audio.play("dash", { pitch = 0.6 })
    end,
    tick = function(player, world, dt, params)
        player.iframes = math.max(player.iframes, 0.1)
        player.attack.timer = math.max(player.attack.timer, 0.05)
        if player.secondary then player.secondary.timer = math.max(player.secondary.timer, 0.05) end
        -- the sand heaves up along the tunnel
        player.burrowT = (player.burrowT or 0) + dt
        if player.burrowT > 0.04 then
            player.burrowT = 0
            world.particles:spawn(player.x + (love.math.random() - 0.5) * 6, player.y + (love.math.random() - 0.5) * 6, 2,
                (love.math.random() - 0.5) * 40, (love.math.random() - 0.5) * 40, 40, 0.5, { 0.66, 0.58, 0.45 }, 2, { grav = 260 })
            world.pendingSplats[#world.pendingSplats + 1] = { kind = "drop", player.x, player.y, { 0.5, 0.44, 0.36 }, 2 }
        end
    end,
    -- the spider's dark shape moving under the sand, so you can see where you are
    draw = function(player, world, params)
        if not player.hidden or player.dead then return end
        local lg = love.graphics
        local gx, gy = Iso.toScreen(player.x, player.y)
        local wob = math.sin(world.time * 14) * 0.04
        lg.setColor(0.05, 0.04, 0.03, 0.32)
        lg.ellipse("fill", math.floor(gx), math.floor(gy + 2), 11 + wob * 20, 5.5)
        Sprites.drawModel(player.model, math.floor(player.anim) + 1, math.floor(gx), math.floor(gy + 2), player.wangle, false,
            1 + wob, 0.85 - wob, 0.5, { tint = { 0.08, 0.06, 0.05 }, bob = 0 })
        lg.setColor(1, 1, 1, 1)
    end,
    exit = function(player, world, params)
        player.hidden = nil
        if player.cloakT == player.burrowId then player.cloakT = nil end
        player.burrowId = nil
        if player.dead then return end
        -- erupt
        local r = (params.radius or 40) * (1 + player.stats:get("area") / 100)
        for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
            Combat.damage(world, e, params.damage or 16, { knockback = 220, kbx = e.x - player.x, kby = e.y - player.y })
        end
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.3, color = { 1, 0.85, 0.55 } })
        world.particles:burst(player.x, player.y, 24, { { 0.75, 0.66, 0.5 }, { 0.58, 0.5, 0.4 }, { 0.9, 0.82, 0.66 } }, 160, 120, { grav = 320 })
        world.camera:shake(0.12)
        Audio.play("boom", { pitch = 1.3, volume = 0.7 })
        player.iframes = math.max(player.iframes, 0.35)
    end,
})
