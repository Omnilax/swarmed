-- Take wing (dragonfly): hold Shift to fly, burning stamina (src/game/stamina.lua). Flying is
-- the dragonfly's only way to move: on the ground it can't walk at all (groundSpeed 0), it just
-- rests, strikes and refills. Keep Shift held and it hops back up by itself as soon as it has
-- caught its breath (params.minStart of the bar), so flying feels like steering. In the air it flies fast and free, and up
-- there only flying enemies (bees, wasps, hornets, flying ants) can touch it, while its own
-- strikes still reach everything. Letting go (or running dry) lands it with a downdraft that
-- blows ants back. Stamina only refills on the ground.
-- params: stamina (seconds of flight, 4), regen (1/s), speed (x in the air, 1), groundSpeed
--         (x walking on the ground, 0 = can't walk), height (12), downdraft (landing damage, 8), radius (landing gust, 40)
local Stamina = require("src.game.stamina")
local Combat = require("src.game.combat")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

-- Is this damage source something that flies?
local function flies(source)
    if type(source) ~= "table" or not source.def then return false end
    local def = source.def
    if def._flies == nil then
        def._flies = false
        for _, t in ipairs(def.tags or {}) do if t == "flying" then def._flies = true end end
    end
    return def._flies
end

-- Player:hurt asks this first: true means the hit is ignored.
local function ward(player, amount, source)
    if not player.airborne then return false end
    if source == "venom" or source == "test" or source == "sandbox" then return false end
    return not flies(source)
end

local function state(player)
    local f = player.flight
    if not f then
        f = { z = 0, wing = 0 }
        player.flight = f
        player.ward = ward
    end
    return f
end

local function lift(player, dt, params)
    local f = state(player)
    local want = player.airborne and (params.height or 12) or 0
    f.z = f.z + (want - f.z) * math.min(1, dt * 10)
    f.wing = f.wing + dt
    player.liftZ = f.z > 0.2 and f.z or nil
end

local def = Stamina.mode({
    name = "Take Wing",
    description = "Hold to fly: your only way to move. Burns stamina; only flying enemies can reach you up there. Landing blows ants back, and you take off again as soon as you have rested.",
    speed = 1,
    enter = function(player, world, params)
        state(player)
        player.airborne = true
        player.moveMul = 1
        world.particles:burst(player.x, player.y, 8, { { 0.7, 0.66, 0.58 } }, 80, 10, { grav = 60 })
        Audio.play("dash", { pitch = 2.2 })
    end,
    tick = function(player, world, dt, params) lift(player, dt, params) end,
    exit = function(player, world, params)
        if not player.airborne then return end
        player.airborne = false
        local r = (params.radius or 40) * (1 + player.stats:get("area") / 100)
        Combat.area(world, player.x, player.y, r, params.downdraft or 8, { knockback = 220 })
        world:addFx({ kind = "ring", x = player.x, y = player.y, r = r, life = 0.25, color = { 0.75, 0.9, 1 } })
        world.particles:burst(player.x, player.y, 10, { { 0.7, 0.66, 0.58 } }, 110, 20, { grav = 120 })
        Audio.play("dash", { pitch = 0.8 })
    end,
    idle = function(player, world, dt, params)
        player.moveMul = params.groundSpeed or 0
        lift(player, dt, params)
    end,
    draw = function(player, world, params)
        local f = player.flight
        if not f or player.dead then return end
        local lg = love.graphics
        -- four long clear wings held out flat; in the air they beat into a shimmering blur
        local c, s = math.cos(player.wangle), math.sin(player.wangle)
        for k = -1, 1, 2 do
            for w = 0, 1 do
                local u = (w == 0 and 2.5 or -2.5) * 0.7
                local beat = player.airborne and (0.55 + 0.45 * math.sin(f.wing * 70 + w * 2)) or 1
                local span = 9 * beat
                local bx, by = Iso.toScreen(player.x + c * u, player.y + s * u, f.z + 3)
                local ex, ey = Iso.toScreen(player.x + c * (u - 1.5) - s * k * span * 1.9, player.y + s * (u - 1.5) + c * k * span * 1.9, f.z + 3)
                local ang = math.atan2(ey - by, ex - bx)
                local len = math.sqrt((ex - bx) ^ 2 + (ey - by) ^ 2)
                lg.push()
                lg.translate((bx + ex) / 2, (by + ey) / 2)
                lg.rotate(ang)
                lg.setColor(0.85, 0.93, 1, player.airborne and 0.18 or 0.28)
                lg.ellipse("fill", 0, 0, len / 2, player.airborne and 2.6 or 2)
                lg.setColor(0.75, 0.85, 0.95, player.airborne and 0.25 or 0.55)
                lg.ellipse("line", 0, 0, len / 2, player.airborne and 2.6 or 2)
                lg.setColor(0.25, 0.18, 0.1, 0.8)
                lg.rectangle("fill", math.floor(len / 2 - 2), -1, 1, 1)      -- pterostigma
                lg.pop()
            end
        end
        lg.setColor(1, 1, 1, 1)
    end,
})
def.flies = flies
return def
