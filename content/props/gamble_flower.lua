-- Gamble flower (a map gamble, src/game/gambles.lua): a daisy with ten coloured petals. Walk
-- into it with enough nectar to spin it: the petals light up round and round and stop on one.
-- Most petals are good (an item, a rare item, a blessing, nectar back or three times over, XP,
-- a full heal); some are not (nothing, a swarm of ants, a curse that lowers a stat for the run).
-- A few spins, each dearer than the last, then it wilts. Needs the nectar currency
-- (World:spendNectar); without it the flower never shows up.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
local Content = require("src.content")
local Audio = require("src.core.audio")
local util = require("src.core.util")
local Env = require("src.game.envfx")
local Gambles = require("src.game.gambles")

local function cfg(world) return world.gambles.cfg.flower end

local function hasNectar(world) return world.spendNectar ~= nil and world.canAffordNectar ~= nil end
local function balance(world) return math.floor(world.nectar or 0) end

local function price(world, o)
    local c = cfg(world)
    local wave = math.max(1, world.spawner.wave or 1)
    return math.floor((c.cost + wave * c.costPerWave) * (1 + (o.st.spins or 0) * c.costGrow) + 0.5)
end

local function leave(world, o)
    if o.leaving then return end
    o.leaving, o.busy, o.st.fade = true, false, 0.8
end

local function colorOf(out)
    out._c = out._c or util.hex(out.color)
    return out._c
end

-- A rare-or-better item for the bag.
local function rareItem(world)
    local R = require("src.config.rarities")
    local def = Content.items:pickWeighted(function(d) return R[d.rarity].weight end,
        function(d) return R[d.rarity] and R[d.rarity].order >= R.rare.order end)
    return def or world:rollItem().def
end

-- What each petal does. Returns the text to float.
local RESOLVE = {
    item = function(world, o)
        local it = world:rollItem()
        local eaten = world:giveItem(it.def.id)
        return eaten > 0 and ("Bag full: ate " .. it.def.name) or it.def.name
    end,
    rare_item = function(world, o)
        local def = rareItem(world)
        local eaten = world:giveItem(def.id)
        return eaten > 0 and ("Bag full: ate " .. def.name) or def.name
    end,
    blessing = function(world, o)
        local b = world.gambles:rollBlessings(1)[1]
        world.gambles:bless(b.stat, b.add, "flower")
        return "Blessed!"
    end,
    jackpot = function(world, o)
        local n = o.st.paid * 3
        world:addNectar(n)
        return "JACKPOT +" .. n .. " nectar"
    end,
    refund = function(world, o)
        world:addNectar(o.st.paid)
        return "Nectar back"
    end,
    xp = function(world, o)
        local n = 10 + math.max(1, world.spawner.wave or 1) * 3
        world:grantXP(n, o.x, o.y - 10)
        return "+" .. n .. " XP"
    end,
    heal = function(world, o)
        local p = world.player
        p:heal(p.stats:get("maxHp"))
        return "Fully healed"
    end,
    wilt = function(world, o)
        return "The petals droop... nothing"
    end,
    swarm = function(world, o)
        local sp = world.spawner
        local def = sp:pickEnemy()
        local n = math.floor(6 + math.max(1, sp.wave or 1) * 0.6)
        if def then world:spawnRing(def, n, o.x, o.y, 110) end
        world.camera:shake(0.2)
        return "ANTS!"
    end,
    curse = function(world, o)
        world.gambles:curse("flower")
        return "Cursed..."
    end,
}

-- Which petal it lands on (ants only come while a wave is on: in a break that petal is "nothing").
local function roll(world, o)
    local outs = cfg(world).outcomes
    local live = Gambles.live(world)
    local i = 1
    local pick = util.weightedPick(outs, function(d)
        if d.id == "swarm" and not live then return 0 end
        if d.id == "heal" and world.player.hp >= world.player.stats:get("maxHp") then return d.weight * 0.3 end
        return d.weight
    end)
    for k, d in ipairs(outs) do if d == pick then i = k end end
    return i
end

