-- A cuckoo's egg laid in your bag. Look after it and something wonderful hatches.
local ItemFx = require("src.game.itemfx")
local Content = require("src.content")

local function hatch(world, p)
    local inv = p.inventory
    local inBag = false
    for _, e in ipairs(inv.bag) do if e.item.id == "cuckoo_egg" then inBag = true end end
    if not inBag then return end
    local pool = {}
    for _, d in ipairs(Content.items:all()) do
        if d.rarity == "legendary" and not d.molted then pool[#pool + 1] = d.id end
    end
    if #pool == 0 then return end
    local id = pool[love.math.random(#pool)]
    inv:remove("cuckoo_egg", 1)
    world:giveItem(id, 1)
    world:floatText(p.x, p.y - 16, "HATCHED: " .. Content.items.byId[id].name:upper(), { 1, 0.75, 0.3 }, true)
    world:addFx({ kind = "ring", x = p.x, y = p.y, r = 36, life = 0.6, color = { 1, 0.8, 0.4 } })
end

return {
    name = "Cuckoo Egg",
    description = "-15 Max HP. Cursed: it hatches into a random legendary item after 3 more waves in your bag.",
    curse = "-15 Max HP while you keep it warm.",
    effect = "After 3 waves in your bag it hatches into a random legendary item.",
    rarity = "cursed",
    category = "cursed",
    size = { 1, 1 },
    stats = { maxHp = -15 },
    procs = {
        {
            trigger = "onWaveStart",
            effect = function(ctx)
                local p = ctx.player
                local s = ItemFx.state(p, "cuckoo_egg")
                s.waves = (s.waves or 0) + 1
                if s.waves > 3 then
                    s.waves = 0
                    -- after the trigger loop: the bag changes
                    p:after(0.05, function() hatch(ctx.world, p) end)
                end
            end,
        },
    },
    tags = { "cursed", "bug" },
}
