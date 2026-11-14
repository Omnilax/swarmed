-- Lesser banded hornet: sprays venom from its sting as a fine mist. Keeps a little way off,
-- curls its abdomen forward (the cone shows where), and fills a cone in front of it with
-- clouds of venom mist that hang in the air and poison you while you stand in them.
-- params: keep (60), cooldown (4), windup (0.6), reach (60), clouds (4), radius (13),
--         life (4), dps (poison, 4)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local function mistUpdate(world, z, dt, inside)
    if inside then world.player:poison(z.dps, 1.5) end
    z.x, z.y = z.x + z.vx * dt, z.y + z.vy * dt
    z.vx, z.vy = z.vx * (1 - dt), z.vy * (1 - dt)
end

local function mistDraw(z, sx, sy, fade)
    local lg = love.graphics
    for i = 0, 2 do
        local a = z.t * 0.7 + i * 2.1
        lg.setColor(0.7, 0.4, 0.95, 0.16 * fade)
        lg.ellipse("fill", sx + math.cos(a) * z.r * 0.3, sy - 3 + math.sin(a) * z.r * 0.15, z.r * 0.9, z.r * 0.45)
    end
    lg.setColor(0.9, 0.7, 1, 0.5 * fade)
    for i = 0, 3 do
        local a = z.t * 1.7 + i * 1.6
        lg.rectangle("fill", math.floor(sx + math.cos(a) * z.r * 0.6), math.floor(sy - 4 + math.sin(a * 1.4) * z.r * 0.3), 1, 1)
    end
end

return {
    name = "Venom mist",
    init = function(e) e.st.mode, e.st.cd = "move", 2 + love.math.random() end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "move" then
            AI.hover(e, world, dt, d < 24 and 1 or 7)
            local keep = params.keep or 60
            local want = st.cd > 0.8 and 1 or util.clamp((d - keep) / 20, -1, 1)
            e.mx, e.my = dx / d * e.speed * want, dy / d * e.speed * want
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.5 then st.mode, st.t, st.dx, st.dy = "windup", params.windup or 0.6, dx / d, dy / d end
        else
            e.mx, e.my = st.dx * 1.5, st.dy * 1.5
            AI.hover(e, world, dt, 5)
            st.t = st.t - dt
            if st.t <= 0 then
                local n, reach = params.clouds or 4, params.reach or 60
                local base = math.atan2(st.dy, st.dx)
                for i = 1, n do
                    local a = base + (i - (n + 1) / 2) * 0.32
                    local r = reach * (0.45 + 0.4 * (i % 2))
                    world.hazards:addZone({ kind = "mist", x = e.x + math.cos(a) * r * 0.3, y = e.y + math.sin(a) * r * 0.3,
                        vx = math.cos(a) * r * 1.4, vy = math.sin(a) * r * 1.4, r = params.radius or 13, life = params.life or 4,
                        dps = (params.dps or 4) * e.damage / math.max(0.1, e.def.damage), color = { 0.7, 0.4, 0.95 },
                        update = mistUpdate, draw = mistDraw })
                end
                Audio.play("dash", { pitch = 1.6 })
                st.mode, st.cd = "move", params.cooldown or 4
            end
        end
    end,
    draw = function(e)
        local st = e.st
        if st.mode ~= "windup" then return end
        local reach = e.params.reach or 60
        local base = math.atan2(st.dy, st.dx)
        local x, y = Iso.toScreen(e.x, e.y)
        local ax, ay = Iso.toScreen(e.x + math.cos(base - 0.55) * reach, e.y + math.sin(base - 0.55) * reach)
        local bx, by = Iso.toScreen(e.x + math.cos(base + 0.55) * reach, e.y + math.sin(base + 0.55) * reach)
        love.graphics.setColor(0.75, 0.45, 1, math.floor(st.t * 12) % 2 == 0 and 0.7 or 0.3)
        love.graphics.line(ax, ay, x, y, bx, by)
    end,
}
