-- Green ant: keeps its distance, rears up (glows) and sprays a fan of acid at the player.
-- params: keep (preferred distance, 130), cooldown (2.4), windup (0.5), shots (5), spread (0.6),
--         shotSpeed (150), shotDamage (4), shotLife (1.4, how far it flies), shotColor ("#8cff4c")
local AI = require("src.game.ai")
local Iso = require("src.core.iso")
local util = require("src.core.util")
local Audio = require("src.core.audio")

return {
    name = "Acid sprayer",
    init = function(e) e.st.cd, e.st.mode = 1 + love.math.random() * 1.5, "move" end,
    update = function(e, world, dt, params)
        local st = e.st
        local dx, dy, d = AI.toPlayer(e, world)
        if st.mode == "move" then
            local keep = params.keep or 130
            local want = util.clamp((d - keep) / 25, -1, 1)
            local side = math.sin(world.time + e.uid) * 0.5
            e.mx = (dx / d * want - dy / d * side) * e.speed
            e.my = (dy / d * want + dx / d * side) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 and d < keep * 1.6 then st.mode, st.t = "windup", params.windup or 0.5 end
        else
            e.mx, e.my = dx / d * 1.2, dy / d * 1.2   -- barely moving, but turned to face the target
            st.t = st.t - dt
            if st.t <= 0 then
                local n, spread = params.shots or 5, params.spread or 0.6
                local base = math.atan2(dy, dx)
                local sp = params.shotSpeed or 150
                params._c = params._c or util.hex(params.shotColor or "#8cff4c")
                for i = 1, n do
                    local a = base + (n > 1 and ((i - 1) / (n - 1) - 0.5) * spread or 0)
                    world.hazards:shoot({ x = e.x, y = e.y, vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                        r = 3, damage = (params.shotDamage or 4) * (e.damage / math.max(0.1, e.def.damage)),
                        life = params.shotLife or 1.4, color = params._c, splat = true, venom = e.elite and e.elite.venom })
                end
                Audio.play("dash", { pitch = 1.8 })
                st.mode, st.cd = "move", params.cooldown or 2.4
            end
        end
    end,
    draw = function(e)
        if e.st.mode ~= "windup" then return end
        local x, y = Iso.toScreen(e.x, e.y)
        love.graphics.setColor(0.6, 1, 0.3, 0.35 + 0.3 * math.sin(e.st.t * 40))
        love.graphics.circle("fill", x, y - 2, 4)
    end,
}
