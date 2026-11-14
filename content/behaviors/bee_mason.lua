-- Mason bee: builds its nest walls out of mud. Flies ahead of you and plasters wet mud where
-- you're about to walk. Mud slows you down, and stand in it too long and it sets: you're stuck
-- fast for a moment. Older patches are drier and set faster.
-- params: lead (how far ahead it aims, seconds of your movement, 0.7), radius (patch, 16),
--         life (8), slow (0.55), set (seconds in the mud before it grips, 0.9), stuck (0.7),
--         cooldown (3.5), keep (90)
local AI = require("src.game.ai")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local MUD = { 0.42, 0.3, 0.19 }

local function patchUpdate(world, z, dt, inside)
    local p = world.player
    if inside then
        -- drier mud (older patch) grips sooner
        z.grip = (z.grip or 0) + dt * (1 + z.t / z.maxLife)
        if z.grip >= z.set then
            z.grip = -0.8
            p:slow(0.06, z.stuck)
            world:floatText(p.x, p.y, "STUCK IN MUD", { 0.85, 0.65, 0.4 }, false)
            world.particles:burst(p.x, p.y, 6, { MUD }, 40, 30, { grav = 200 })
        end
    else
        z.grip = math.max(0, (z.grip or 0) - dt * 2)
    end
    -- the patch dries out: paler as it ages
    local k = math.min(1, z.t / z.maxLife)
    z.color[1], z.color[2], z.color[3] = MUD[1] + k * 0.18, MUD[2] + k * 0.15, MUD[3] + k * 0.1
end

return {
    name = "Mud plasterer",
    init = function(e) e.st.mode, e.st.cd = "away", 1 + love.math.random() * 2 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "away" then
            AI.hover(e, world, dt, 10)
            local keep = params.keep or 90
            local want = util.clamp((d - keep) / 25, -1, 1)
            e.mx, e.my = (dx / d * want - dy / d * 0.5) * e.speed, (dy / d * want + dx / d * 0.5) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 then
                local lead = params.lead or 0.7
                st.tx, st.ty = p.x + (p.vx or 0) * lead, p.y + (p.vy or 0) * lead
                st.mode, st.t = "fly", 3
            end
        elseif st.mode == "fly" then
            AI.hover(e, world, dt, 6)
            st.t = st.t - dt
            if AI.goTo(e, st.tx, st.ty, e.speed * 1.6) < 6 or st.t <= 0 then st.mode, st.t = "plaster", 0.5 end
        else
            e.mx, e.my = 0, 0
            AI.hover(e, world, dt, 1)
            st.t = st.t - dt
            if love.math.random() < dt * 20 then world.particles:spawn(e.x, e.y, 2, 0, 0, 20, 0.4, MUD, 1, { grav = 200 }) end
            if st.t <= 0 then
                world.hazards:addZone({ kind = "mud", x = e.x, y = e.y, r = params.radius or 16, life = params.life or 8,
                    slow = params.slow or 0.55, set = params.set or 0.9, stuck = params.stuck or 0.7,
                    color = { MUD[1], MUD[2], MUD[3] }, update = patchUpdate })
                Audio.play("hit", { pitch = 0.45 })
                st.mode, st.cd = "away", params.cooldown or 3.5
            end
        end
    end,
}
