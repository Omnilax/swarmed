-- Nasute termite soldier: no jaws, just a nozzle on its head. Keeps its distance and squirts
-- quick bursts of sticky glue (real nasutes gum up ants with terpene glue). A hit gums you up
-- (slows you), and every glob leaves a sticky patch on the floor that slows you while you're in it.
-- params: keep (preferred distance, 105), cooldown (2.6), windup (0.45), burst (globs, 3),
--         gap (seconds between globs, 0.12), shotSpeed (165), shotDamage (2), gum (player speed x
--         on a hit, 0.5), gumTime (1.4), patch (sticky floor radius, 12), patchLife (4.5),
--         patchSlow (0.6)
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local GLUE = { 0.86, 0.84, 0.58 }

local function patch(world, s)
    local P = s.patch
    world.hazards:addZone({ kind = "glue", x = s.x, y = s.y, r = P.r, life = P.life, slow = P.slow, color = GLUE })
    if s.hitPlayer then world.player:slow(P.gum, P.gumTime) end
end

return {
    name = "Glue squirter",
    init = function(e) e.st.cd, e.st.mode, e.st.side = 0.8 + love.math.random() * 1.5, "move", love.math.random() < 0.5 and -1 or 1 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "move" then
            local keep = params.keep or 105
            local want = util.clamp((d - keep) / 25, -1, 1)
            local side = st.side * 0.55
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.7 then st.mode, st.t = "windup", params.windup or 0.45 end
        elseif st.mode == "windup" then
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2
            st.t = st.t - dt
            if st.t <= 0 then st.mode, st.left, st.t = "squirt", params.burst or 3, 0 end
        else
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2
            st.t = st.t - dt
            if st.t <= 0 then
                st.t, st.left = params.gap or 0.12, st.left - 1
                -- lead the target a little, with some wobble so a burst sprays a short line
                local lead = math.min(0.35, d / (params.shotSpeed or 165))
                local tx, ty = p.x + (p.vx or 0) * lead, p.y + (p.vy or 0) * lead
                local a = math.atan2(ty - e.y, tx - e.x) + (love.math.random() - 0.5) * 0.18
                local sp = params.shotSpeed or 165
                local shot = world.hazards:shoot({ x = e.x + math.cos(a) * 5, y = e.y + math.sin(a) * 5,
                    vx = math.cos(a) * sp, vy = math.sin(a) * sp, r = 2.5, z = 4, vz = 25,
                    damage = (params.shotDamage or 2) * (e.damage / math.max(0.1, e.def.damage)),
                    life = 1.3, color = GLUE, venom = e.elite and e.elite.venom,
                    patch = { r = params.patch or 12, life = params.patchLife or 4.5, slow = params.patchSlow or 0.6,
                        gum = params.gum or 0.5, gumTime = params.gumTime or 1.4 } })
                shot.onEnd = function(w, s)
                    local px, py = w.player.x - s.x, w.player.y - s.y
                    s.hitPlayer = px * px + py * py < (w.player.radius + s.r + 1) ^ 2
                    patch(w, s)
                end
                e.squash = 0.08
                Audio.play("dash", { pitch = 2.1 })
                if st.left <= 0 then
                    st.mode, st.cd = "move", params.cooldown or 2.6
                    st.side = -st.side
                end
            end
        end
    end,
    -- the nozzle swells with a bead of glue before it fires
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        local a = e.angle
        love.graphics.setColor(1, 0.97, 0.6, 0.5 + 0.4 * math.sin(e.st.t * 40))
        love.graphics.circle("fill", x + math.cos(a) * 5, y + math.sin(a) * 5 - 2, 1.5)
    end,
}
