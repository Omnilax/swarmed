-- Every player stat. Items, characters and level-ups modify these by id, so adding a stat here
-- makes it available to all content. `percent` stats are shown with a % sign.
return {
    { id = "maxHp", label = "Max HP", default = 50, min = 1 },
    { id = "hpRegen", label = "HP Regen /s", default = 0, min = 0 },
    { id = "armor", label = "Armor", default = 0 },
    { id = "dodge", label = "Dodge", default = 0, min = 0, max = 60, percent = true },
    { id = "moveSpeed", label = "Speed", default = 100, min = 20 },
    { id = "damage", label = "Damage", default = 0, min = -90, percent = true },
    { id = "attackSpeed", label = "Attack Speed", default = 0, min = -80, percent = true },
    { id = "area", label = "Area", default = 0, min = -80, percent = true },
    { id = "knockback", label = "Knockback", default = 0, min = -100, percent = true },
    { id = "critChance", label = "Crit Chance", default = 5, min = 0, max = 100, percent = true },
    { id = "critDamage", label = "Crit Damage", default = 150, min = 100, percent = true },
    { id = "luck", label = "Luck", default = 0, percent = true },
    { id = "lifesteal", label = "Life Steal", default = 0, min = 0, max = 100, percent = true },
    { id = "pickupRange", label = "Pickup Range", default = 40, min = 0 },
    { id = "dashCooldown", label = "Dash Cooldown", default = 1.2, min = 0.2, lowerIsBetter = true },
}
