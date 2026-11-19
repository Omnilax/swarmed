-- Web cocoons: a spider's larder. One or two bugs lie wrapped up somewhere in the arena; hit a
-- cocoon three times (or dash through it) and the bug inside fights beside you for 20 s.
local Env = require("src.game.envfx")

return {
    name = "Web Cocoons",
    description = "Bugs wrapped in silk! Break a cocoon to free an ally.",
    color = { 0.7, 1, 0.7 },
    kind = "event",
    weight = 8, minWave = 3,
    start = function(world, ev)
        ev.st.cocoons = {}
        local n = ev.opts.count or (world.spawner.wave >= 7 and 2 or 1)
        for _ = 1, n do
            local x, y = Env.pointAway(world, 110, 60)
            -- not too far off either
            local p = world.player
            local dx, dy = x - p.x, y - p.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.0001
            if d > 220 then x, y = p.x + dx / d * 200, p.y + dy / d * 200 end
            ev.st.cocoons[#ev.st.cocoons + 1] = world.props:spawn("cocoon", x, y, { allyLife = ev.opts.allyLife })
        end
    end,
    update = function(world, ev)
        for _, c in ipairs(ev.st.cocoons) do if not c.dead then return end end
        ev.done = true      -- all broken open (the allies live on by themselves)
    end,
    finish = function(world, ev)
        for _, c in ipairs(ev.st.cocoons) do c.dead = true end
    end,
}
