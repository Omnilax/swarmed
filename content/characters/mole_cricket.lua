-- Mole cricket: a slow, tough digger with two huge shovel forelegs. Clumsy on top (it slides
-- about: movement.slide), precise and fast underground (content/dashes/moledig.lua). The
-- shovels are animation limbs drawn on top of a body without them (model.restLimbs), so they
-- swing in the slash, scoop up the sand toss and dig.
local ARM = { { 3.0, 1.0, 0.2 }, { 3.0, -0.9, 0 }, { 1.6, -0.5, -0.2 } }
local function shovel(t)
    local s = { u = 7, v = 3.5, group = "shovel", width = 3, color = "C", tip = "crusher", tipLen = 3.2, tipW = 1.3, segs = ARM }
    for k, v in pairs(t or {}) do s[k] = v end
    return s
end
local SHOVEL = shovel()
-- slash: one shovel swept round and across in front (the clip alternates sides)
local SWIPE = shovel({ pair = true, ch = "L", chR = "R",
    strike = { { 4.2, 0.1, 0.4 }, { 4.6, -0.3, 0 }, { 2.2, -0.4, -0.3 } } })
-- sand toss: both shovels scoop low and fling up and forward
local SCOOP = shovel({ pair = true, ch = "scoop",
    strike = { { 3.6, 0.35, 0.9 }, { 3.6, -0.45, 0.6 }, { 2.0, -0.3, 0.4 } } })
-- digging in: both shovels drive down into the soil
local DIG = shovel({ pair = true, ch = "dig",
    strike = { { 3.0, 0.3, -0.7 }, { 3.0, -0.3, -0.5 }, { 1.6, 0, -0.4 } } })

return {
    name = "Mole Cricket",
    description = "Slow, tough and clumsy on top: it slides about. Its shovel claws slash in a huge swipe, and right click flings a spray of sand like a shotgun (the closer the ants, the harder it hits). Hold Shift to dig: underground it is fast, precise and untouchable. Attack to burst out with an uppercut, right click for an earthquake. Letting go just pops you up, and digging takes a long time to recharge.",
    lore = "Mole crickets spend almost their whole lives underground, digging with forelegs shaped like a mole's paws. Males dig a horn-shaped burrow that makes their song louder.",
    sprite = "mole_cricket",
    model = { legs = "mole_cricket_legs", body = "mole_cricket_body", height = 5, lift = 2, kneeUp = 0.5, restLimbs = { SHOVEL } },
    order = 27,
    playstyle = "tank",          -- src/config/playstyles.lua
    tip = "Hold {dash} to dig. Underground, {attack} bursts out with an uppercut and {secondary} sets off an earthquake. Just letting go wastes the dig!",
    radius = 11,
    scale = 1.25,
    -- clumsy on the surface: steering eases in like on ice (the dig turns this off)
    movement = { slide = 0.8 },
    stats = { maxHp = 125, armor = 6, moveSpeed = 72, knockback = 30 },
    attack = { type = "arc", damage = 15, cooldown = 0.75, radius = 46, arc = 2.8, knockback = 170, color = { 1, 0.85, 0.6 } },
    secondary = { type = "sandtoss", damage = 3, cooldown = 1.5, grains = 14, spread = 0.95, range = 170, speed = 300, falloff = 0.8, knockback = 30 },
    dash = { type = "moledig", stamina = 3.5, regen = 0.3, minStart = 0.5, speed = 2.1,
        strike = 26, strikeRadius = 54, strikeArc = 3.4, quake = 24, quakeRadius = 100, quakeStun = 1 },
    anims = {
        attack = { time = 0.36, mirror = true, limbs = { SWIPE }, keys = {
            { 0 }, { 0.3, L = -0.5, twist = -0.35, rear = 1, lunge = -1 },
            { 0.55, L = 1.1, twist = 0.45, lunge = 3, rear = -0.5, stretch = 0.06 }, { 1 } } },
        secondary = { time = 0.4, limbs = { SCOOP }, keys = {
            { 0 }, { 0.25, scoop = -0.6, rear = -1.5, lunge = -1 },
            { 0.5, scoop = 1.1, rear = 1, lunge = 2, stretch = 0.08 }, { 1 } } },
        dash = { time = 0.3, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, limbs = { DIG }, keys = {
            { 0 }, { 0.5, dig = 1, rear = -2, lunge = 1, spread = 0.3 }, { 1 } } },
    },
    startingItems = {},
    tags = { "insect", "heavy" },
}
