-- Leafcutter ant: forms a solid wall ring around the player.
return {
    name = "Leafcutter Ant",
    description = "Surrounds you shoulder to shoulder, forming a living wall you must cut or dash through.",
    lore = "Leafcutters farm fungus on the leaves they carry home, and march in disciplined lines that never break.",
    tip = "Dash straight through the wall, or carve a gap with a wide attack. Its cutting jaws crack your armor.",
    sprite = "leafcutter_ant",
    hp = 7,
    speed = 50,
    damage = 1.5,
    shred = { armor = 1, time = 3, max = 8 },   -- bites crack your armor (src/config/defense.lua)
    radius = 4,
    mass = 3,
    behavior = "wall",
    behaviorParams = { ring = 30, engage = 120 },
    solid = true,
    personalSpace = 0.9,
    swarmShade = 0.18,
    spawn = { weight = 20, minWave = 3, groupSize = 0.7 },
    gibs = { "#4a1e0a", "#94421a", "#5aa83a" },
    splat = "#8c7a36",
    tags = { "ant", "wall" },
}
