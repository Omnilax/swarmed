-- Club punch (mantis shrimp): one punch per click, no wind-up. The club still strikes fast
-- enough to boil the water, so every punch leaves a cavitation bubble that bursts a beat later.
-- (The held, charged punch lives on the dash now: content/dashes/recoilpunch.lua.)
-- params: damage, cooldown, reach (36), radius (bubble, 26), bubble (x damage, 0.5), knockback, color
local ChargePunch = require("content.attacks.chargepunch")

return {
    name = "Club Punch",
    range = ChargePunch.range,
    fire = function(player, world, ax, ay, params)
        ChargePunch.fire(player, world, ax, ay, params, 0)
    end,
}
