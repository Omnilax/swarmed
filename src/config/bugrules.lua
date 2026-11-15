-- Bug rules: a few bugs change how items work for them, not just their stats. Keyed by
-- character id; shown on the bug select screen. src/game/bugrules.lua runs them.
--
-- A rule (every hook optional):
--   name, description          shown on bug select ("RULE  Recycler: ...")
--   start(world, player, st)   once when the run begins (st = the rule's saved state table)
--   tick(world, player, st, dt) every frame
--   onEat(world, player, st, ctx)   an item is being eaten (ctx.hp = HP it will heal)
--   procChance(def, trigger, ctx) -> multiplier for an item proc's chance
--   procRepeats(def, trigger, ctx) -> how many times an item proc fires (1)
--   stats(player, st) -> { [stat] = { add, mult } }   kept on the player (re-applied on change)
local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

return {
    dung_beetle = {
        name = "Recycler",
        description = "Every item eaten adds +3% damage and +2 max HP for the rest of the run.",
        onEat = function(world, player, st) st.eaten = (st.eaten or 0) + 1 end,
        stats = function(player, st)
            local n = st.eaten or 0
            return { damage = { 3 * n, 0 }, maxHp = { 2 * n, 0 } }
        end,
    },
    hermit_crab = {
        name = "Roomy Shell",
        description = "Starts with an extra bag row, but each filled bag cell slows it by 1%.",
        start = function(world, player) player.inventory:addRows(1) end,
        stats = function(player)
            return { moveSpeed = { 0, -0.01 * player.inventory:usedCells() } }
        end,
    },
    orb_weaver = {
        name = "Web Tension",
        description = "Item procs on webbed or slowed ants fire twice.",
        procRepeats = function(def, trigger, ctx)
            local e = ctx.target
            if e and (e.slowT or 0) > 0 and (trigger == "onHit" or trigger == "onKill") then return 2 end
            return 1
        end,
    },
    hissing_roach = {
        name = "Scavenger",
        description = "Eating an item heals twice as much.",
        onEat = function(world, player, st, ctx) ctx.hp = (ctx.hp or 0) * 2 end,
    },
    scorpion = {
        name = "Venom Sac",
        description = "Poison items proc 50% more often.",
        procChance = function(def) return hasTag(def, "poison") and 1.5 or 1 end,
    },
}
