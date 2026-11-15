-- The daily run: one seed per calendar day picks the bug, the stage, the species order and every
-- wave modifier, so everyone playing that day faces the same run (Colony rules). Your best result
-- for each day is kept in the records save (Records.profile.daily).
local Content = require("src.content")

local Daily = {}

-- "2026-11-14" and 20261114 for today (or for os time t).
function Daily.today(t)
    local d = os.date("*t", t or os.time())
    return ("%04d-%02d-%02d"):format(d.year, d.month, d.day), d.year * 10000 + d.month * 100 + d.day
end

-- Everything the day decides: { key, seed, character, stage, gameMode }.
function Daily.info(t)
    local key, seed = Daily.today(t)
    local rng = love.math.newRandomGenerator(seed)
    rng:random()     -- the first draw of a fresh generator barely moves with the seed
    local chars, stages = Content.characters:all(), Content.stages:all()
    local c = chars[rng:random(#chars)]
    local s = stages[rng:random(#stages)]
    return { key = key, seed = seed * 7919 + 17, character = c.id, stage = s.id, gameMode = "colony" }
end

-- Game params for today's run.
function Daily.params(t)
    local d = Daily.info(t)
    return { mode = "run", character = d.character, stage = d.stage, gameMode = d.gameMode, seed = d.seed, daily = d.key }
end

-- Today's best { wave, kos, won } (or nil).
function Daily.best(key)
    local p = require("src.game.records").get()
    return p.daily and p.daily[key or Daily.today()]
end

return Daily
