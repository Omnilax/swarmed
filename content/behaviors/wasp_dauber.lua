-- Mud dauber: builds rows of mud tubes ("organ pipes") to raise its young in. This one builds
-- them round you: it zips from spot to spot on a ring around where you stand, slapping down a
-- solid mud pipe at each one, caging you in. Then it stings over the wall. Get out before the
-- ring closes, smash a pipe, or dash through the gap. The pipes crumble after a while.
-- params: ring (cage radius, 30), pipes (per cage, 7), place (seconds per pipe, 0.45),
--         pipe (enemy id, "mud_pipe"), attack (seconds stinging before building again, 4)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local MUD = { 0.45, 0.33, 0.22 }

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { grav = 250 }

return {
    name = "Pipe cage",
    init = function(e) e.st.mode, e.st.t = "attack", 1.5 + love.math.random() end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.t = st.t - dt
        if st.mode == "attack" then
            AI.hover(e, world, dt, d < 24 and 1 or 7)
            e.mx, e.my = dx / d * e.speed, dy / d * e.speed
            if st.t <= 0 and d < 90 then
                st.mode, st.cx, st.cy, st.k, st.t = "build", p.x, p.y, 0, 0
                st.a0 = love.math.random() * math.pi * 2
            end
        else
            e.biteCd = 1
            AI.hover(e, world, dt, 3)
            local n = params.pipes or 7
            local r = params.ring or 30
            local a = st.a0 + st.k / n * math.pi * 2
            local tx, ty = st.cx + math.cos(a) * r, st.cy + math.sin(a) * r
            local arrived = AI.goTo(e, tx, ty, e.speed * 2.5) < 4
            if arrived and st.t <= 0 then
                st.t = params.place or 0.45
                if (p.x - tx) ^ 2 + (p.y - ty) ^ 2 > (p.radius + 6) ^ 2 then
                    world:spawnEnemy(params.pipe or "mud_pipe", tx, ty)
                    world.particles:burst(tx, ty, 5, { MUD }, 40, 30, PFX_1)
                    Audio.play("hit", { pitch = 0.5 })
                end
                st.k = st.k + 1
                if st.k >= n then st.mode, st.t = "attack", params.attack or 4 end
            end
            -- you walked off before it finished: start a new cage
            if (p.x - st.cx) ^ 2 + (p.y - st.cy) ^ 2 > (r * 1.6) ^ 2 then st.mode, st.t = "attack", 1.5 end
        end
    end,
    -- where the cage is going up
    drawUnder = function(e)
        local st = e.st
        if st.mode ~= "build" then return end
        local x, y = Iso.toScreen(st.cx, st.cy)
        local r = e.params.ring or 30
        love.graphics.setColor(MUD[1] + 0.3, MUD[2] + 0.25, MUD[3] + 0.2, 0.25)
        love.graphics.ellipse("line", x, y, r * 1.414, r * 0.707)
    end,
}
