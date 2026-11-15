-- Vinegaroon: a walking acid sprayer. Squirts corrode ants (they take more damage from
-- everything), its palps grab an ant to soak and throw as an acid bomb, and its dash is a
-- double skip that leaves a puff of vinegar behind each push-off.
local PALPS = { u = 7, v = 3, pair = true, ch = "grab", open = "open", width = 3, color = "C", tip = "pincer", tipLen = 3,
    segs = { { 3, 0.6, 0 }, { 3, -0.4, 0 } }, strike = { { 4.5, 0.2, 0.3 }, { 4, -0.2, 0 } } }
local TAIL = { u = -10, v = 0, z = 2, ch = "aim", width = 1, color = "w",
    segs = { { 3, 3.14, 0.2 }, { 3, 0, 0.1 } }, strike = { { 3, 3.14, 1.2 }, { 4, 0, 1.1 } } }

return {
    name = "Vinegaroon",
    description = "Squirts vinegar from its whip tail: acid that corrodes ants so they take more damage, and every 5th squirt leaves a stinging cloud. The special grabs an ant: hold to soak it, let go to hurl it as an acid bomb that leaves a burning pool. Shift is a double dash: skip, then skip again any way you like, each push-off leaving a puff of corroding vinegar.",
    lore = "Its spray is 85% acetic acid, the stuff in vinegar, and it can aim it in any direction by swivelling its tail.",
    sprite = "vinegaroon",
    model = { legs = "vinegaroon_legs", body = "vinegaroon_body", height = 3, lift = 2, stride = 1.5 },
    order = 23,
    playstyle = "ranged",          -- src/config/playstyles.lua
    tip = "Corroded ants take more damage from everything. {secondary} grabs an ant: hold to soak it, let go to throw it as an acid bomb.",
    radius = 8,
    scale = 1.05,
    stats = { maxHp = 62, armor = 3, moveSpeed = 98, area = 10 },
    attack = { type = "acidsquirt", damage = 4, cooldown = 0.32, range = 105, drops = 3, spread = 0.25, corrode = { 1.35, 3 }, burn = { 2, 2 }, cloudEvery = 5, cloudRadius = 26 },
    secondary = { type = "acidbomb", damage = 14, cooldown = 3, reach = 42, soak = 1.5, distance = 125, pool = 42, poolLife = 4, corrode = { 1.4, 3 } },
    dash = { type = "acidskip", distance = 70, speed = 1.1, window = 0.7, damage = 5, radius = 26, corrode = { 1.4, 3 } },
    anims = {
        attack = { time = 0.25, limbs = { TAIL }, keys = { { 0 }, { 0.3, aim = 1, rear = 1 }, { 0.7, aim = 1 }, { 1 } } },
        secondary = { time = 0.5, holdAt = 0.4, hold = function(p) return p.carry ~= nil end, limbs = { PALPS, TAIL }, keys = {
            { 0, open = 1 }, { 0.2, grab = 1, open = 0, lunge = 3 }, { 0.4, grab = 0.8, aim = 1, rear = 1 }, { 0.7, grab = 1.2, lunge = 4, aim = 0.5 }, { 1 } } },
        -- a low skitter with the tail flicked up to puff vinegar behind
        dash = { time = 0.25, limbs = { TAIL }, keys = { { 0, rear = -1.5, spread = 0.3 }, { 0.3, aim = 1, lunge = 3, stretch = 0.1 }, { 1 } } },
    },
    startingItems = {},
    tags = { "arachnid" },
}
