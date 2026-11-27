-- What is open from the start and what in-run goals open the rest (src/game/unlocks.lua).
--
-- starters: the bugs everyone has from the first run. Every other bug is locked until its goal
-- is met. Items listed under `items` stay out of the item choice (and the starting items
-- screen) until theirs is met. Each goal becomes an achievement in the "Unlocks" category
-- (content/achievements/unlocks.lua), so the Records screen shows progress and an unlock card
-- pops up mid-run when it happens.
--
-- A goal: { text = "One line.", goal = number, value = function(profile, run) -> number }.
-- `run` is the run going on (nil between runs); see content/achievements/_template.lua for the
-- fields of both. Helpers below build the common ones. A bug already played before unlocks
-- existed counts as unlocked. Settings > Developer > "Unlock Everything" opens it all.
local U = {}

U.starters = { "rhino_beetle", "stag_beetle", "wolf_spider", "scorpion", "mantis", "tiger_beetle",
    "bombardier_beetle", "orb_weaver" }

local function name(id)
    local def = require("src.content").characters:get(id)
    return def and def.name or id
end

-- in one run: run[field] >= goal (optionally as a given bug)
local function inRun(field, goal, text, as)
    return { text = text, goal = goal, value = function(_, run)
        if not run or (as and run.character ~= as) then return 0 end
        return run[field] or 0
    end }
end

-- all time: profile[field] >= goal
local function total(field, goal, text)
    return { text = text, goal = goal, value = function(p) return p[field] or 0 end }
end

-- clear wave n (in one run), optionally as a given bug
local function clearWave(n, as)
    local text = as and ("Clear wave %d as the %s."):format(n, name(as)) or ("Clear wave %d."):format(n)
    return inRun("wavesCleared", n, text, as)
end

-- win a run, optionally as a given bug
local function win(as)
    return { text = as and ("Win a run as the " .. name(as) .. ".") or "Win a run.", goal = 1, value = function(p)
        if as then return p.characters[as] and p.characters[as].wins or 0 end
        return p.wins
    end }
end

U.bugs = {
    crab = clearWave(5, "rhino_beetle"),
    hermit_crab = clearWave(8, "crab"),
    lobster = inRun("blocked", 300, "Block 300 damage in one run (the Hermit Crab's shell blocks)."),
    tarantula = clearWave(10, "wolf_spider"),
    jumping_spider = inRun("dashKills", 25, "Kill 25 ants mid-dash in one run."),
    camel_spider = { text = "Reach a 150 combo.", goal = 150, value = function(p, run)
        return math.max(p.bestCombo or 0, run and run.world and run.world.bestCombo or 0)
    end },
    assassin_bug = total("elites", 40, "Kill 40 elite ants."),
    stink_bug = inRun("queens", 3, "Kill 3 queens in one run."),
    hissing_roach = inRun("itemsEaten", 8, "Eat 8 items in one run."),
    dung_beetle = total("kills", 5000, "Kill 5,000 ants."),
    millipede = inRun("flawlessWaves", 3, "Clear 3 waves without a scratch in one run."),
    centipede = inRun("kills", 400, "Kill 400 ants in one run as the Mantis.", "mantis"),
    dragonfly = clearWave(10, "tiger_beetle"),
    emperor_scorpion = win("scorpion"),
    whip_scorpion = inRun("kills", 1000, "Kill 1,000 ants in one run."),
    vinegaroon = win("bombardier_beetle"),
    mantis_shrimp = win(),
    pistol_shrimp = win("mantis_shrimp"),
    -- built-in scripted bugs (content/scripted)
    water_strider = clearWave(6, "assassin_bug"),
    mole_cricket = clearWave(8, "camel_spider"),
    velvet_worm = clearWave(8, "orb_weaver"),
}

U.items = {
    royal_jelly = clearWave(10),
    trilobite = inRun("queens", 2, "Kill 2 queens in one run."),
    tardigrade = total("flawlessWaves", 5, "Clear 5 waves without a scratch."),
    amber = { text = "Win a run at Danger 1 or higher.", goal = 1, value = function(p)
        for _, c in pairs(p.characters) do if (c.danger or -1) >= 1 then return 1 end end
        return 0
    end },
    fulgurite = inRun("kills", 500, "Kill 500 ants in one run."),
    cordyceps = { text = "Carry 4 poison items at once.", goal = 4, value = function(_, run)
        local w = run and run.world
        if not w then return 0 end
        local n = 0
        for _, e in ipairs(w.player.inventory.bag) do
            for _, t in ipairs(e.item.def.tags or {}) do if t == "poison" then n = n + 1 break end end
        end
        return n
    end },
    glass_mandible = clearWave(5),
    firefly_lantern = inRun("dashKills", 10, "Kill 10 ants mid-dash in one run."),
}

return U
