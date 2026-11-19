-- Ichneumon wasp: lays its eggs inside other insects with a long needle (the ovipositor). It
-- lines up (the needle line), stabs, and if it hits, a clutch of eggs is stuck in you: a few
-- seconds later they hatch into grubs right where you stand. Sidestep the line.
-- params: range (stab reach, 30), windup (0.6), hatch (seconds, 5), larvae (grubs per clutch, 3),
--         larva (enemy id, "ichneumon_larva"), cooldown (3)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.95, 0.92, 0.8 }
local PFX_2 = { grav = 200 }
local PFX_LIST_1 = { PFX_1 }

local function eggsUpdate(world, z, dt)
    local p = world.player
    z.x, z.y = p.x, p.y
    if z.t >= z.hatch and not z.done then
        z.done = true
        for i = 1, z.count do
            local a = i / z.count * math.pi * 2
            world:spawnEnemy(z.larva, p.x + math.cos(a) * 8, p.y + math.sin(a) * 8)
        end
        world:floatText(p.x, p.y, "HATCHED", { 0.95, 0.9, 0.75 }, false)
        world.particles:burst(p.x, p.y, 8, PFX_LIST_1, 50, 40, PFX_2)
        Audio.play("kill", { pitch = 0.6 })
        z.t = z.maxLife
    end
end

-- little pale eggs clinging round your feet, pulsing faster as they get ready
local function eggsDraw(z, sx, sy)
    local k = z.t / z.hatch
    local lg = love.graphics
    for i = 1, z.count do
        local a = i / z.count * math.pi * 2 + 0.6
        local x, y = math.floor(sx + math.cos(a) * 5), math.floor(sy + math.sin(a) * 2.5)
        lg.setColor(0.98, 0.95, 0.82, 0.7 + 0.3 * math.sin(z.t * (4 + k * 20)))
        lg.rectangle("fill", x, y, 2, 1)
    end
end

return {
    name = "Egg layer",
    init = function(e) e.st.mode, e.st.cd = "approach", 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        e.biteCd = 1
        local range = params.range or 30
        if st.mode == "approach" then
            AI.hover(e, world, dt, 6)
            st.cd = st.cd - dt
            local want = d > range * 0.8 and 1 or -0.5
            e.mx, e.my = dx / d * e.speed * want, dy / d * e.speed * want
            if st.cd <= 0 and d < range * 1.1 then st.mode, st.t, st.dx, st.dy = "windup", params.windup or 0.6, dx / d, dy / d end
        elseif st.mode == "windup" then
            e.mx, e.my = st.dx * 1.5, st.dy * 1.5
            AI.hover(e, world, dt, 3)
            st.t = st.t - dt
            if st.t <= 0 then
                -- stab along the locked line
                local ex, ey = e.x + st.dx * range, e.y + st.dy * range
                local vx, vy = ex - e.x, ey - e.y
                local t = math.max(0, math.min(1, ((p.x - e.x) * vx + (p.y - e.y) * vy) / (vx * vx + vy * vy)))
                local cx, cy = e.x + vx * t - p.x, e.y + vy * t - p.y
                world:addFx({ kind = "stab", x = e.x, y = e.y, x2 = ex, y2 = ey, w = 2, life = 0.2, color = { 0.95, 0.9, 0.7 } })
                if cx * cx + cy * cy < (p.radius + 2) ^ 2 and not p.dead and p.dashT <= 0 then
                    AI.sting(e, world, 1)
                    local hatch = params.hatch or 5
                    world.hazards:addZone({ kind = "eggs", x = p.x, y = p.y, r = 1, life = hatch + 1, hatch = hatch,
                        count = params.larvae or 3, larva = params.larva or "ichneumon_larva", color = { 1, 1, 1 },
                        update = eggsUpdate, draw = eggsDraw })
                    world:floatText(p.x, p.y, "EGGS LAID IN YOU", { 0.95, 0.9, 0.75 }, false)
                end
                Audio.play("hit", { pitch = 1.4 })
                st.mode, st.t = "back", 0.8
            end
        else
            AI.hover(e, world, dt, 8)
            e.mx, e.my = -dx / d * e.speed, -dy / d * e.speed
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.cd = "approach", params.cooldown or 3 end
        end
    end,
    draw = function(e)
        local st = e.st
        if st.mode ~= "windup" then return end
        local r = e.params.range or 30
        local x1, y1 = Iso.toScreen(e.x, e.y)
        local x2, y2 = Iso.toScreen(e.x + st.dx * r, e.y + st.dy * r)
        love.graphics.setColor(1, 0.95, 0.7, math.floor(st.t * 14) % 2 == 0 and 0.8 or 0.35)
        love.graphics.line(x1, y1, x2, y2)
    end,
}
