local Env = require("src.game.envfx")
return {
    name = "The Antlion Pit",
    description = "The sand slides toward its jaws. Ants that fall in are eaten; don't follow them.",
    enemy = "antlion",
    weight = 10, minWave = 5,
    xp = 25,
    slain = "THE ANTLION IS DONE FOR",
    -- in open ground, a fair way from the player and the walls
    entry = function(world) return Env.pointAway(world, 160, 130) end,
}
