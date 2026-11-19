-- TEMPLATE. Copy to content/routes/my_route.lua. After a wave, two tunnels open in the ground
-- near the player (src/game/routes.lua): one "safe" route and one "hard" route, picked at
-- random by weight. Walking into one starts the next wave that way; ignoring them (or pressing
-- Next Wave) plays a normal wave. Only offered while the break lasts (Settings > Next Wave).
return {
    name = "My Tunnel",
    description = "One short line shown over the tunnel.",
    kind = "hard",                -- "safe" or "hard": one of each is offered
    color = "#e06040",
    weight = 10, minWave = 2,     -- minWave: the earliest wave this route can lead into
    -- the wave itself
    groupMul = 1.4,               -- size of every group of ants
    eliteMul = 1,                 -- elite chance
    hpMul = 1,                    -- enemy health
    -- what clearing that wave pays: bonus XP, a share of the frenzy meter, and the rarity the
    -- best card of the next item choice is at least (common | uncommon | rare | legendary)
    reward = { xp = 15, frenzy = 0, minRarity = "rare" },
}
