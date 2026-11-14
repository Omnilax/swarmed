-- Shadow dash (wolf spider): a low, fast dart that ends with the spider melting into the leaf
-- litter. For a moment afterwards it is camouflaged (player.cloakT, see content/dashes/cloak.lua):
-- the ants lose track of it and search where it was. Its own bursts don't give it away.
-- params: distance (90), speed (x normal dash speed, 1.3), hide (seconds hidden after, 1.4),
--         run (move speed x while hidden, 1.15), charges
local Audio = require("src.core.audio")
local Cloak = require("content.dashes.cloak")

return {
    name = "Shadow Dash",
    description = "Dart low and fast, then vanish into the leaf litter for a moment: the ants lose track of you.",
    start = function(player, world, dx, dy, params)
        player:lunge(dx, dy, params.distance or 90, params.speed or 1.3)
        local id = {}
        player:after(player.dashT, function(p, w)
            Cloak.reveal(p)     -- a fresh cloak, so the ants have to guess your spot again
            p.cloakT, p.alpha, p.moveMul = id, 0.3, params.run or 1.15
            w.particles:burst(p.x, p.y, 10, { { 0.45, 0.4, 0.3 }, { 0.6, 0.55, 0.4 } }, 50, 30, { grav = 120 })
            Audio.play("dash", { pitch = 0.6, volume = 0.4 })
            p:after(params.hide or 1.4, function(q) if q.cloakT == id then Cloak.reveal(q) end end)
        end)
    end,
}
