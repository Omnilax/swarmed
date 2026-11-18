-- A bumblebee's pollen basket: the hairy hind leg it packs its haul into.
return {
    name = "Pollen Basket",
    description = "+15 Pickup Range. Kills drop 15% more nectar (+15% per stack).",
    rarity = "uncommon",
    category = "fortune",
    size = { 1, 1 },
    stats = { pickupRange = 15 },
    beadValue = 0.15,    -- src/game/nectar.lua Nectar:onKill
    tags = { "utility", "bug" },
}
