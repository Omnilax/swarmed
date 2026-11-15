-- Which bugs and items are open (data in src/config/unlocks.lua), the item pool the player
-- switched on or off (Settings > Gameplay > Item Pool, src/states/itempool.lua), and danger
-- levels per bug (src/config/danger.lua).
--
-- Unlocks are achievements (content/achievements/unlocks.lua builds them), so the Records save
-- keeps them: a bug is open when it is a starter, its goal's achievement is unlocked, it was
-- played before unlocks existed, or the "Unlock Everything" setting is on. Unlocks.free makes
-- everything open (selftests and the balance bot set it).
local Config = require("src.config.unlocks")
local Danger = require("src.config.danger")

local Unlocks = { free = false }

local starter = {}
for _, id in ipairs(Config.starters) do starter[id] = true end

function Unlocks.bugAchievement(id) return "unlock_bug_" .. id end
function Unlocks.itemAchievement(id) return "unlock_item_" .. id end

local function Records() return require("src.game.records") end

function Unlocks.all()
    if Unlocks.free then return true end
    local ok, Settings = pcall(require, "src.core.settings")
    return ok and Settings.get("unlockAll") == true
end

-- The goal that opens a bug / item (nil = always open).
function Unlocks.bugGoal(id)
    if starter[id] then return nil end
    return Config.bugs[id]
end
function Unlocks.itemGoal(id) return Config.items[id] end

function Unlocks.bug(id)
    if Unlocks.all() or not Unlocks.bugGoal(id) then return true end
    local p = Records().get()
    if p.achievements[Unlocks.bugAchievement(id)] then return true end
    -- played before unlocks were added: don't take it away
    local c = p.characters[id]
    return c ~= nil and (c.runs or 0) > 0
end

function Unlocks.item(id)
    if Unlocks.all() or not Config.items[id] then return true end
    return Records().get().achievements[Unlocks.itemAchievement(id)] ~= nil
end

-- Progress text for a locked bug or item: "Clear wave 5 as the Rhino Beetle.  (3 / 5)".
function Unlocks.progressText(goal)
    if not goal then return "" end
    local Rec = Records()
    local v, g = Rec.progress(goal, Rec.get(), Rec.run and not Rec.run.ended and Rec.run or nil)
    if g <= 1 then return goal.text end
    return ("%s  (%d / %d)"):format(goal.text, math.floor(v), g)
end

-- How many bugs are open, out of all of them.
function Unlocks.bugCount()
    local n, all = 0, 0
    for _, c in ipairs(require("src.content").characters:all()) do
        all = all + 1
        if Unlocks.bug(c.id) then n = n + 1 end
    end
    return n, all
end

----------------------------------------------------------------------------------------------
-- Item pool

-- The player's own pool: items switched off (prefs "poolOff" = { [id] = true }).
function Unlocks.poolOff()
    local d = require("src.game.prefs").get()
    if type(d.poolOff) ~= "table" then d.poolOff = {} end
    return d.poolOff
end

function Unlocks.inPool(id)
    if not Unlocks.item(id) then return false end
    if Unlocks.free then return true end
    return not Unlocks.poolOff()[id]
end

Unlocks.MIN_POOL = 12      -- the pool can't shrink below this many items

function Unlocks.poolSize()
    local n = 0
    for _, d in ipairs(require("src.content").items:all()) do if Unlocks.inPool(d.id) then n = n + 1 end end
    return n
end

-- Switch an item in or out of the pool. Returns false when it would leave too few.
function Unlocks.setInPool(id, on)
    local off = Unlocks.poolOff()
    if not on and not off[id] and Unlocks.poolSize() <= Unlocks.MIN_POOL then return false end
    off[id] = (not on) or nil
    require("src.game.prefs").save()
    return true
end

----------------------------------------------------------------------------------------------
-- Danger levels

Danger.MAX = #Danger

-- Highest danger won with a bug (-1 = never won).
function Unlocks.bestDanger(id)
    local c = Records().get().characters[id]
    return c and c.danger or -1
end

-- Highest danger the player may pick for a bug: one above the best won.
function Unlocks.maxDanger(id)
    if Unlocks.all() then return Danger.MAX end
    return math.max(0, math.min(Danger.MAX, Unlocks.bestDanger(id) + 1))
end

-- The rules in effect at a danger level, folded into one table (every level up to n adds one).
function Unlocks.dangerRules(n)
    local out = { level = n or 0, hpMul = 1, damageMul = 1, speedMul = 1, eliteMul = 1, healMul = 1,
        extraQueens = 0, groupMul = 1 }
    for i = 1, math.min(n or 0, Danger.MAX) do
        for k, v in pairs(Danger[i].rules) do
            if k == "extraQueens" then out[k] = out[k] + v else out[k] = out[k] * v end
        end
    end
    return out
end

return Unlocks
