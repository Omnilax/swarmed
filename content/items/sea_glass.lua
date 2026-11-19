-- A shard of bottle glass, tumbled smooth and frosted by the tide. Shore item.
return {
    name = "Sea Glass",
    description = "+4% Crit Chance, +10% Crit Damage. Crustaceans: +3% Crit Chance more.",
    rarity = "common",
    category = "attack",
    size = { 1, 1 },
    stats = { critChance = 4, critDamage = 10 },
    kin = { tags = { "crustacean" }, stats = { critChance = 3 } },
    tags = { "offense", "shore" },
}
