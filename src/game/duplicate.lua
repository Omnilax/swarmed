-- The aphid matriarch's cloning (content/events/aphid_matriarch.lua, src/states/duplicate.lua):
-- one bag item is copied by eating another item of the same rarity.
local Inventory = require("src.game.inventory")

local Duplicate = {}

-- Entries of the same rarity as `e`, other than e itself (what could be fed to copy e).
function Duplicate.partners(inv, e)
    local out = {}
    for _, o in ipairs(inv.bag) do
        if o ~= e and o.item.def.rarity == e.item.def.rarity then out[#out + 1] = o end
    end
    return out
end

-- Does the bag hold two items of one rarity?
function Duplicate.anyPair(inv)
    local seen = {}
    for _, e in ipairs(inv.bag) do
        local r = e.item.def.rarity
        if seen[r] then return true end
        seen[r] = true
    end
    return false
end

-- Eat `food` and copy `target`. Returns the copy and whether it found room in the bag
-- (if not, the caller lets the player make room, as with an item choice).
function Duplicate.clone(world, target, food)
    local inv = world.player.inventory
    if target == food or target.item.def.rarity ~= food.item.def.rarity then return nil end
    inv:removeEntry(food)
    world.events:emit("item_eaten", food.item)
    local copy = Inventory.newItem(target.item.id)
    copy.rot = target.item.rot
    local ok = inv:give(copy)
    world.events:emit("item_duplicated", target.item.id, food.item.id)
    return copy, ok
end

return Duplicate
