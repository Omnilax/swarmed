-- Instant cards: something happens right away and that is all (`apply` runs once when taken).
-- Nectar Sip (heal) lives in stats.lua with the older cards.
local function r(v) return math.floor(v + 0.5) end
local function wave(world) return world.spawner and math.max(1, world.spawner.wave) or 1 end

return {
    { id = "nectar_cache", name = "Nectar Cache", family = "instant", weight = 4,
        text = function(m) return ("Find a hidden stash: +%d nectar per wave so far (spend it at shrines and gambles)"):format(r(6 * m)) end,
        apply = function(p, m, world)
            local n = r(6 * m * wave(world))
            world:addNectar(n, p.x, p.y)
        end },
    { id = "royal_jelly", name = "Royal Jelly", family = "instant", weight = 3, minLevel = 3,
        text = function(m) return ("Gain %d%% of a level's XP right away (it can level you up again)"):format(r(math.min(100, 55 * m))) end,
        apply = function(p, m, world)
            local sk = p.skills
            if not sk then return end
            local need = require("src.game.skills").xpFor(sk.level + 1)
            world:grantXP(math.floor(need * math.min(1, 0.55 * m) + 0.5), p.x, p.y)
        end },
    { id = "deep_breath", name = "Deep Breath", family = "instant", weight = 3,
        text = function(m) return ("Refill your stamina, and +%d%% Speed for the next 20 s"):format(r(20 * m)) end,
        apply = function(p, m)
            local st = require("src.game.stamina").state(p)
            if st and st.max then st.cur = st.max end
            require("src.game.itemfx").buff(p, "lu_deep_breath", "moveSpeed", 0, 0.2 * m, 20)
        end },
}
