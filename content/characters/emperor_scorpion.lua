-- Animation limbs: the huge pincer arms (left and right take turns) and the thick tail.
local PINCER = { u = 6, v = 2.5, pair = true, ch = "L", chR = "R", open = "open", width = 3, color = "C", tip = "pincer", tipLen = 4,
    segs = { { 4.8, 0.7 }, { 3.6, -0.15 }, { 4, -0.3 } },
    strike = { { 5.4, 0.35 }, { 5, -0.2 }, { 4.4, -0.15 } } }
local TAIL = { u = -16, v = 0, z = 3, ch = "tail", alpha = "show", width = 4, color = "3", tip = "sting", tipLen = 4,
    segs = { { 3, math.pi - 0.3, 0.3 }, { 3, -0.9, 0 }, { 3, -0.9, 0.1 }, { 3, -0.9, 0.1 }, { 2.5, -0.6, 0 } },
    strike = { { 6.5, 0, 1.2 }, { 6.5, 0, -0.6 }, { 6.5, 0, -0.6 }, { 6, 0, -0.6 }, { 5, 0, -0.5 } } }

return {
    name = "Emperor Scorpion",
    description = "Slow and armoured. Its huge claws crush ants left and right (wounded ones take extra). Right click grabs an ant in each claw and stings them over and over (hold to keep stinging), then slams them down. Hold Shift to brace the claws as a wall: hits from the front glance off and ants ahead get bulldozed.",
    lore = "One of the largest scorpions alive. Its sting is mild for its size: it relies on those enormous claws.",
    sprite = "emperor_scorpion",
    model = { legs = "emperor_scorpion_legs", body = "emperor_scorpion_body", height = 4, lift = 2, kneeUp = 1 },
    order = 14,
    playstyle = "tank",          -- src/config/playstyles.lua
    tip = "Hold {dash} to raise your claws as a wall that ants can't get through. Let go to shove the whole crowd back.",
    radius = 13,
    scale = 1.5,
    stats = { maxHp = 150, armor = 8, moveSpeed = 62, knockback = 40, damage = 10, area = 20 },
    attack = { type = "crushclaws", damage = 13, cooldown = 0.7, radius = 20, offset = 26, spread = 9, execute = 1.6, knockback = 120, poison = { 4, 3 }, color = { 0.6, 0.7, 1 } },
    secondary = { type = "grabstab", damage = 8, cooldown = 3, reach = 46, stabs = 6, minStabs = 3, stabTime = 0.2, splash = 16, poison = { 8, 4 }, slam = 22, color = { 0.75, 1, 0.4 } },
    dash = { type = "clawwall", stamina = 3, regen = 1, speed = 0.6, guard = 1.1, ram = 3, push = 160, releaseRadius = 46, releaseShove = 320 },
    anims = {
        attack = { time = 0.34, mirror = true, limbs = { PINCER }, keys = {
            { 0 }, { 0.35, L = 0.3, open = 1, twist = -0.15, rear = 1, lunge = -1 },
            { 0.55, L = 1.1, open = 0, twist = 0.1, lunge = 3, rear = -1, spread = 0.2 }, { 1 } } },
        secondary = { time = 0.6, holdAt = 0.45, hold = function(p) return p.carry ~= nil and p.carry.kind == "grabstab" end,
            limbs = { PINCER, TAIL }, keys = {
            { 0, show = 1 }, { 0.2, L = 1.2, R = 1.2, open = 1, lunge = 3, reach = 1, show = 1 },
            { 0.35, L = 0.6, R = 0.6, open = 0, tail = 0.4, rear = 1, show = 1 },
            { 0.45, L = 0.6, R = 0.6, tail = 1.1, rear = 2, lunge = 1, show = 1 },
            { 0.8, L = 0.3, R = 0.3, tail = 0.3, rear = -2, lunge = 2, show = 1 }, { 1 } } },
        -- claw wall: both claws held out in front, braced low, for as long as Shift is down
        dash = { time = 0.35, holdAt = 0.5, hold = function(p) return p.holdMode ~= nil end, limbs = { PINCER }, keys = {
            { 0 }, { 0.5, L = 0.75, R = 0.75, open = 0.3, rear = -1.2, spread = 0.35, lunge = 1 }, { 1 } } },
    },
    startingItems = {},
    tags = { "arachnid", "heavy" },
}
