-- The claws are animation limbs drawn on top of a clawless body, always there (model.restLimbs):
-- a heavy crusher on the right, a slimmer cutter on the left, like a real lobster. Clips move
-- them by channel: "up" raises the crusher, "slam" drives it down ahead, "open" gapes it,
-- "out" flings both wide (spin), "guard" stands both up as a wall in front (block).
local ARM = { { 3.6, 0.8, 0.15 }, { 3.0, -0.4, 0 }, { 2.6, -0.3, -0.1 } }
local function claw(side, t)
    local c = { u = 5.5, v = 2.5, side = side, group = "claw", width = 3, color = "C", tip = "crusher",
        tipLen = side == 1 and 5.5 or 5, tipW = side == 1 and 1 or 0.62, segs = ARM }
    for k, v in pairs(t or {}) do c[k] = v end
    return c
end
local CRUSHER, CUTTER = claw(1), claw(-1, { restOpen = 0.15 })
-- attack: crusher raised high and open, then slammed down out in front
local SNAP = claw(1, { ch = "up", ch2 = "slam", open = "open",
    strike = { { 3.2, 0.5, 0.9 }, { 3.0, -0.2, 0.35 }, { 3.0, -0.2, -0.1 } },
    alt = { { 4.4, 0.2, -0.15 }, { 4.2, -0.1, 0 }, { 4.0, 0, -0.3 } } })
local SPIN = { claw(1, { ch = "out", strike = { { 4.5, 1.35, 0.2 }, { 3.5, 0.1, 0 }, { 5, 0.1, 0 } } }),
    claw(-1, { ch = "out", strike = { { 4.5, 1.35, 0.2 }, { 3.5, 0.1, 0 }, { 5, 0.1, 0 } } }) }
-- block: both claws swung in and stood up on edge side by side in front of the face
local GUARD = { claw(1, { ch = "guard", strike = { { 3.0, 0.55, 0.7 }, { 2.6, -1.0, 0.1 }, { 2.2, -0.8, -0.5 } } }),
    claw(-1, { ch = "guard", strike = { { 3.0, 0.55, 0.6 }, { 2.6, -1.0, 0.1 }, { 2.2, -0.8, -0.5 } } }) }

return {
    name = "Lobster",
    description = "A big wanderer from the sea in heavy armour. Hold left click to open the crusher claw wider and wider, let go to snap it shut: the longer the hold, the bigger the bite. Shift: brace behind the claws; letting go shoves the swarm back.",
    lore = "Lobsters never really stop growing, and some live to be over a hundred years old.",
    sprite = "lobster",
    model = { legs = "lobster_legs", body = "lobster_body", height = 5, lift = 2, kneeUp = 0.5, restLimbs = { CRUSHER, CUTTER } },
    order = 7,
    playstyle = "tank",          -- src/config/playstyles.lua
    tip = "Hold {attack} to open the crusher claw wider, let go to snap it shut. A full charge bites three and a half times as hard.",
    radius = 14,
    scale = 1.45,
    stats = { maxHp = 145, armor = 9, moveSpeed = 64, hpRegen = 0.5, area = 25 },
    attack = { type = "clawsnap", damage = 10, cooldown = 0.35, charge = 1.1, radius = 16, maxRadius = 40, offset = 26, maxMult = 3.5,
        knockback = 220, color = { 1, 0.6, 0.45 } },
    secondary = { type = "spin", damage = 12, cooldown = 3, radius = 50, turns = 3, turnTime = 0.13, knockback = 220, color = { 1, 0.6, 0.45 } },
    dash = { type = "block", slow = 0.35, shove = 90 },
    anims = {
        -- the crusher snaps shut the moment you let go (the opening is the "charge" clip)
        attack = { time = 0.32, limbs = { SNAP }, keys = {
            { 0, up = 1, open = 1, rear = 2, lunge = -1 },
            { 0.18, slam = 1, open = 0, rear = -1.5, lunge = 5, twist = 0.12, stretch = 0.1, spread = 0.3, shake = 0.6 },
            { 0.55, slam = 0.9, rear = -1, lunge = 3, twist = 0.05 }, { 1 } } },
        charge = { time = 0.5, holdAt = 0.9, hold = function(p) return p.clawCharge ~= nil end, limbs = { SNAP }, keys = {
            { 0 }, { 0.9, up = 1, open = 1, rear = 2, lunge = -2, twist = -0.2, shake = 0.3 }, { 1, up = 1, open = 1, rear = 2 } } },
        secondary = { build = function(params)
            return { time = (params.turns or 3) * (params.turnTime or 0.12) + 0.12, limbs = SPIN, keys = {
                { 0 }, { 0.15, out = 1, rear = 1, spread = 0.3 }, { 0.8, out = 1, rear = 1, spread = 0.3 }, { 1 } } }
        end },
        -- block: hunkered low behind the raised claws, braced wide
        dash = { time = 0.3, holdAt = 0.5, hold = function(p) return p.blocking end, limbs = GUARD, keys = {
            { 0 }, { 0.5, guard = 1, rear = -2, spread = 0.4, stretch = -0.1, lunge = -0.5 }, { 1 } } },
    },
    startingItems = {},
    tags = { "crustacean", "heavy" },
}
