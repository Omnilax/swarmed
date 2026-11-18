-- TEMPLATE. Copy to content/items/my_item.lua. It appears in the sandbox and console right away.
local Combat = require("src.game.combat")

return {
    name = "My Item",
    description = "What it does, shown in the shop.",
    -- effect = "...",             -- what its procs do, in words (the inventory shows this under the stats)
    rarity = "common",              -- common | uncommon | rare | legendary (src/config/rarities.lua)
    -- What the item is FOR, one of: attack | elemental | guard | mend | move | control | fortune | cursed
    -- (src/config/categories.lua). The bag sorts by it and the shop / catalogue group by it.
    -- Left out, it is guessed from rarity and tags.
    category = "attack",
    price = 25,
    -- Cells it takes in the bag grid { wide, tall }. Everything in the bag counts and copies stack,
    -- so space is the only limit: give bigger items more power for the room they take.
    size = { 1, 1 },
    -- Or a shape instead of a size: rows of cells, "X" filled, "." empty (L's, T's, crosses...):
    -- shape = { "X.", "XX" },
    -- icon = "icon_my_item",       -- sprite id; defaults to "icon_" .. item id (tools/make_item_icons.py)
    -- Flat stat changes (per copy in the bag) (ids in src/config/stats.lua).
    stats = { damage = 5, moveSpeed = -2 },
    -- Multiplier changes per stack: 0.1 = +10% of the final value.
    statsMult = {},
    -- Procs. trigger: onHit | onKill | onHurt | onDash | onWaveStart
    -- chance: number (0..1) or function(stacks) -> number; omitted = always. Luck scales it on a
    -- hyperbolic curve (never 100%, see Inventory.stackChance). chanceStack = 0.5: each extra copy
    -- rolls the chance half a time more (for procs whose effect does not grow with copies).
    -- ctx: world, player, target, damage, crit, x, y, procDepth
    -- Pass procDepth = ctx.procDepth + 1 to any damage you deal so chains stay bounded.
    procs = {
        {
            trigger = "onKill",
            chance = 0.1,
            effect = function(ctx, stacks)
                Combat.area(ctx.world, ctx.x, ctx.y, 30, 5 * stacks, { procDepth = ctx.procDepth + 1 })
            end,
        },
    },
    -- Optional hook when picked up: onAdd = function(player, stacks) end,
    -- shopSpeed = 0.25,           -- the nectar shop restocks 25% faster per copy (src/game/economy.lua)
    -- More bag-wide fields, summed over every copy (Inventory:sum):
    -- waveNectar = 3,             -- nectar paid at each wave clear (Economy.payInterest)
    -- interestCap = 5,            -- savings interest can pay this much more (Economy.interestCap)
    -- beadValue = 0.15,           -- kills drop 15% more nectar (Nectar:onKill)
    -- freeShopRerolls = 1,        -- free shop rerolls after each restock (Economy.rerollPrice)
    -- rarityBump = 0.1,           -- chance an item choice card rolls a rarity higher (Choices.roll)
    -- poisonAmp = 0.15,           -- poisoned ants take 15% more damage (Combat.damage)
    -- Helpers in src/game/itemfx.lua: ItemFx.trail / onTrail (slime trails), ItemFx.guard (take
    -- less damage for a while), ItemFx.patch { hurtPlayer = 4 } (a patch that bites you too).
    tags = {},
}
