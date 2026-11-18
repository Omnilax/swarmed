-- Cursed: a parasite that eats for you. Huge damage, but meals from the bag no longer heal.
return {
    name = "Hungry Tapeworm",
    description = "+40% Damage. Cursed: eating items no longer heals you.",
    curse = "Eating items no longer heals you.",
    rarity = "cursed",
    category = "cursed",
    shape = { "XXX" },
    stats = { damage = 40 },
    noEatHeal = true,
    tags = { "cursed", "offense" },
}
