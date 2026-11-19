return {
    name = "Tarantula",
    description = "Big, hairy and tough. Rears up and stomps down, stunning everything in front. Hold right click to kick a stream of itching hairs where you point, slowing every ant they hit. Shift: leap and crash down on the swarm.",
    lore = "New World tarantulas kick barbed hairs off their abdomen at attackers. They itch terribly.",
    sprite = "tarantula",
    model = { legs = "tarantula_legs", body = "tarantula_body", height = 5, lift = 3, kneeUp = 2.5 },
    order = 10,
    playstyle = "tank",          -- src/config/playstyles.lua
    tip = "Your stomp stuns everything in front of you. Hold {secondary} to kick itching hairs that slow the whole crowd.",
    radius = 11,
    scale = 1.35,
    stats = { maxHp = 120, armor = 4, moveSpeed = 82, hpRegen = 0.6, area = 20 },
    attack = { type = "fangslam", damage = 17, cooldown = 0.95, radius = 36, offset = 16, windup = 0.22, stun = 0.8, knockback = 180, color = { 1, 0.6, 0.3 } },
    secondary = { type = "hairflick", cooldown = 0, damage = 0.6, rate = 0.09, range = 130, spread = 0.22, speed = 300, slow = { 0.6, 1.2 }, color = { 1, 0.6, 0.3 } },
    dash = { type = "leapslam", distance = 80, speed = 0.85, hop = 16, damage = 14, radius = 36, stun = 0.6, knockback = 200 },
    startingItems = {},
    tags = { "spider", "arachnid", "heavy" },
}
