return {
    name = "Metamorphosis", order = 9, cost = 40, color = "#e7a3ff",
    description = "You start as a random bug from the ones you have unlocked, whoever you picked.",
    params = function(params)
        local Content = require("src.content")
        local Unlocks = require("src.game.unlocks")
        local pool = Content.characters:filter(function(c) return not c.custom and Unlocks.bug(c.id) end)
        if #pool > 0 then params.character = pool[love.math.random(#pool)].id end
    end,
}
