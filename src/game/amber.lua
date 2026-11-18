-- Amber: the currency kept between runs (numbers and the Burrow's stock in src/config/amber.lua).
-- Lives in the records save: profile.amber (to spend), profile.amberEarned (all time) and
-- profile.amberOwned = { [unlock id] = true }.
--
--   Amber.earned(run)      what a finished run pays (Records.endRun calls Amber.award)
--   Amber.owns(id)         is an unlock bought (or open anyway)
--   Amber.itemOpen(id) / Amber.stageOpen(id) / Amber.modeOpen(id)
--   Amber.buy(id)          spend amber on an unlock; true when bought
--   Amber.next()           the cheapest unlock not bought yet (for "next up" lines)
local Cfg = require("src.config.amber")

local Amber = {}

local function Records() return require("src.game.records") end
local function Unlocks() return require("src.game.unlocks") end

-- Every unlock by id, and which unlock holds each item / stage / mode. Built on first use, with
-- an Artifacts shelf made from content/artifacts (src/game/artifacts.lua).
local byId, itemPack, stageUnlock, modeUnlock
local function index()
    if byId then return end
    byId, itemPack, stageUnlock, modeUnlock = {}, {}, {}, {}
    local Content = require("src.content")
    local have = false
    for _, shelf in ipairs(Cfg.shelves) do if shelf.id == "artifacts" then have = true end end
    if not have and Content.artifacts then
        local list = {}
        for _, a in ipairs(Content.artifacts:all()) do
            list[#list + 1] = { id = "artifact_" .. a.id, name = a.name, cost = a.cost, kind = "artifact",
                artifact = a.id, description = a.description .. " Switch it on or off before a run in mode select." }
        end
        Cfg.shelves[#Cfg.shelves + 1] = { id = "artifacts", name = "Artifacts", list = list }
    end
    for _, shelf in ipairs(Cfg.shelves) do
        for _, u in ipairs(shelf.list) do
            u.shelf = shelf.id
            byId[u.id] = u
            for _, it in ipairs(u.items or {}) do itemPack[it] = u end
            if u.stage then stageUnlock[u.stage] = u end
            if u.mode then modeUnlock[u.mode] = u end
        end
    end
end

function Amber.get(id) index() return byId[id] end
function Amber.shelves() index() return Cfg.shelves end

-- The display name of an unlock (stages and modes use their own names).
function Amber.name(u)
    if u.name then return u.name end
    local Content = require("src.content")
    local def = (u.stage and Content.stages:get(u.stage)) or (u.mode and Content.modes:get(u.mode))
    return def and def.name or u.id
end

function Amber.description(u)
    if u.description then return u.description end
    local Content = require("src.content")
    local def = (u.stage and Content.stages:get(u.stage)) or (u.mode and Content.modes:get(u.mode))
    return def and (def.description or def.tagline) or ""
end

-- The profile's amber fields, made on first use. A save that already had runs in it gets a
-- head start, once.
function Amber.profile()
    local p = Records().get()
    if not p.amberStarted then
        local runs = p.runs or 0
        local start = runs >= Cfg.veteranRuns and math.min(Cfg.startCap, runs * Cfg.startPerRun) or 0
        p.amberStarted = true
        p.amber = (p.amber or 0) + start
        p.amberEarned = (p.amberEarned or 0) + start
    end
    p.amberOwned = p.amberOwned or {}
    return p
end

function Amber.balance() return Amber.profile().amber end

function Amber.owns(id)
    if Unlocks().all() then return true end
    return Amber.profile().amberOwned[id] == true
end

function Amber.itemOpen(id)
    index()
    local u = itemPack[id]
    return not u or Amber.owns(u.id)
end

function Amber.stageOpen(id)
    index()
    local u = stageUnlock[id]
    return not u or Amber.owns(u.id)
end

-- A mode is open when bought, or when it was played before amber existed (never taken away).
function Amber.modeOpen(id)
    index()
    local u = modeUnlock[id]
    if not u or Amber.owns(u.id) then return true end
    local m = Amber.profile().modes[id]
    return m ~= nil and (m.runs or 0) > 0
end

-- Already open some other way (a mode played before amber)? Then it isn't for sale.
function Amber.open(u)
    if u.kind == "mode" then return Amber.modeOpen(u.mode) end
    return Amber.owns(u.id)
end

function Amber.modeUnlock(id) index() return modeUnlock[id] end
function Amber.stageUnlock(id) index() return stageUnlock[id] end

function Amber.canBuy(id)
    index()
    local u = byId[id]
    return u ~= nil and not Amber.open(u) and Amber.balance() >= u.cost
end

function Amber.buy(id)
    if not Amber.canBuy(id) then return false end
    local p, u = Amber.profile(), Amber.get(id)
    p.amber = p.amber - u.cost
    p.amberOwned[id] = true
    Records().save()
    return true
end

-- The cheapest thing still to buy (nil when everything is open).
function Amber.next()
    local best
    for _, shelf in ipairs(Amber.shelves()) do
        for _, u in ipairs(shelf.list) do
            if not Amber.open(u) and (not best or u.cost < best.cost) then best = u end
        end
    end
    return best
end

-- What a finished run pays, from its records line.
function Amber.earned(run)
    local e = Cfg.earn
    local n = (run.wavesCleared or 0) * e.perWave + (run.queens or 0) * e.perQueen
        + math.floor((run.elites or 0) / e.perElites) + math.floor((run.kills or 0) / e.perKills)
        + (run.won and e.win or 0)
    if run.mode == "custom" then n = math.floor(n * e.customMul) end
    if (run.wavesCleared or 0) > 0 then n = math.max(e.minimum, n) end
    return n
end

-- One line for the results screens: what this world's run paid (or will pay), and what's next.
function Amber.runLine(world)
    local Rec = Records()
    local run = Rec.run
    if not run or run.world ~= world then return nil end
    local n = run.amber or Amber.earned(run)
    local s = run.amber and ("+%d amber"):format(n) or ("+%d amber so far"):format(n)
    local nx = Amber.next()
    if nx then
        local left = nx.cost - Amber.balance() - (run.amber and 0 or n)
        if left <= 0 then s = s .. "  ·  enough for " .. Amber.name(nx) .. " in the Burrow"
        else s = s .. ("  ·  %d more for %s"):format(left, Amber.name(nx)) end
    end
    return s
end

-- Pay a run out (once). Returns the amount.
function Amber.award(run)
    if run.amber then return run.amber end
    local p = Amber.profile()
    local n = Amber.earned(run)
    run.amber = n
    p.amber = p.amber + n
    p.amberEarned = (p.amberEarned or 0) + n
    return n
end

return Amber
