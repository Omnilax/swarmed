-- Animation limbs: the oversized left claw and the little right one.
local BIG = { u = 3.5, v = -3, ch = "big", open = "open", width = 3, color = "C", tip = "pincer", tipLen = 3.5,
    segs = { { 3, -0.6 }, { 3.5, 0.4 }, { 3.5, 0.2 } }, strike = { { 4, -0.2, 0.4 }, { 4, 0.2, -0.2 }, { 3.8, 0.1, -0.3 } } }
local SMALL = { u = 3.5, v = 2.5, ch = "small", open = "open", width = 2, color = "C", tip = "pincer", tipLen = 2,
    segs = { { 2, 0.6 }, { 2.5, -0.4 }, { 2, -0.2 } }, strike = { { 3, 0.2 }, { 3, -0.2 }, { 2.5, -0.1 } } }

return {
    name = "Hermit Crab",
    description = "Tough and patient. Pinches with a little claw and a big crushing one. Shift pulls it into its shell: no damage, and it can still walk and pinch. Right click plants a stinging sea anemone: two can be out at once, planted back to back.",
    lore = "Hermit crabs move house as they grow, and some carry sea anemones on their shells as stinging bodyguards.",
    sprite = "hermit_crab",
    model = { legs = "hermit_crab_legs", body = "hermit_crab_body", height = 5, lift = 2 },
    order = 16,
    radius = 9,
    stats = { maxHp = 85, armor = 6, moveSpeed = 82 },
    attack = { type = "hermitpinch", damage = 7, cooldown = 0.38, radius = 20, bigRadius = 29, bigMult = 2.4, offset = 22, color = { 1, 0.6, 0.75 } },
    secondary = { type = "anemone", damage = 3.5, cooldown = 5, range = 110, radius = 24, life = 7, rate = 2.2, slow = { 0.35, 0.8 }, max = 2 },
    dash = { type = "shell", slow = 0.7, thorns = 4, shove = 70 },
    anims = {
        attack = { time = 0.3, limbs = { BIG, SMALL }, build = function(params, p)
            if (p.attack.combo or 1) == 3 then
                return { time = 0.38, limbs = { BIG, SMALL }, keys = { { 0 }, { 0.35, big = 0.5, open = 1, rear = 2, lunge = -1 },
                    { 0.55, big = 1.2, open = 0, rear = -1.5, lunge = 4, spread = 0.3 }, { 1 } } }
            end
            return { time = 0.2, limbs = { BIG, SMALL }, keys = { { 0 }, { 0.3, small = 0.6, open = 1 }, { 0.55, small = 1.1, lunge = 2 }, { 1 } } }
        end },
        secondary = { time = 0.4, keys = { { 0 }, { 0.3, rear = 2, lunge = -1, twist = 0.2 }, { 0.6, lunge = 3, rear = -1 }, { 1 } } },
        -- pulled into the shell: body drops and the legs tuck in, but it still shuffles along
        dash = { time = 0.4, holdAt = 0.35, hold = function(p) return p.blocking end, keys = {
            { 0 }, { 0.35, rear = -2.5, lunge = -2, spread = -0.25, stretch = -0.1 }, { 1 } } },
    },
    startingItems = {},
    tags = { "crustacean", "defensive" },
}
