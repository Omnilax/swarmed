-- Dig (mole cricket): hold Shift to dig down and tunnel along, burning stamina
-- (src/game/stamina.lua). Underground it is much faster, steers sharply (on top it is clumsy and
-- slides about, see `movement.slide` on the character) and nothing can touch it; the ants lose
-- track of it (player.cloakT, as camouflage). Its normal moves are locked while down there:
--   * attack  -> bursts up out of the ground with a huge double-claw uppercut in front;
--   * special -> EARTHQUAKE: the ground heaves all round, hurting and stunning everything near,
--                and it surfaces in the middle of it.
-- Letting go of Shift, or running out of stamina, just pops it back up with no attack, out in
-- the open. Stamina refills slowly (low `regen`), so a dig has to count. Shift must be let go
-- before it can dig again.
-- params: stamina (3.5 s), regen (0.3/s), minStart (0.5 of the bar), speed (x walk speed, 2),
--         strike (uppercut damage, 26), strikeRadius (54), strikeArc (radians, 3.4),
--         quake (earthquake damage, 24), quakeRadius (100), quakeStun (s, 1)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Audio = require("src.core.audio")
local Input = require("src.core.input")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")
local util = require("src.core.util")

local SOIL = { { 0.5, 0.38, 0.26 }, { 0.38, 0.28, 0.19 }, { 0.62, 0.5, 0.36 } }

-- buttons, the same way Player:update reads them (title-screen demo, move preview pilot)
local function pressed(world, id)
    if world.pilot then return world.pilot.pressed[id] == true end
    if world.flags.demo then return false end
    return Input.pressed(id)
end
local function down(world, id)
    if world.pilot then return world.pilot.down[id] == true end
    if world.flags.demo then return false end
    return Input.down(id)
end

local function area(player) return 1 + player.stats:get("area") / 100 end

