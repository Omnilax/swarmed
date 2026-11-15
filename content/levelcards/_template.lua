-- A level-up card (src/game/levelups.lua). Every level-up deals cards: skill-tree nodes of the
-- bug you play, and these global cards anyone can take. A file returns one card or a list.
-- Each card rolls a rarity (common x1 .. legendary x2, Luck makes rare ones likelier) that
-- multiplies its numbers.
return {
    id = "my_card",                 -- defaults to the file name
    name = "Card Name",
    description = nil,              -- optional; stat cards describe themselves ("+6% Speed")
    stats = { armor = 1 },          -- flat adds (src/config/stats.lua ids), times the rarity multiplier
    statsMult = { moveSpeed = 0.06 }, -- multipliers (0.06 = +6%), times the rarity multiplier
    weight = 10,                    -- how often it is dealt
    minLevel = 1,                   -- first level it can show up at
    -- optional: something besides stats (called once when taken). mult = rarity multiplier.
    apply = function(player, mult, world) end,
    -- optional: false = can't be dealt right now (e.g. a heal at full health)
    available = function(player, world) return true end,
}
