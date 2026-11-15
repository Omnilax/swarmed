-- Giant anteater (boss encounter): ambles about keeping `keep` from the player, and every
-- `every` s plants itself and aims its tongue down a lane toward the player (a red warning
-- for `warn` s), then flicks it: every ant in the lane is eaten, the player takes `damage`
-- and is dragged toward the snout.
-- params: every (3.2), warn (1.1), reach (175), width (9), damage (14), keep (100)
local AI = require("src.game.ai")
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

local function snout(e)
    local a = e.st.face
    return e.x + math.cos(a) * (e.radius + 14), e.y + math.sin(a) * (e.radius + 14)
end

return {
    name = "Anteater",
    init = function(e) e.st.mode, e.st.cd, e.st.face, e.st.t = "walk", 2.5, 0, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        st.t = st.t + dt
        if st.mode == "walk" then
            local keep = params.keep or 100
            local want = math.max(-1, math.min(1, (d - keep) / 40))
            -- circle a little as it closes in
            e.mx = (dx / d * want - dy / d * 0.4) * e.speed
            e.my = (dy / d * want + dx / d * 0.4) * e.speed
            if e.mx * e.mx + e.my * e.my > 1 then st.face = math.atan2(e.my, e.mx) end
            st.cd = st.cd - dt
            if st.cd <= 0 and d < (params.reach or 175) + 40 then
                st.mode, st.t = "aim", 0
                st.face = math.atan2(dy, dx)
                local x1, y1 = snout(e)
                local reach = params.reach or 175
                st.mx0, st.my0 = x1, y1
                st.tx, st.ty = x1 + math.cos(st.face) * reach, y1 + math.sin(st.face) * reach
                Audio.play("rumble", { pitch = 1.8, volume = 0.5 })
            end
        elseif st.mode == "aim" then
            e.mx, e.my = 0, 0
            if st.t >= (params.warn or 1.1) then
                st.mode, st.t = "lick", 0
                Audio.play("dash", { pitch = 0.5 })
            end
        elseif st.mode == "lick" then
            e.mx, e.my = 0, 0
            if not st.struck and st.t >= 0.2 then
                st.struck = true
                local w = params.width or 9
                local n = Env.strikeLane(world, st.mx0, st.my0, st.tx, st.ty, w, 999, { bossMul = 0.15 })
                if n >= 5 then world:floatText(st.tx, st.ty, n .. " LICKED UP", { 1, 0.6, 0.6 }, true) end
                if Env.playerInLane(world, st.mx0, st.my0, st.tx, st.ty, w) then
                    if Env.hurtPlayer(world, (params.damage or 14) * e.damage / math.max(0.1, e.def.damage), p.x, p.y, { name = "anteater" }) then
                        p:knock(st.mx0 - p.x, st.my0 - p.y, 170)
                    end
                end
            end
            if st.t >= 0.75 then
                st.mode, st.struck, st.cd = "walk", false, (params.every or 3.2) * (0.8 + love.math.random() * 0.4)
            end
        end
    end,
    -- the warning lane is always shown (it is the whole fight)
    drawUnder = function(e, world)
        local st = e.st
        if st.mode == "aim" then
            Env.warnLane(st.mx0, st.my0, st.tx, st.ty, 9, st.t / 1.1, world.time)
        end
    end,
}
