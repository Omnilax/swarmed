-- Every player stat. Items, characters and level-ups modify these by id, so adding a stat here
-- makes it available to all content. `percent` stats are shown with a % sign, `suffix` adds a
-- unit, `lowerIsBetter` flips the good / bad colours, and `info(value)` explains the value in
-- real numbers (stat tooltips in the bag and the pause screen).
local function pct(v) return math.floor(v + 0.5) end
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end

return {
    { id = "maxHp", label = "Max HP", default = 50, min = 1,
        info = function(v) return ("You can take %d damage from full health before you fall."):format(pct(v)) end },
    { id = "hpRegen", label = "HP Regen /s", default = 0, min = 0,
        info = function(v)
            if v <= 0 then return "No healing over time." end
            return ("Heals %s HP every second (%d HP a minute)."):format(r1(v), pct(v * 60))
        end },
    { id = "armor", label = "Armor", default = 0,
        info = function(v)
            -- matches armorMultiplier in src/game/player.lua
            local m = v >= 0 and 15 / (15 + v) or (15 - v) / 15
            if v >= 0 then return ("Every hit on you does %d%% less damage (a 10 damage bite does %s)."):format(pct((1 - m) * 100), r1(10 * m)) end
            return ("Every hit on you does %d%% more damage (a 10 damage bite does %s)."):format(pct((m - 1) * 100), r1(10 * m))
        end },
    -- soft = { knee, cap }: past the knee each point counts for less (src/game/stats.lua Stats.soften)
    { id = "dodge", label = "Dodge", default = 0, min = 0, max = 100, percent = true, soft = { 30, 60 },
        info = function(v) return ("%d%% chance that a hit misses you completely. Past 30%% each point counts for less, and it never reaches 60%%."):format(pct(v)) end },
    { id = "moveSpeed", label = "Speed", default = 100, min = 20,
        info = function(v) return ("Walks %d pixels a second (%d%% of a standard bug)."):format(pct(v), pct(v)) end },
    { id = "damage", label = "Damage", default = 0, min = -90, percent = true,
        info = function(v) return ("Every hit does %d%% of its base damage (a 10 damage bite does %s)."):format(pct(100 + v), r1(10 * (1 + v / 100))) end },
    { id = "attackSpeed", label = "Attack Speed", default = 0, min = -80, percent = true,
        info = function(v) return ("Attacks %sx as often as normal."):format(r1(math.max(0.2, 1 + v / 100))) end },
    { id = "area", label = "Area", default = 0, min = -80, percent = true,
        info = function(v) return ("Reach and blast size are %d%% of normal (a 40 px swing reaches %d px)."):format(pct(100 + v), pct(40 * (1 + v / 100))) end },
    { id = "knockback", label = "Knockback", default = 0, min = -100, percent = true,
        info = function(v) return ("Your hits push ants %d%% as far as normal."):format(pct(100 + v)) end },
    { id = "critChance", label = "Crit Chance", default = 5, min = 0, max = 100, percent = true,
        info = function(v) return ("%d%% of your hits are critical (about 1 in %s)."):format(pct(v), v > 0 and tostring(r1(100 / v)) or "never") end },
    { id = "critDamage", label = "Crit Damage", default = 150, min = 100, percent = true,
        info = function(v) return ("Critical hits do %sx damage (a 10 damage bite crits for %s)."):format(r1(v / 100), r1(v / 10)) end },
    { id = "luck", label = "Luck", default = 0, percent = true,
        info = function(v)
            -- matches Inventory.stackChance in src/game/inventory.lua
            local m = math.max(0, 1 + v / 100)
            local function at(c) return r1(100 * (1 - (1 - c) ^ m)) end
            return ("Item effects roll %sx as often (a 10%% chance becomes %s%%, a 50%% chance %s%%). It never reaches 100%%."):format(r1(m), at(0.1), at(0.5))
        end },
    { id = "lifesteal", label = "Life Steal", default = 0, min = 0, max = 100, percent = true,
        info = function(v)
            if v <= 0 then return "Hits don't heal you." end
            return ("%d%% of your hits heal 1 HP (about 1 HP every %s hits)."):format(pct(v), r1(100 / v))
        end },
    { id = "pickupRange", label = "Pickup Range", default = 40, min = 0,
        info = function(v) return ("%d px. Nothing lies on the ground right now (items go straight to the bag), so this does nothing yet."):format(pct(v)) end },
    { id = "dashCooldown", label = "Dash Cooldown", default = 1.2, min = 0.2, suffix = "s", lowerIsBetter = true,
        info = function(v) return ("Stamina (dashes, blocks, modes) refills %sx as fast as normal (1.2s)."):format(r1(1.2 / math.max(0.2, v))) end },
}
