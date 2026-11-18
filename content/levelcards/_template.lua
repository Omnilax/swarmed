-- A level-up card (src/game/levelups.lua). Every level-up deals cards anyone can take. A file
-- returns one card or a list. Each card rolls a rarity (common x1 .. legendary x2, Luck makes
-- rare ones likelier) that multiplies its numbers.
--
-- family (shown as a ribbon on the card):
--   "stat"     small boosts (default)              stats / statsMult
--   "pact"     a big boost with a cost             stats / statsMult, plus cost = { stats, statsMult } (not scaled)
--   "growth"   grows every wave for the run        growth = { stats, statsMult } (added at every wave start)
--   "perk"     a lasting effect, ranks up          procs, maxRank, text(power); saveFromDeath(p, power, world)
--   "instant"  happens now, nothing lasting        apply, text(mult)
-- (See perks.lua, pacts.lua, growth.lua, instant.lua for working examples.)
return {
    id = "my_card",                 -- defaults to the file name
    name = "Card Name",
    family = "stat",
    description = nil,              -- optional; stat cards describe themselves ("+6% Speed")
    -- text = function(mult_or_power) return "..." end, -- text with the rolled numbers in it
    stats = { armor = 1 },          -- flat adds (src/config/stats.lua ids), times the rarity multiplier
    statsMult = { moveSpeed = 0.06 }, -- multipliers (0.06 = +6%), times the rarity multiplier
    weight = 10,                    -- how often it is dealt
    minLevel = 1,                   -- first level it can show up at
    -- perks: like item procs (onHit, onKill, onHurt, onDash, onDodge, onBlock, onWaveStart, onTick,
    -- onAttack, onSpecial, onEat). power = sum of the rarity rolls of every copy taken.
    -- procs = { { trigger = "onKill", chance = function(power) return 0.1 end, cooldown = 1,
    --     effect = function(ctx, power, state, levelups) end } },
    -- maxRank = 3,
    -- optional: something besides stats (called once when taken). mult = rarity multiplier.
    apply = function(player, mult, world) end,
    -- optional: false = can't be dealt right now (e.g. a heal at full health)
    available = function(player, world) return true end,
}
