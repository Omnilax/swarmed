-- Gentle Start: holds systems back over a new player's first runs (numbers and cards in
-- src/config/onramp.lua) and shows a short "NEW" card the first time each one appears.
--
-- Systems ask before they show up:  OnRamp.allows(world, "events", wave)
-- What has been met is kept in the tutorial save (Tutorial.seen["sys:<id>"]), so a system the
-- player has already seen is never held back again.
local Settings = require("src.core.settings")
local Cfg = require("src.config.onramp")

local OnRamp = {}

local function Tutorial() return require("src.game.tutorial") end

-- Is Gentle Start in charge of this world at all?
function OnRamp.active(world)
    if OnRamp.off or not world or world.mode ~= "run" then return false end
    local f = world.flags or {}
    if f.demo or f.practice or world.daily then return false end
    local m = world.modeDef
    if m and (m.onramp == false or m.custom or m.waves) then return false end
    return Settings.get("gentleStart") ~= false
end

-- Which real run this is (1 = the first). Records.track counts the run as it starts.
function OnRamp.runNumber(world)
    if world._onrampRun then return world._onrampRun end
    local Records = require("src.game.records")
    local p = Records.get()
    local n = (p.runs or 0)
    if not (Records.run and Records.run.world == world) then n = n + 1 end
    world._onrampRun = math.max(1, n)
    return world._onrampRun
end

function OnRamp.seen(id) return Tutorial().seen["sys:" .. id] == true end

-- May system `id` show up on wave n of this run?
function OnRamp.allows(world, id, n)
    if not OnRamp.active(world) then return true end
    local rule = Cfg.systems[id]
    if not rule or OnRamp.seen(id) then return true end
    if OnRamp.runNumber(world) < (rule.run or 1) then return false end
    n = n or (world.spawner and world.spawner.wave) or 1
    return n >= (rule.wave or 1)
end

-- Still in the calm first runs (fewer events at once)?
function OnRamp.calm(world)
    return OnRamp.active(world) and OnRamp.runNumber(world) < (Cfg.calmUntilRun or 0)
end

-- The first time a system shows up: remember it and show its card.
function OnRamp.reveal(world, id)
    if not world or world.mode ~= "run" or (world.flags and (world.flags.demo or world.flags.practice)) then return end
    local T = Tutorial()
    local key = "sys:" .. id
    if T.seen[key] then return end
    T.seen[key] = true
    T.save()
    local card = Cfg.cards[id]
    if card then T.notify(card[1], card[2], "NEW") end
end

-- Listen for each system's first appearance (called by World.new).
function OnRamp.attach(world)
    local ev = world.events
    -- players with plenty of runs behind them have met it all already: no cards for them
    if world.mode == "run" and not OnRamp.off then
        local T, runs = Tutorial(), (require("src.game.records").get().runs or 0)
        if runs >= (Cfg.veteranRuns or 6) then
            local changed = false
            for id in pairs(Cfg.systems) do
                if not T.seen["sys:" .. id] then T.seen["sys:" .. id], changed = true, true end
            end
            if changed then T.save() end
        end
    end
    local function on(name, id) ev:on(name, function() OnRamp.reveal(world, id) end) end
    on("elite_spawned", "elites")
    on("treasure_spawned", "treasure")
    on("goal_started", "goals")
    on("wave_modifier", "wavemods")
    on("event_started", "events")
    on("gamble_placed", "gambles")
    on("routes_offered", "routes")
    on("encounter_started", "encounters")
    ev:on("wave_started", function()
        if require("src.game.economy").open(world) then OnRamp.reveal(world, "shop") end
    end)
end

return OnRamp
