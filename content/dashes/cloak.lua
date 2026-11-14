-- Cloak (pistol shrimp): it vanishes into a shimmer of bubbles. While cloaked (player.cloakT)
-- the ants lose track of it: they stop chasing and biting and search around where it was last
-- seen (World:updateEnemies). Stray shots can still hit. It moves faster; attacking reveals it,
-- but a sniper snap fired from the cloak hits twice as hard (content/attacks/snapshot.lua).
-- Dashes a short hop as it fades.
-- params: time (2.2 s), speed (move speed x while cloaked, 1.3), distance (40)
local Audio = require("src.core.audio")

local Cloak = {
    name = "Cloak",
    description = "Turn invisible: the ants lose track of you and you move faster. Attacking reveals you, but a snap shot from the cloak hits twice as hard.",
}

-- Drop the cloak early (attacking). Returns true if it was on.
function Cloak.reveal(player)
    if not player.cloakT then return false end
    player.cloakT, player.alpha, player.moveMul = nil, nil, nil
    player.world.particles:burst(player.x, player.y, 8, { { 0.75, 0.9, 1 } }, 60, 30, { glow = true, grav = -30 })
    return true
end

function Cloak.start(player, world, dx, dy, params)
    player:lunge(dx, dy, params.distance or 40, 1)
    local id = {}
    local time = params.time or 2.2
    player.cloakT = id
    player.alpha = 0.22
    player.moveMul = params.speed or 1.3
    world.particles:burst(player.x, player.y, 14, { { 0.75, 0.9, 1 }, { 1, 1, 1 } }, 80, 40, { glow = true, grav = -30 })
    Audio.play("zap", { pitch = 2, volume = 0.4 })
    player:after(time, function(p) if p.cloakT == id then Cloak.reveal(p) end end)
end

return Cloak
