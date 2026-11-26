-- Shore items and the crustaceans' home turf.
--
-- An item can name the bugs it belongs with:
--   kin = { tags = { "crustacean" }, stats = { armor = 3 }, statsMult = {} }
-- Playing a bug with one of those tags (content/characters `tags`), each copy also gives the
-- kin stats, and the item turns up more often on item choice cards (KIN_WEIGHT). Items tagged
-- "shore" also turn up more often on the beach maps (stage `shore = true`).
local Shore = {}

Shore.KIN_WEIGHT = 2.5     -- item choice weight for an item whose kin you are playing
Shore.STAGE_WEIGHT = 2     -- ... and for a "shore" item on a beach map

local function hasTag(list, tag)
    for _, t in ipairs(list or {}) do if t == tag then return true end end
    return false
end

-- True when `player` (or a character def) is one of the item's kin.
function Shore.isKin(player, def)
    local kin = def and def.kin
    if not kin or not player then return false end
    local cdef = player.def or player
    for _, t in ipairs(kin.tags or {}) do
        if hasTag(cdef.tags, t) then return true end
    end
    return false
end

-- Bugs at home on the water that aren't crustaceans (by character id).
Shore.WATER_BUGS = { water_strider = true }

-- True for crustaceans, the water bugs above and anything else tagged as at home in water
-- (a Bug Creator bug can take the "amphibious" or "aquatic" tag).
function Shore.amphibious(player)
    local cdef = player and (player.def or player)
    if not cdef then return false end
    return Shore.WATER_BUGS[cdef.id] or hasTag(cdef.tags, "crustacean") or hasTag(cdef.tags, "amphibious")
        or hasTag(cdef.tags, "aquatic") or false
end

-- Item choice weight multiplier for def in this world.
function Shore.weight(world, def)
    local w = 1
    local p = world and world.player
    if p and Shore.isKin(p, def) then w = w * Shore.KIN_WEIGHT end
    if world and world.stage and world.stage.shore and hasTag(def.tags, "shore") then w = w * Shore.STAGE_WEIGHT end
    return w
end

-- The stats one copy of def gives this player: its own plus its kin stats when they apply.
-- Returns add, mult (new tables only when kin stats are added).
function Shore.statsFor(def, player)
    local add, mult = def.stats or {}, def.statsMult or {}
    if not Shore.isKin(player, def) then return add, mult end
    local a, m = {}, {}
    for k, v in pairs(add) do a[k] = v end
    for k, v in pairs(mult) do m[k] = v end
    for k, v in pairs(def.kin.stats or {}) do a[k] = (a[k] or 0) + v end
    for k, v in pairs(def.kin.statsMult or {}) do m[k] = (m[k] or 0) + v end
    return a, m
end

return Shore
