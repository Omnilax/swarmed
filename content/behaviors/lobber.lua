-- Pebble ant: picks up a pebble and lobs it at where you're going to be. A ring on the ground
-- marks where it will land; get caught and you're hurt and dazed (slowed). Real Dorymyrmex ants
-- drop pebbles down rival honeypot ants' nests to keep them underground.
-- Like acid, a pebble can be swatted back with an attack.
-- params: keep (150), cooldown (2.6), windup (0.55), flight (0.9), blast (14), shotDamage (5),
--         slow (0.5), slowTime (0.9)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local GRAV = 300

return {
    name = "Pebble lob",
    init = function(e) e.st.mode, e.st.cd = "move", 1 + love.math.random() * 1.5 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "move" then
            local keep = params.keep or 150
            local want = util.clamp((d - keep) / 25, -1, 1)
            -- spread out into a firing line: each ant keeps to its own side
            local side = ((e.uid % 3) - 1) * 0.6
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.7 then st.mode, st.t = "windup", params.windup or 0.55 end
        else
            e.mx, e.my = dx / d * 1, dy / d * 1
            st.t = st.t - dt
            if st.t <= 0 then
                local T = params.flight or 0.9
                -- lead the target: aim where the player will be
                local tx = p.x + (p.vx or 0) * T * 0.8 + (love.math.random() - 0.5) * 10
                local ty = p.y + (p.vy or 0) * T * 0.8 + (love.math.random() - 0.5) * 10
                local z0 = 6
                world.hazards:shoot({ x = e.x, y = e.y, z = z0, vx = (tx - e.x) / T, vy = (ty - e.y) / T,
                    vz = (1 - z0 + GRAV * T * T / 2) / T, grav = GRAV, r = 3,
                    damage = (params.shotDamage or 5) * (e.damage / math.max(0.1, e.def.damage)),
                    life = T + 0.3, color = { 0.66, 0.6, 0.52 }, pebble = true,
                    lob = { x = tx, y = ty, r = params.blast or 14, slow = params.slow or 0.5, slowTime = params.slowTime or 0.9, flight = T } })
                Audio.play("dash", { pitch = 1.3 })
                st.mode, st.cd = "move", params.cooldown or 2.6
            end
        end
    end,
    -- the pebble held up in its jaws
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y, 6)
        love.graphics.setColor(0.66, 0.6, 0.52, 1)
        love.graphics.rectangle("fill", math.floor(x) - 1, math.floor(y) - 1, 2, 2)
    end,
}