-- burst up with both shovels swiping out in front
local function uppercut(player, world, params)
    local r = (params.strikeRadius or 54) * area(player)
    local ang, half = math.atan2(player.aimY, player.aimX), (params.strikeArc or 3.4) / 2
    local hits = Combat.collect(world, player.x, player.y, r, function(e, dx, dy)
        return math.abs(util.angleDiff(ang, math.atan2(dy, dx))) <= half
    end)
    for _, e in ipairs(hits) do
        local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
        Combat.damage(world, e, params.strike or 26, { knockback = 300, kbx = nx, kby = ny, stun = 0.3 })
    end
    world:addFx({ kind = "arc", x = player.x, y = player.y, r = r, a = ang, arc = half * 2, dir = 1, life = 0.22, color = { 1, 0.85, 0.6 } })
    world.particles:burst(player.x + player.aimX * 10, player.y + player.aimY * 10, 22, SOIL, 170, 130, { grav = 340 })
    world.camera:shake(0.1 + math.min(0.1, #hits * 0.01))
    Audio.play("boom", { pitch = 1.5, volume = 0.6 })
    player.attack.timer = player:takeCooldown(player.attack.params.cooldown)
    player.lungeT, player.wangle = 0.18, ang
    require("src.gfx.anim").move(player, "attack", player.attack.params)
end

-- the ground heaves all round: rings of rolling dirt, everything near is hurt and stunned
local function earthquake(player, world, params)
    local r = (params.quakeRadius or 100) * area(player)
    for _, e in ipairs(Combat.collect(world, player.x, player.y, r)) do
        local nx, ny = util.normalize(e.x - player.x, e.y - player.y)
        local d = util.len(e.x - player.x, e.y - player.y)
        local k = 1 - 0.4 * math.min(1, d / r)         -- strongest at the middle
        Combat.damage(world, e, (params.quake or 24) * k, { knockback = 180, kbx = nx, kby = ny, stun = params.quakeStun or 1 })
    end
    for i = 0, 2 do
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r * (0.45 + i * 0.28), life = 0.3 + i * 0.1, color = { 0.85, 0.7, 0.5 } })
    end
    for i = 1, 14 do
        local a = i / 14 * math.pi * 2
        world.particles:burst(player.x + math.cos(a) * r * 0.6, player.y + math.sin(a) * r * 0.6, 3, SOIL, 90, 110, { grav = 320 })
        world.pendingSplats[#world.pendingSplats + 1] = { kind = "drop", player.x + math.cos(a) * r * 0.5, player.y + math.sin(a) * r * 0.5, SOIL[2], 4 }
    end
    world.camera:shake(0.35)
    Audio.play("boom", { pitch = 0.7, volume = 0.9 })
    -- the toss button that set it off must not throw sand too this frame
    if player.secondary then player.secondary.timer = math.max(player.secondary.timer, 0.4) end
end

return Stamina.mode({
    name = "Dig",
    description = "Hold to dig in: fast, precise and untouchable underground. Attack to burst out with an uppercut, special for an earthquake. Letting go just surfaces.",
    speed = 2,
    iframes = 0.2,
    canEnter = function(player) return not player.moleNeedRelease end,
    idle = function(player, world)
        if player.moleNeedRelease and not down(world, "dash") then player.moleNeedRelease = nil end
    end,
    enter = function(player, world, params)
        player.hidden = true
        player.cloakT = {}
        player.digId = player.cloakT
        player.slideNow = false                  -- precise underground
        player.moleSurface, player.digT = nil, 0
        world.particles:burst(player.x, player.y, 14, SOIL, 90, 60, { grav = 300 })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = 16, life = 0.2, color = { 0.8, 0.65, 0.45 } })
        Audio.play("dash", { pitch = 0.5 })
    end,
    tick = function(player, world, dt, params)
        player.iframes = math.max(player.iframes, 0.1)
        -- the normal moves are swapped for the surfacing ones while down here
        if pressed(world, "attack") then
            player.moleSurface = "strike"
            Stamina.stop(player)
            return
        elseif pressed(world, "secondary") then
            player.moleSurface = "quake"
            Stamina.stop(player)
            return
        end
        player.attack.timer = math.max(player.attack.timer, 0.05)
        if player.secondary then player.secondary.timer = math.max(player.secondary.timer, 0.05) end
        -- a ridge of loose soil heaves up along the tunnel
        player.digT = (player.digT or 0) + dt
        if player.digT > 0.05 then
            player.digT = 0
            world.particles:spawn(player.x + (love.math.random() - 0.5) * 8, player.y + (love.math.random() - 0.5) * 8, 2,
                (love.math.random() - 0.5) * 30, (love.math.random() - 0.5) * 30, 30, 0.5, SOIL[1 + love.math.random(0, 2)], 2, { grav = 240 })
            world.pendingSplats[#world.pendingSplats + 1] = { kind = "drop", player.x, player.y, SOIL[2], 3 }
        end
    end,
    -- a moving hump of soil with the cricket's dark shape in it, so you can see where you are
    draw = function(player, world, params)
        if not player.hidden or player.dead or player.digId ~= player.cloakT then return end
        local lg = love.graphics
        local gx, gy = Iso.toScreen(player.x, player.y)
        local wob = math.sin(world.time * 12) * 0.05
        lg.setColor(0.36, 0.27, 0.18, 0.7)
        lg.ellipse("fill", math.floor(gx), math.floor(gy + 1), 13 + wob * 20, 6.5)
        lg.setColor(0.55, 0.43, 0.3, 0.8)
        lg.ellipse("fill", math.floor(gx), math.floor(gy), 9 + wob * 14, 4)
        Sprites.drawModel(player.model, math.floor(player.anim) + 1, math.floor(gx), math.floor(gy + 1), player.wangle, false,
            0.9 + wob, 0.75 - wob, 0.35, { tint = { 0.1, 0.07, 0.05 }, bob = 0 })
        lg.setColor(1, 1, 1, 1)
    end,
    exit = function(player, world, params, dry)
        player.hidden = nil
        if player.cloakT == player.digId then player.cloakT = nil end
        player.digId = nil
        player.slideNow = nil
        -- out of the ground the clumsiness comes back, carrying on the way it was going
        player.slideVX, player.slideVY = player.vx or 0, player.vy or 0
        local how = player.moleSurface
        player.moleSurface, player.moleLast = nil, how     -- moleLast: skill tree procs read how it came up
        player.moleNeedRelease = true            -- let go of Shift before digging again
        if player.dead then return end
        world.particles:burst(player.x, player.y, 10, SOIL, 80, 70, { grav = 300 })
        if how == "strike" then
            uppercut(player, world, params)
            player.iframes = math.max(player.iframes, 0.25)
        elseif how == "quake" then
            earthquake(player, world, params)
            player.iframes = math.max(player.iframes, 0.3)
        else
            Audio.play("dash", { pitch = 0.7, volume = 0.5 })   -- just pops up: no damage
        end
    end,
})
