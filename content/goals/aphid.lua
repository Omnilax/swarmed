-- A little aphid has wandered into the fight. Some of the ants go for it: keep it alive until
-- the wave is cleared.
local Goals = require("src.game.goals")

return {
    name = "Guard the Aphid",
    description = "An aphid sits in the arena and some ants go for it. Keep it alive until the wave is cleared.",
    weight = 10, minWave = 3,
    reward = { xp = 30, frenzy = 0.35 },
    params = { hp = 60, lureChance = 0.3, lureRange = 170, bite = 0.6 },
    text = function(goal)
        local a = goal.aphid
        return ("Guard the aphid  %d%%"):format(math.max(0, math.ceil(a.hp / a.max * 100)))
    end,
    start = function(goal, world)
        local p, S = world.player, world.size
        local ang = love.math.random() * math.pi * 2
        local x = math.max(30, math.min(S - 30, p.x + math.cos(ang) * 45))
        local y = math.max(30, math.min(S - 30, p.y + math.sin(ang) * 45))
        local hp = goal.def.params.hp * (1 + (goal.wave - 1) * 0.08)
        goal.aphid = Goals.guarded(world, x, y, hp, goal.def.params)
    end,
    update = function(goal, world, dt)
        if Goals.updateGuarded(world, goal.aphid, dt) then return "failed" end
    end,
    finish = function(goal) return goal.aphid.hp > 0 and "done" or "failed" end,
    drawWorld = function(goal, world) Goals.drawGuarded(world, goal.aphid) end,
}
