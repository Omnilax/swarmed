-- Colony war (content/events/colony_war.lua): an ant fighting for its colony. e.rival is its
-- side ("red" for the invaders, "home" for colony ants drawn into the fight). It goes for the
-- nearest ant of the other side and the two bite each other; with no foe in reach it falls back
-- on its own behaviour (e.rivalBase), which for the invaders means coming for the player too.
local Env = require("src.game.envfx")

local function isFoe(e, o)
    if o == e or o.dead or o.hidden or o.dropH or (o.z or 0) > 4 or o.def.encounter then return false end
    if e.rival == "red" then return o.rival ~= "red" end
    return o.rival == "red"
end

return {
    name = "Colony war",
    update = function(e, world, dt, params)
        local st = e.st
        st.warT = (st.warT or 0) - dt
        st.warCd = math.max(0, (st.warCd or 0) - dt)
        local foe = st.foe
        if foe and (foe.uid ~= st.foeUid or not isFoe(e, foe)) then foe, st.foe = nil, nil end
        if st.warT <= 0 then
            st.warT = 0.35 + love.math.random() * 0.2
            local list, n = world:queryEnemies(e.x, e.y, 110)
            local best, bd = nil, math.huge
            for i = 1, n do
                local o = list[i]
                if isFoe(e, o) then
                    local d = (o.x - e.x) ^ 2 + (o.y - e.y) ^ 2
                    if d < bd then best, bd = o, d end
                end
            end
            if best then st.foe, st.foeUid, foe = best, best.uid, best end
        end
        if not foe then
            local base = e.rivalBase
            if base and base.update then base.update(e, world, dt, params) else e.mx, e.my = 0, 0 end
            return
        end
        local dx, dy = foe.x - e.x, foe.y - e.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local reach = e.radius + foe.radius + 2
        if d > reach then
            e.mx, e.my = dx / d * e.speed * 1.1, dy / d * e.speed * 1.1
        else
            e.mx, e.my = dx / d * 4, dy / d * 4
            if st.warCd <= 0 then
                st.warCd = 0.6 + love.math.random() * 0.3
                e.squash = 0.1
                local mine = math.max(1, e.damage) * 1.4
                local theirs = math.max(1, foe.damage) * 1.2
                Env.hurtAnt(world, foe, mine, { force = 30, kx = dx, ky = dy })
                if not e.dead then Env.hurtAnt(world, e, theirs, { force = 30, kx = -dx, ky = -dy }) end
                if love.math.random() < 0.5 then
                    world.particles:sparks((e.x + foe.x) / 2, (e.y + foe.y) / 2, 2, { 1, 0.6, 0.4 }, dx, dy, 2, 80)
                end
            end
        end
    end,
}
