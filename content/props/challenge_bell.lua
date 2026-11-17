-- Challenge bell (a map gamble, src/game/gambles.lua): a bluebell flower hanging off a bent
-- stalk. Hit it (or dash into it) while the wave is on and a pack of tough ants answers from
-- all round, some of them elite. Kill every one of them before the time runs out for XP, a
-- chunk of frenzy and a rarer best card in the next item choice. Too slow, and the pack just
-- stays on as part of the wave.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
local Content = require("src.content")
local Audio = require("src.core.audio")
local Env = require("src.game.envfx")
local Gambles = require("src.game.gambles")

local GOLD = { 1, 0.82, 0.35 }

local function cfg(world) return world.gambles.cfg.bell end

local function leave(world, o)
    if o.leaving then return end
    o.leaving, o.busy, o.st.fade = true, false, 0.8
end

-- the pack ants still standing
local function left(o)
    local n = 0
    for _, m in ipairs(o.st.pack) do
        if not m.e.dead and m.e.uid == m.uid then n = n + 1 end
    end
    return n
end

local function ring(world, o)
    local st, c, sp = o.st, cfg(world), world.spawner
    local wave = math.max(1, sp.wave or 1)
    st.state, st.pack, o.busy = "on", {}, true
    st.swing = 1
    local n = math.floor(c.pack + wave * c.packPerWave)
    local elites = math.min(n, math.floor(c.elites + wave * c.elitesPerWave))
    for i = 1, n do
        local def = sp:pickEnemy()
        if def then
            local a = (i / n) * math.pi * 2 + love.math.random() * 0.3
            local r = c.radius + love.math.random() * 30
            local elite
            if i <= elites then
                elite = Content.elites:pickWeighted(function(d) return d.weight end, function(d) return d.minWave <= wave end)
            end
            local e = world:spawnEnemy(def, o.x + math.cos(a) * r, o.y + math.sin(a) * r, elite)
            if e then
                e.maxHp = math.max(1, math.floor(e.maxHp * c.hpMul + 0.5))
                e.hp = e.maxHp
                e.challenge = o.uid
                st.pack[#st.pack + 1] = { e = e, uid = e.uid }
            end
        end
    end
    st.total = #st.pack
    st.timeLeft = c.time + st.total * c.timePerAnt
    st.timeMax = st.timeLeft
    Audio.play("bell")
    world.camera:shake(0.2)
    world.director:announce("The Bell Tolls", ("Kill the pack of %d in %d seconds for a prize."):format(st.total, math.floor(st.timeLeft)), GOLD)
    world.events:emit("bell_rung", o, st.total)
end

local function win(world, o)
    local st, c = o.st, cfg(world).reward
    local wave = math.max(1, world.spawner.wave or 1)
    local r = { xp = math.floor(c.xp + wave * c.xpPerWave), frenzy = c.frenzy, minRarity = c.minRarity }
    if wave >= c.legendaryFrom then r.minRarity = "legendary" elseif wave >= c.rareFrom then r.minRarity = "rare" end
    world.rewards:pay(r, o.x, o.y)
    st.state, st.won = "done", true
    local R = require("src.config.rarities")
    world:floatText(o.x, o.y - 20, "CHALLENGE WON", GOLD, true)
    world.milestone = { text = "CHALLENGE WON: next pick " .. R[r.minRarity].label:upper() .. "+", t = 0 }
    Audio.play("bell", { pitch = 1.25 })
    Audio.play("wave_clear", { pitch = 1.2 })
    world.particles:burst(o.x, o.y, 26, { GOLD, { 1, 1, 0.8 } }, 130, 100, { grav = 160 })
    world.events:emit("bell_won", o)
    leave(world, o)
end

local function lose(world, o)
    local st = o.st
    st.state, st.won = "done", false
    for _, m in ipairs(st.pack) do if m.e.uid == m.uid then m.e.challenge = nil end end
    world:floatText(o.x, o.y - 20, "TOO SLOW", { 0.85, 0.6, 0.5 }, true)
    Audio.play("bell", { pitch = 0.6 })
    world.events:emit("bell_lost", o)
    leave(world, o)
end

return {
    name = "Challenge Bell",
    description = "Ring it to call a tough pack. Kill them all in time for a prize.",
    radius = 8,
    labelZ = 40,
    dashHit = 1,
    gamble = { weight = 10, minWave = 3, text = "Hit it to call a tough pack. Beat them in time for a prize.", color = GOLD },
    leave = leave,
    init = function(world, o)
        o.st.state, o.st.fade, o.st.swing, o.st.pack, o.st.pop = "idle", 1, 0, {}, 0
    end,
    onHit = function(world, o)
        local st = o.st
        if o.leaving or st.state ~= "idle" then return end
        if not Gambles.live(world) then
            if (st.say or 0) <= 0 then
                world:floatText(o.x, o.y - 14, "Only rings while the colony is out", { 0.85, 0.8, 0.7 })
                st.say = 1
            end
            st.swing = 0.4
            return
        end
        ring(world, o)
    end,
    update = function(world, o, dt)
        local st = o.st
        st.pop = math.min(1, st.pop + dt * 3)
        st.say = math.max(0, (st.say or 0) - dt)
        st.swing = math.max(0, st.swing - dt * 0.6)
        if o.leaving then
            st.fade = st.fade - dt
            if st.fade <= 0 then o.dead = true end
            return
        end
        if st.state == "on" then
            st.timeLeft = st.timeLeft - dt
            if left(o) == 0 then win(world, o)
            elseif st.timeLeft <= 0 then lose(world, o) end
        end
    end,
    draw = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local a = st.fade * st.pop
        -- a gold ring under each ant of the pack still standing
        if st.state == "on" then
            lg.setColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
            for _, m in ipairs(st.pack) do
                local e = m.e
                if not e.dead and e.uid == m.uid then Env.ellipse("line", e.x, e.y, (e.radius or 5) + 3) end
            end
        end
        lg.setColor(0, 0, 0, 0.3 * a)
        lg.ellipse("fill", sx, sy + 1, 9, 4)
        -- the stalk, bending over (painted: src/gfx/propart.lua)
        Paint.draw(PA.bellStalk(), sx, sy, 0, 1, 1, a)
    end,
    drawAir = function(world, o, sx, sy)
        local lg, st = love.graphics, o.st
        local a = st.fade * st.pop
        local sw = math.sin(o.t * 14) * st.swing * 0.6 + math.sin(o.t * 1.5) * 0.08
        -- the bell flower, swinging from the stalk's tip
        local done = st.state == "done"
        sw = math.floor(sw / 0.08 + 0.5) * 0.08          -- a few steps, so the pixels stay crisp
        Paint.draw(PA.bell(done), sx + 6, sy - 28, sw, 1, 1, a)
        lg.push()
        lg.translate(sx + 6, sy - 28)
        lg.rotate(sw)
        -- the clapper
        lg.setColor(GOLD[1], GOLD[2], GOLD[3], a)
        lg.circle("fill", math.sin(o.t * 9) * st.swing * 2, 12, 1.6)
        lg.pop()
        -- the time left, as a shrinking gold arc
        if st.state == "on" then
            local k = math.max(0, st.timeLeft / st.timeMax)
            lg.setColor(0.1, 0.08, 0.05, 0.7)
            lg.setLineWidth(3)
            lg.arc("line", "open", sx + 6, sy - 22, 12, -math.pi / 2, math.pi * 1.5)
            lg.setColor(k < 0.25 and 1 or GOLD[1], k < 0.25 and 0.4 or GOLD[2], GOLD[3] * 0.6, 1)
            lg.arc("line", "open", sx + 6, sy - 22, 12, -math.pi / 2, -math.pi / 2 + k * math.pi * 2)
            lg.setLineWidth(1)
        end
    end,
    label = function(world, o)
        local st = o.st
        if o.leaving then return nil end
        if st.state == "idle" then
            if not Gambles.live(world) then return "Challenge Bell (rings during a wave)", { 0.8, 0.78, 0.7 } end
            return "Challenge Bell: hit to ring", GOLD
        end
        if st.state == "on" then
            return ("%d / %d left  %ds"):format(left(o), st.total, math.ceil(st.timeLeft)), st.timeLeft < 6 and { 1, 0.5, 0.4 } or GOLD
        end
    end,
}
