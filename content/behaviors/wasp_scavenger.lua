-- Yellowjacket: a scavenger. When something dies nearby it drops everything, flies to the body
-- and feeds, and every meal makes it bigger, tougher and harder-biting (up to three). Kill the
-- ants away from them, or kill the yellowjackets before they eat.
-- params: smell (how far it notices a kill, 150), meals (max, 3), eat (seconds, 1.0),
--         grow (size per meal, 0.15), height (7)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

-- particle colours and options, made once (not a new table every frame)
local PFX_1 = { 0.75, 0.6, 0.3 }
local PFX_2 = { grav = 200 }

return {
    name = "Scavenger",
    init = function(e) e.st.mode, e.st.meals, e.st.ph = "hunt", 0, love.math.random() * 6.28 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "hunt" then
            st.ph = st.ph + dt * 5
            local nx, ny = dx / d + math.cos(st.ph) * 0.4, dy / d + math.sin(st.ph) * 0.4
            local l = math.sqrt(nx * nx + ny * ny) + 0.0001
            e.mx, e.my = nx / l * e.speed, ny / l * e.speed
            AI.hover(e, world, dt, d < 22 and 1 or (params.height or 7))
            if st.meals < (params.meals or 3) then
                local deaths, r2 = world.recentDeaths, (params.smell or 150) ^ 2
                for i = 1, deaths.n do
                    local k = deaths[i]
                    if k.id ~= e.def.id and (k.x - e.x) ^ 2 + (k.y - e.y) ^ 2 < r2 then
                        st.mode, st.tx, st.ty, st.t = "fly", k.x, k.y, 2.5
                        break
                    end
                end
            end
        elseif st.mode == "fly" then
            AI.hover(e, world, dt, 5)
            st.t = st.t - dt
            if AI.goTo(e, st.tx, st.ty, e.speed * 1.5) < 4 then st.mode, st.t = "eat", params.eat or 1.0 end
            if st.t <= 0 then st.mode = "hunt" end
        else
            e.mx, e.my = 0, 0
            e.z = math.max(0, e.z - dt * 20)
            st.t = st.t - dt
            if love.math.random() < dt * 10 then
                world.particles:spawn(e.x, e.y, 2, (love.math.random() - 0.5) * 30, (love.math.random() - 0.5) * 30, 20, 0.4, PFX_1, 1, PFX_2)
            end
            if st.t <= 0 then
                st.meals = st.meals + 1
                e.maxHp = math.floor(e.maxHp * 1.5 + 0.5)
                e.hp = e.maxHp
                e.damage = e.damage * 1.2
                e.scale = e.baseScale * (1 + st.meals * (params.grow or 0.15))
                e.radius = e.def.radius * (1 + st.meals * 0.08)
                world:floatText(e.x, e.y, st.meals >= (params.meals or 3) and "GORGED" or "FED", { 1, 0.85, 0.3 }, false)
                Audio.play("pickup", { pitch = 0.6 })
                st.mode = "hunt"
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "eat" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(1, 0.85, 0.3, 0.4)
        love.graphics.ellipse("line", x, y, 6, 3)
    end,
}
