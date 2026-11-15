local Env = require("src.game.envfx")
return {
    name = "Shadow From Above",
    title = "Sparrow",
    description = "A bird circles overhead. Dodge its swoop, then hit it while it pecks.",
    enemy = "sparrow",
    weight = 10, minWave = 5,
    xp = 25,
    slain = "THE SPARROW FLIES OFF",
    entry = function(world) return Env.pointAway(world, 140, 60) end,
}
