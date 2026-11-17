-- Animation limbs: the spiny legs that form a basket to seize prey on the wing.
local BASKET = { u = 4.5, v = 1.5, z = 0, pair = true, ch = "grab", width = 1, color = "l",
    segs = { { 2, 0.4, -0.5 }, { 2, 0.4, -0.3 } }, strike = { { 3.5, 0.2, 0 }, { 3, -0.8, 0 } } }

return {
    name = "Dragonfly",
    description = "A bomber that never walks: flying is its only way to move. Hold Shift to fly: fast, and only flying enemies can touch it. When it runs out of breath it lands, sweeps ants aside with its wings and takes off again as soon as it can; attacks up there are untouchable diving lunges. Hold right click to snatch an ant and carry it as long as you like; let go to drop it like a bomb.",
    lore = "Dragonflies catch up to 95% of the prey they chase, more than any lion or shark.",
    sprite = "dragonfly",
    model = { legs = "dragonfly_legs", body = "dragonfly_body", height = 2, lift = 3 },
    order = 18,
    playstyle = "speedster",          -- src/config/playstyles.lua
    tip = "It can't walk: hold {dash} to fly and steer. Only flying enemies can reach you up there. Hold {secondary} to snatch an ant, then let go to drop it as a bomb.",
    radius = 6,
    scale = 0.95,
    stats = { maxHp = 30, moveSpeed = 200, dodge = 12, pickupRange = 70 },
    attack = { type = "dragonstrike", damage = 13, cooldown = 0.45, gust = 46, arc = 3.4, gustMult = 0.9, reach = 70, lungeSpeed = 1.7, knockback = 90, color = { 0.5, 0.85, 1 } },
    secondary = { type = "dragongrab", cooldown = 1, reach = 34, bomb = 26, radius = 34, groundMult = 0.6, squeeze = 0, color = { 0.5, 0.85, 1 } },
    dash = { type = "wingflight", stamina = 5, regen = 2.5, minStart = 0.15, speed = 1, groundSpeed = 0, height = 12, downdraft = 8, radius = 40 },
    anims = {
        attack = { time = 0.24, limbs = { BASKET }, build = function(params, p)
            if p.airborne then
                return { time = 0.24, limbs = { BASKET }, keys = { { 0, stretch = 0.15, rear = -1 }, { 0.3, grab = 1, lunge = 4, stretch = 0.2 }, { 0.7, grab = 0.6, stretch = 0.1 }, { 1 } } }
            end
            -- the sweep: wind up to one side, scythe right across the front
            return { time = 0.3, mirror = true, keys = { { 0 }, { 0.2, twist = -0.5, rear = 1, spread = 0.2 }, { 0.55, twist = 0.6, lunge = 1.5, spread = 0.3 }, { 1 } } }
        end },
        secondary = { time = 0.3, limbs = { BASKET }, keys = { { 0, grab = 1 }, { 0.4, grab = 0, rear = 1, stretch = 0.1 }, { 1 } } },
        dash = { time = 0.3, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, keys = {
            { 0 }, { 0.3, rear = -1, spread = 0.3 }, { 0.5, rear = 1, stretch = 0.08 }, { 1 } } },
    },
    startingItems = {},
    tags = { "insect", "flying" },
}
