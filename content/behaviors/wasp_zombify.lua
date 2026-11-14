-- Emerald cockroach wasp (jewel wasp): stings a cockroach in the brain and walks it home by
-- the antenna like a zombie. This one keeps away from you and stings ants instead: each one it
-- gets becomes a Zombified brute (the "zombified" elite: much tougher, bigger, slower, green).
-- Once it has made its zombies it comes for you. Kill the wasp before it builds a horde.
-- params: keep (distance from you, 130), cooldown (3.5), max (zombies per wasp, 4),
--         search (radius, 150), elite ("zombified")
local AI = require("src.game.ai")
local Content = require("src.content")
local Elites = require("src.game.elites")
local util = require("src.core.util")
local Audio = require("src.core.audio")

local function zombify(world, o, elite)
    o.elite = elite
    o.maxHp = math.max(1, math.floor(o.maxHp * elite.hp + 0.5))
    o.hp = o.maxHp
    o.damage = o.damage * elite.damage
    o.speed = o.speed * elite.speed
    o.mass = o.mass * elite.mass
    o.radius = o.radius * elite.scale ^ 0.5
    o.scale = o.scale * elite.scale
    o.baseScale = o.scale
    o.params = Elites.params(o.def, elite)
    o.flash = 0.2
    world:floatText(o.x, o.y, "ZOMBIFIED", { 0.5, 1, 0.45 }, false)
    world.particles:burst(o.x, o.y, 8, { { 0.45, 1, 0.4 } }, 50, 40, { glow = true, grav = 40 })
end

return {
    name = "Zombifier",
    init = function(e) e.st.mode, e.st.cd, e.st.made = "keep", 1.5, 0 end,
    update = function(e, world, dt, params)
        local st, p = e.st, world.player
        local dx, dy, d = AI.toPlayer(e, world)
        local done = st.made >= (params.max or 4)
        if st.mode == "keep" then
            if done then
                -- out of zombies to make: fight
                AI.hover(e, world, dt, d < 22 and 1 or 7)
                e.mx, e.my = dx / d * e.speed * 1.2, dy / d * e.speed * 1.2
                return
            end
            e.biteCd = 1
            AI.hover(e, world, dt, 9)
            local keep = params.keep or 130
            local want = util.clamp((d - keep) / 25, -1, 1)
            e.mx, e.my = (dx / d * want - dy / d * 0.5) * e.speed, (dy / d * want + dx / d * 0.5) * e.speed
            st.cd = st.cd - dt
            if st.cd <= 0 then
                local o = AI.nearestOther(world, e, e.x, e.y, params.search or 150, function(o)
                    return o.def.family == "ant" and not o.elite and o.z < 2
                end)
                if o then st.mode, st.prey, st.preyUid, st.t = "go", o, o.uid, 3 else st.cd = 1 end
            end
        else -- fly to the ant and sting it
            e.biteCd = 1
            local o = st.prey
            st.t = st.t - dt
            if o.dead or o.uid ~= st.preyUid or o.elite or st.t <= 0 then
                st.mode, st.cd = "keep", 0.5
                return
            end
            AI.hover(e, world, dt, 2)
            if AI.goTo(e, o.x, o.y, e.speed * 1.5) < e.radius + o.radius + 1.5 then
                local z = Content.elites:get(params.elite or "zombified")
                if z then zombify(world, o, z) end
                world:addFx({ kind = "bolt", x = e.x, y = e.y, x2 = o.x, y2 = o.y, life = 0.15, color = { 0.4, 1, 0.5 } })
                Audio.play("zap", { pitch = 0.7 })
                st.made = st.made + 1
                st.mode, st.cd = "keep", params.cooldown or 3.5
            end
        end
    end,
}
