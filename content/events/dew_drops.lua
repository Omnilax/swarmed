-- Morning dew: big drops of water roll down the blades of grass and across the arena in
-- straight lines. Each one bowls through the ants in its way; you get knocked if it hits you.
local Env = require("src.game.envfx")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local WARN, R, SPEED = 1.1, 11, 125

local function newDrop(world)
    local p = world.player
    local tx, ty = Env.pointNear(world, p.x, p.y, 140)
    local x1, y1, x2, y2 = Env.crossing(world, tx, ty, 0)
    local dx, dy = x2 - x1, y2 - y1
    local l = math.sqrt(dx * dx + dy * dy) + 0.0001
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2, x = x1, y = y1, dx = dx / l, dy = dy / l, len = l, t = 0, hit = {}, hitPlayer = false }
end

return {
    name = "Dew Drops",
    description = "Water drops roll through. Stand clear and let them bowl the ants over.",
    color = { 0.6, 0.85, 1 },
    kind = "hazard",
    weight = 9, minWave = 2,
    start = function(world, ev)
        ev.st.drops, ev.st.left, ev.st.cd = {}, ev.opts.count or (4 + math.min(4, math.floor(world.spawner.wave / 3))), 0
    end,
    update = function(world, ev, dt)
        local st = ev.st
        st.cd = st.cd - dt
        if st.cd <= 0 and st.left > 0 then
            st.left, st.cd = st.left - 1, 0.9 + love.math.random() * 0.8
            st.drops[#st.drops + 1] = newDrop(world)
        end
        for i = #st.drops, 1, -1 do
            local d = st.drops[i]
            d.t = d.t + dt
            if d.t >= WARN then
                local run = (d.t - WARN) * SPEED
                if d.t - dt < WARN then Audio.play("dash", { pitch = 0.6 }) end
                d.x, d.y = d.x1 + d.dx * run, d.y1 + d.dy * run
                for _, e in ipairs(require("src.game.combat").collect(world, d.x, d.y, R)) do
                    if not d.hit[e.uid] then
                        d.hit[e.uid] = true
                        Env.hurtAnt(world, e, 18 + world.spawner.wave * 1.5, { force = 220, kx = d.dx + (e.x - d.x) * 0.05, ky = d.dy + (e.y - d.y) * 0.05 })
                    end
                end
                if not d.hitPlayer and Env.playerIn(world, d.x, d.y, R) then
                    d.hitPlayer = true
                    Env.hurtPlayer(world, 9, d.x - d.dx * 10, d.y - d.dy * 10, { force = 200 })
                end
                if run >= d.len then
                    table.remove(st.drops, i)
                    world.particles:burst(d.x, d.y, 12, { { 0.7, 0.85, 1 }, { 1, 1, 1 } }, 90, 70, { grav = 300 })
                end
            end
        end
        if st.left <= 0 and #st.drops == 0 then ev.done = true end
    end,
    drawGround = function(world, ev)
        for _, d in ipairs(ev.st.drops) do
            if d.t < WARN then
                Env.warnLane(d.x1, d.y1, d.x2, d.y2, R * 0.8, d.t / WARN, world.time, { 0.5, 0.8, 1 })
            else
                Env.shadow(d.x, d.y, R, 0.6)
            end
        end
    end,
    drawAir = function(world, ev)
        local lg = love.graphics
        for _, d in ipairs(ev.st.drops) do
            if d.t >= WARN then
                local sx, sy = Iso.toScreen(d.x, d.y, R)
                lg.setColor(0.55, 0.75, 0.95, 0.55)
                lg.circle("fill", sx, sy, R * 1.15)
                lg.setColor(0.8, 0.92, 1, 0.65)
                lg.circle("line", sx, sy, R * 1.15)
                lg.setColor(1, 1, 1, 0.9)
                lg.circle("fill", sx - R * 0.4, sy - R * 0.45, 2)
            end
        end
    end,
}
