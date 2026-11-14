-- Bald-faced hornet (really a big yellowjacket): defends its nest by squirting venom at the
-- eyes of whatever is attacking it. Keeps its distance, flashes white for a moment, then fires
-- a jet; if it hits, you're blinded: the light shrinks to just around you for a few seconds.
-- A swing can bat the jet back.
-- params: keep (75), cooldown (3.2), windup (0.5), speed (230), blind (seconds, 2.6),
--         shotDamage (3)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local VENOM = { 0.92, 0.95, 1 }

local function blindHit(world, s, p)
    p:blind(s.blind)
    world:floatText(p.x, p.y, "BLINDED", { 0.9, 0.95, 1 }, false)
end

return {
    name = "Eye squirter",
    init = function(e) e.st.mode, e.st.cd = "move", 1.5 + love.math.random() end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "move" then
            AI.hover(e, world, dt, 8)
            local keep = params.keep or 75
            local want = util.clamp((d - keep) / 25, -1, 1)
            local side = math.sin(world.time * 0.8 + e.uid) * 0.6
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.7 then st.mode, st.t = "windup", params.windup or 0.5 end
        else
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2
            st.t = st.t - dt
            if st.t <= 0 then
                -- lead the shot a little
                local sp = params.speed or 230
                local tt = d / sp
                local tx, ty = p.x + (p.vx or 0) * tt * 0.6, p.y + (p.vy or 0) * tt * 0.6
                local ax, ay = util.normalize(tx - e.x, ty - e.y)
                world.hazards:shoot({ x = e.x, y = e.y, z = e.z, vz = 0, grav = 0, vx = ax * sp, vy = ay * sp, r = 2.5,
                    damage = (params.shotDamage or 3) * e.damage / math.max(0.1, e.def.damage), life = 0.9,
                    color = VENOM, blind = params.blind or 2.6, onHitPlayer = blindHit })
                Audio.play("dash", { pitch = 2.4 })
                st.mode, st.cd = "move", params.cooldown or 3.2
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y, e.z)
        love.graphics.setColor(1, 1, 1, 0.5 + 0.5 * math.sin(e.st.t * 45))
        love.graphics.circle("fill", x, y, 3)
    end,
}
