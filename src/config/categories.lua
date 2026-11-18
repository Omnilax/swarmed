-- Item categories: what an item is FOR, one per item (`category` in content/items).
-- Tags (src/config/tags.lua) are the many little themes an item shares for set bonuses; the
-- category is the one big answer to "what does this do for me?". The bag sorts by it, the
-- shop and item choice show it, and the Item Catalogue can group by it.
--
-- An item without a `category` gets one from its rarity and tags (Categories.guess), so a new
-- item always lands somewhere sensible. Order here is the order everything is listed in.
-- `glyph` names a little symbol drawn by src/ui/catglyph.lua.
local Categories = {
    order = { "attack", "elemental", "guard", "mend", "move", "control", "fortune", "cursed" },
    attack = { label = "Attack", color = "#ff7a5c", glyph = "fang",
        blurb = "Raw damage, crits and attack speed." },
    elemental = { label = "Elemental", color = "#ffb347", glyph = "spark",
        blurb = "Poison, fire, lightning, blasts and swarms that hurt ants for you." },
    guard = { label = "Guard", color = "#8fb4d8", glyph = "shield",
        blurb = "Armor, max HP and dodge. Some bite back when you are hit." },
    mend = { label = "Mend", color = "#7fe08a", glyph = "heart",
        blurb = "Healing, regeneration and lifesteal." },
    move = { label = "Move", color = "#7fe0d8", glyph = "wing",
        blurb = "Speed, dodges and dashes." },
    control = { label = "Control", color = "#c8a8ff", glyph = "web",
        blurb = "Slows, freezes, knockback and panic: keeps the swarm off you." },
    fortune = { label = "Fortune", color = "#f2d04e", glyph = "clover",
        blurb = "Luck, nectar, pickups and the shop." },
    cursed = { label = "Cursed", color = "#c071ff", glyph = "skull",
        blurb = "Huge power with a catch." },
}

Categories.index = {}
for i, id in ipairs(Categories.order) do Categories.index[id] = i; Categories[id].id = id end

-- A best guess from rarity and tags, for items that don't name a category.
function Categories.guess(def)
    if def.rarity == "cursed" then return "cursed" end
    local has = {}
    for _, t in ipairs(def.tags or {}) do has[t] = true end
    if has.poison or has.fire or has.lightning or has.explosive or has.orbital then return "elemental" end
    if has.healing then return "mend" end
    if has.mobility then return "move" end
    if has.defense then return "guard" end
    if has.offense then return "attack" end
    if has.utility then return "control" end
    return "attack"
end

function Categories.get(id) return Categories[id] or Categories.attack end

-- Sort position of a category id (unknown ones go last).
function Categories.rank(id) return Categories.index[id] or #Categories.order + 1 end

return Categories
