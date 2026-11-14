-- Paper wasp: chews wood into paper and builds a nest. It flies off to a spot at the edge of the
-- fight, builds a nest there (a few seconds), and the nest keeps releasing more wasps until you
-- break it. After building, it guards: stays by the nest and attacks if you come near.
-- params: site (how far from you it builds, 120), build (2.2), nest (enemy id, "paper_nest"),
--         guard (radius it defends, 110)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local PAPER = { 0.72, 0.68, 0.6 }

return {
    name = "Nest builder",
    init = function(e) e.st.mode, e.st.ph = "seek", love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.ph = st.ph + dt * 4
        if st.built and st.mode ~= "guard" then st.mode = "guard" end
        if st.mode == "seek" then
            if not st.tx then
                local a = math.atan2(e.y - p.y, e.x - p.x) + (love.math.random() - 0.5)
                local r = params.site or 120
                st.tx = math.max(20, math.min(world.size - 20, p.x + math.cos(a) * r))
                st.ty = math.max(20, math.min(world.size - 20, p.y + math.sin(a) * r))
            end
            AI.hover(e, world, dt, 8)
            if AI.goTo(e, st.tx, st.ty, e.speed * 1.3) < 5 then st.mode, st.t = "build", params.build or 2.2 end
        elseif st.mode == "build" then
            e.mx, e.my = math.cos(st.ph * 3) * 8, math.sin(st.ph * 3) * 8
            AI.hover(e, world, dt, 3)
            st.t = st.t - dt
            if love.math.random() < dt * 12 then
                world.particles:spawn(st.tx, st.ty, 3, (love.math.random() - 0.5) * 20, (love.math.random() - 0.5) * 20, 20, 0.5, PAPER, 1, { grav = 150 })
            end
            if st.t <= 0 then
                local nest = world:spawnEnemy(params.nest or "paper_nest", st.tx, st.ty)
                if nest then st.nest, st.nestUid = nest, nest.uid end
                st.built = true
                Audio.play("hit", { pitch = 0.5 })
            end
        else -- guard the nest; with no nest left, just attack
            local nest = st.nest
            if nest and (nest.dead or nest.uid ~= st.nestUid) then nest, st.nest = nil, nil end
            local defend = not nest or (p.x - nest.x) ^ 2 + (p.y - nest.y) ^ 2 < (params.guard or 110) ^ 2
            if defend then
                AI.hover(e, world, dt, d < 22 and 1 or 6)
                local nx, ny = dx / d + math.cos(st.ph) * 0.3, dy / d + math.sin(st.ph) * 0.3
                local l = math.sqrt(nx * nx + ny * ny) + 0.0001
                e.mx, e.my = nx / l * e.speed * 1.2, ny / l * e.speed * 1.2
            else
                AI.hover(e, world, dt, 7)
                AI.goTo(e, nest.x + math.cos(st.ph * 0.5) * 18, nest.y + math.sin(st.ph * 0.5) * 18, e.speed)
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "build" then return end
        local x, y = Iso.toScreen(e.st.tx, e.st.ty)
        love.graphics.setColor(PAPER[1], PAPER[2], PAPER[3], 0.5)
        love.graphics.ellipse("line", x, y, 7, 3.5)
    end,
}
