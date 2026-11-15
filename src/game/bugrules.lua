-- Runs the bug rules in src/config/bugrules.lua. The rule follows the player's current bug
-- (the sandbox can swap bugs), and its state lives in world.ruleState so a saved run keeps it.
-- Hooks into Inventory:trigger (proc chance / repeats, onEat, onTick).
local Rules = require("src.config.bugrules")

local BugRules = {}

function BugRules.of(player) return player and player.def and Rules[player.def.id] end

function BugRules.attach(world)
    world.ruleState = world.ruleState or {}
    world.ruleStarted = false
end

local function state(world, id)
    local all = world.ruleState
    if not all then all = {} world.ruleState = all end
    all[id] = all[id] or {}
    return all[id]
end

-- Keep the rule's stat bonus on the player (only touches the stats when it changes).
local function applyStats(world, player, rule, st)
    if not rule.stats then return end
    local want = rule.stats(player, st)
    local key = ""
    for k, v in pairs(want) do key = key .. k .. (v[1] or 0) .. "/" .. (v[2] or 0) .. ";" end
    if player._ruleKey == key and player._ruleStats == player.stats then return end
    player.stats:removeSource("rule")
    for stat, v in pairs(want) do player.stats:addModifier("rule", stat, v[1] or 0, v[2] or 0) end
    player._ruleKey, player._ruleStats = key, player.stats
end

-- Called from Inventory:trigger for every trigger the bag sees.
function BugRules.trigger(player, name, ctx)
    local rule = BugRules.of(player)
    if not rule then return end
    local world = player.world
    local st = state(world, player.def.id)
    if name == "onTick" then
        if not world.ruleStarted and world.mode == "run" then
            world.ruleStarted = true
            if rule.start and not st.started then rule.start(world, player, st) end
            st.started = true
        end
        if rule.tick then rule.tick(world, player, st, ctx.dt or 0) end
        applyStats(world, player, rule, st)
    elseif name == "onEat" and rule.onEat then
        rule.onEat(world, player, st, ctx)
    end
end

-- Chance multiplier and repeat count for one item proc.
function BugRules.proc(player, def, name, ctx)
    local rule = BugRules.of(player)
    if not rule then return 1, 1 end
    return rule.procChance and rule.procChance(def, name, ctx) or 1,
        rule.procRepeats and rule.procRepeats(def, name, ctx) or 1
end

return BugRules
