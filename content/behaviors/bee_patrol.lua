-- Wool carder bee: the males claim a strip of flowers and patrol it back and forth at full
-- speed, ramming anything in the way (they really do crush other insects). It flies a lane
-- through where you're standing, marked faintly on the ground: get out of the lane.
-- Ants in its way get bowled aside too.
-- params: length (half the lane, 110), passes (before it picks a new lane, 3), dash (patrol
--         speed, 150), knock (240), mult (1.5)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local function newLane(e, world, params)
    local st, p = e.st, world.player
    local a = love.math.random() * math.pi
    local L = params.length or 110
    local cx, cy = p.x + (love.math.random() - 0.5) * 20, p.y + (love.math.random() - 0.5) * 20
    st.ax, st.ay = cx - math.cos(a) * L, cy - math.sin(a) * L
    st.bx, st.by = cx + math.cos(a) * L, cy + math.sin(a) * L
    -- start from whichever end is nearer
    if (st.ax - e.x) ^ 2 + (st.ay - e.y) ^ 2 > (st.bx - e.x) ^ 2 + (st.by - e.y) ^ 2 then
        st.ax, st.ay, st.bx, st.by = st.bx, st.by, st.ax, st.ay
    end
    st.mode, st.passes = "toLane", 0
end

return {
    name = "Lane patrol",
    init = function(e, world, params) e.st.cd = 0 newLane(e, world, params) end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        e.biteCd = 1
        st.cd = st.cd - dt
        AI.hover(e, world, dt, 2)
        if st.mode == "toLane" then
            if AI.goTo(e, st.ax, st.ay, e.speed * 1.5) < 6 then st.mode = "patrol" end
            return
        end
        -- patrol: fly flat out from a to b, then turn round
        local dx, dy = st.bx - e.x, st.by - e.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local s = params.dash or 150
        e.mx, e.my = dx / d * s, dy / d * s
        if d < 6 then
            st.ax, st.ay, st.bx, st.by = st.bx, st.by, st.ax, st.ay
            st.passes = st.passes + 1
            if st.passes >= (params.passes or 3) then newLane(e, world, params) end
        end
        local nx, ny = dx / d, dy / d
        local pdx, pdy = p.x - e.x, p.y - e.y
        if st.cd <= 0 and pdx * pdx + pdy * pdy < (p.radius + e.radius + 3) ^ 2 and not p.dead then
            st.cd = 0.6
            AI.sting(e, world, params.mult or 1.5)
            local side = (pdx * -ny + pdy * nx) >= 0 and 1 or -1
            p:knock(-ny * side + nx * 0.5, nx * side + ny * 0.5, params.knock or 240)
            world.camera:shake(0.2)
            Audio.play("hit", { pitch = 0.7 })
        end
        -- ants in the lane are shoved aside
        local list, n = world:queryEnemies(e.x, e.y, e.radius + 6)
        for i = 1, n do
            local o = list[i]
            if o ~= e and not o.dead and not o.def.boss and o.def.family ~= "bee" then
                local side = ((o.x - e.x) * -ny + (o.y - e.y) * nx) >= 0 and 1 or -1
                o.kvx, o.kvy = -ny * side * 140 / o.mass, nx * side * 140 / o.mass
            end
        end
    end,
    -- the lane, faintly marked on the ground
    drawUnder = function(e)
        local st = e.st
        if st.mode ~= "patrol" then return end
        local x1, y1 = Iso.toScreen(st.ax, st.ay)
        local x2, y2 = Iso.toScreen(st.bx, st.by)
        love.graphics.setColor(1, 0.9, 0.6, 0.12)
        love.graphics.setLineWidth(3)
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.setLineWidth(1)
    end,
}