local function finishSpin(world, o)
    local st = o.st
    local out = cfg(world).outcomes[st.land]
    local text = (RESOLVE[out.id] or RESOLVE.wilt)(world, o)
    local bad = out.id == "wilt" or out.id == "swarm" or out.id == "curse"
    world:floatText(o.x, o.y - 22, out.label:upper() .. ": " .. text, bad and { 0.9, 0.55, 0.6 } or colorOf(out), true)
    Audio.play(bad and "hurt" or "pickup", { pitch = bad and 0.7 or 1.3 })
    if out.id == "jackpot" then Audio.play("wave_clear", { pitch = 1.3 }) end
    world.particles:burst(o.x, o.y - 6, bad and 10 or 22, { colorOf(out), { 1, 1, 1 } }, 100, 90, { grav = 160 })
    world.events:emit("flower_spun", out.id)
    st.spinning, st.say = false, 1.2
    st.lastOut = out
    if st.spins >= cfg(world).spins then leave(world, o) else o.busy = false end
end

return {
    name = "Gamble Flower",
    description = "Pay nectar to spin it: items, blessings, nectar... or ants and curses.",
    radius = 9,
    labelZ = 40,
    gamble = { weight = 11, minWave = 2, allowed = hasNectar, text = "Walk in with nectar to spin it. Most petals are good. Some are not.", color = { 1, 0.75, 0.9 } },
    leave = leave,
    init = function(world, o)
        local st = o.st
        st.spins, st.fade, st.pop, st.say, st.lit = 0, 1, 0, 0, 1
    end,
    update = function(world, o, dt)
        local st, p = o.st, world.player
        st.pop = math.min(1, st.pop + dt * 3)
        st.say = math.max(0, st.say - dt)
        if o.leaving then
            st.fade = st.fade - dt
            if st.fade <= 0 then o.dead = true end
            return
        end
        local n = #cfg(world).outcomes
        if st.spinning then
            -- the light runs round, slowing down, and stops on the petal it landed on
            st.spinT = st.spinT + dt
            local k = math.min(1, st.spinT / st.spinLen)
            local steps = math.floor(st.steps * (1 - (1 - k) ^ 2.2))
            local lit = (st.from + steps - 1) % n + 1
            if lit ~= st.lit then
                st.lit = lit
                Audio.play("hit", { pitch = 1.6 + k * 0.4 })
            end
            if k >= 1 then finishSpin(world, o) end
            return
        end
        if p.dead or st.say > 0 or not hasNectar(world) then return end
        if (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 < (p.radius + o.r + 4) ^ 2 then
            local cost = price(world, o)
            if world:spendNectar(cost) then
                st.spins, st.paid = st.spins + 1, cost
                st.land = roll(world, o)
                st.from = st.lit
                -- two to three turns round, ending on the petal
                st.steps = n * (2 + love.math.random(0, 1)) + ((st.land - st.from) % n)
                st.spinT, st.spinLen, st.spinning = 0, 1.6, true
                o.busy = true
                Audio.play("chime", { pitch = 1.1 })
                world.events:emit("flower_paid", cost)
            else
                world:floatText(o.x, o.y - 14, ("%d more nectar"):format(cost - balance(world)), { 1, 0.75, 0.6 })
                st.say = 1.4
            end
        end
    end,
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local a = o.st.fade * o.st.pop
        lg.setColor(0, 0, 0, 0.3 * a)
        lg.ellipse("fill", sx, sy + 1, 10, 4)
        Paint.draw(PA.flowerStem(), sx, sy, 0, 1, 1, a)
    end,
    drawAir = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local a = st.fade * st.pop
        local outs = cfg(world).outcomes
        local n = #outs
        local cx, cy = sx + 1, sy - 22
        local wilt = o.leaving and 4 or 0
        for i, out in ipairs(outs) do
            local ang = (i - 1) / n * math.pi * 2 - math.pi / 2
            local c = colorOf(out)
            local lit = i == st.lit
            local r = lit and 6.5 or 5
            local px, py = cx + math.cos(ang) * 8, cy + math.sin(ang) * 4.5 + wilt
            -- painted petals (src/gfx/propart.lua), the lit one bigger with a pale rim
            Paint.draw(PA.petal(c, lit), math.floor(px + 0.5), math.floor(py + 0.5), 0, 1, 1, a)
        end
        Paint.draw(PA.flowerHeart(), math.floor(cx + 0.5), math.floor(cy + 0.5), 0, 1, 1, a)
    end,
    label = function(world, o)
        local st = o.st
        if o.leaving then return nil end
        if st.spinning then return "...", { 1, 0.9, 0.95 } end
        local cost, have = price(world, o), balance(world)
        local left = cfg(world).spins - st.spins
        if have >= cost then return ("Spin: %d nectar (%d left)"):format(cost, left), { 1, 0.85, 0.95 } end
        return ("Gamble Flower: %d / %d nectar"):format(have, cost), { 0.9, 0.75, 0.8 }
    end,
}
