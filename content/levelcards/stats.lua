-- Global stat cards: small, steady boosts any bug can take on a level-up. Numbers are the
-- common roll; uncommon x1.33, rare x1.66, legendary x2 (see src/config/levelups.lua).
return {
    { id = "swift_legs", name = "Swift Legs", statsMult = { moveSpeed = 0.06 }, weight = 10 },
    { id = "thick_shell", name = "Thick Shell", stats = { armor = 1 }, weight = 10 },
    { id = "sharp_mandibles", name = "Sharp Mandibles", stats = { damage = 6 }, weight = 12 },
    { id = "quick_reflexes", name = "Quick Reflexes", stats = { attackSpeed = 6 }, weight = 11 },
    { id = "big_appetite", name = "Big Appetite", statsMult = { maxHp = 0.08 }, weight = 10 },
    { id = "sap_glands", name = "Sap Glands", stats = { hpRegen = 0.3 }, weight = 7 },
    { id = "wide_reach", name = "Wide Reach", stats = { area = 6 }, weight = 9 },
    { id = "keen_eyes", name = "Keen Eyes", stats = { critChance = 3 }, weight = 9 },
    { id = "cruel_edge", name = "Cruel Edge", stats = { critDamage = 12 }, weight = 7 },
    { id = "lucky_spots", name = "Lucky Spots", stats = { luck = 8 }, weight = 7 },
    { id = "nimble", name = "Nimble", stats = { dodge = 2 }, weight = 7 },
    { id = "heavy_body", name = "Heavy Body", stats = { knockback = 12 }, weight = 5 },
    { id = "thirsty_jaws", name = "Thirsty Jaws", stats = { lifesteal = 2 }, weight = 6, minLevel = 4 },
    { id = "long_antennae", name = "Long Antennae", stats = { pickupRange = 12 }, weight = 4 },
    { id = "second_wind", name = "Second Wind", statsMult = { dashCooldown = -0.06 }, weight = 7 },
    { id = "nectar_sip", name = "Nectar Sip", weight = 5,
        description = "Heal 35% of your Max HP now",
        scaledText = function(mult) return ("Heal %d%% of your Max HP now"):format(math.floor(35 * mult + 0.5)) end,
        available = function(p) return p.hp < p.stats:get("maxHp") * 0.8 end,
        apply = function(p, mult) p:heal(p.stats:get("maxHp") * 0.35 * mult) end },
}
