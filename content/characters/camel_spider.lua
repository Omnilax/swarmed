-- Camel spider (solifuge): the fastest thing in the sand. Jaws that pierce in a quick one-two,
-- a frenzy of darts from ant to ant, and it can tunnel under the ground and burst out beneath
-- the swarm.
local pi = math.pi
local JAWS = { u = 6.5, v = 1.8, pair = true, ch = "bite", open = "gape", width = 2, color = "B", tip = "pincer", tipLen = 2.5,
    segs = { { 3, 0.1, 0 }, { 2, -0.1, 0 } }, strike = { { 4.5, 0.05, 0.2 }, { 3, -0.2, -0.3 } } }
local PALPS = { u = 1.5, v = 2.6, pair = true, ch = "rake", width = 1, color = "l", tip = "fang", tipLen = 1.5,
    segs = { { 5, 0.9, 0.3 }, { 6, -0.6, -0.2 } }, strike = { { 6, 1.6, 0.3 }, { 8, -0.2, -0.3 } } }

return {
    name = "Camel Spider",
    description = "Blazing fast. Its huge jaws drive forward in a quick double thrust that pierces a whole line, its special darts from ant to ant biting each one, and holding Shift tunnels under the sand (untouchable and unseen, on stamina) until you let go and erupt beneath the swarm.",
    lore = "Camel spiders aren't true spiders and have no venom, but their jaws can be a third of their body length. They chase shadows to stay cool.",
    sprite = "camel_spider",
    model = { legs = "camel_spider_legs", body = "camel_spider_body", height = 3, lift = 2, stride = 2, kneeUp = 1 },
    order = 20,
    playstyle = "speedster",          -- src/config/playstyles.lua
    tip = "Hold {dash} to tunnel under the sand: nothing can hit you down there, and surfacing bites everything around you.",
    radius = 6,
    scale = 0.95,
    stats = { maxHp = 40, moveSpeed = 165, attackSpeed = 15 },
    attack = { type = "jawpierce", damage = 7, cooldown = 0.36, reach = 40, width = 6, thrusts = 2, gap = 0.08, bleed = { 2, 3 }, knockback = 40, color = { 1, 0.88, 0.65 } },
    secondary = { type = "frenzy", damage = 11, cooldown = 3, hops = 5, range = 70, radius = 18, bleed = { 4, 3 }, color = { 1, 0.85, 0.55 } },
    dash = { type = "burrow", stamina = 2, regen = 0.8, speed = 1.25, damage = 16, radius = 40 },
    anims = {
        -- one-two: the jaws drive forward twice
        attack = { time = 0.26, limbs = { JAWS }, keys = {
            { 0, gape = 1 }, { 0.2, bite = 1, lunge = 4, stretch = 0.1 }, { 0.4, gape = 1, lunge = 0 },
            { 0.6, bite = 1.1, lunge = 5, stretch = 0.12 }, { 1 } } },
        secondary = { time = 0.5, limbs = { JAWS }, keys = {
            { 0, gape = 1, rear = -1, stretch = 0.15 }, { 0.5, bite = 1, gape = 0.5, stretch = 0.15, lunge = 2 }, { 1 } } },
        -- dives in, stays down while underground, pops up on the eruption
        dash = { time = 0.45, holdAt = 0.3, hold = function(p) return p.holdMode ~= nil end, keys = {
            { 0, rear = -2, spread = 0.4, stretch = -0.15 }, { 0.3, rear = -4, stretch = 0.2 }, { 0.6, rear = 3, spread = 0.3 }, { 1 } } },
    },
    startingItems = {},
    tags = { "arachnid" },
}
