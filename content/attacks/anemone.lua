-- Sea Anemone (hermit crab): real hermit crabs plant stinging anemones on their shells for
-- protection. This one sets an anemone down where you point; it sways there for a while,
-- lashing every ant that comes within reach of its tentacles with paralysing stings
-- (damage and a heavy slow). Up to `max` at once; the oldest withers when you plant another.
-- (zone fields are named sting / stingSlow: a zone's damage and slow would hit the player)
-- Two can be planted back to back: the special holds `max` charges, each refilling on its own
-- cooldown (the special's bar shows the refill while none are left).
-- params: damage (per sting), cooldown (per charge), range (110), radius (tentacle reach, 26),
--         life (7 s), rate (stings per second per ant, 2.5), slow ({ mul, time }), max (2)
local Combat = require("src.game.combat")
local Iso = require("src.core.iso")
local Audio = require("src.core.audio")

local function draw(z, sx, sy, fade)
    local lg = love.graphics
    local grow = math.min(1, z.t / 0.4)
    local r = z.r * grow
    local t = z.t
    -- tentacles: a ring of swaying arms with glowing tips
    for i = 0, 13 do
        local a = i / 14 * math.pi * 2 + math.sin(t * 2 + i) * 0.15
        local reach = r * (0.45 + 0.15 * math.sin(t * 3 + i * 1.7)) + (z.lash or 0) * 6
        local bx, by = Iso.toScreen(z.x + math.cos(a) * 3, z.y + math.sin(a) * 3, 3)
        local mx, my = Iso.toScreen(z.x + math.cos(a + 0.3) * reach * 0.6, z.y + math.sin(a + 0.3) * reach * 0.6, 4)
        local ex, ey = Iso.toScreen(z.x + math.cos(a) * reach, z.y + math.sin(a) * reach, 2)
        lg.setColor(0.95, 0.45, 0.6, 0.9 * fade)
        lg.line(bx, by, mx, my, ex, ey)
        lg.setColor(1, 0.85, 0.95, fade)
        lg.rectangle("fill", math.floor(ex), math.floor(ey), 1, 1)
    end
    -- the column
    lg.setColor(0.55, 0.15, 0.3, fade)
    lg.ellipse("fill", sx, sy - 1, 4, 2.5)
    lg.setColor(0.85, 0.35, 0.5, fade)
    lg.ellipse("fill", sx, sy - 3, 3, 1.8)
    -- reach on the ground
    lg.setColor(0.95, 0.5, 0.7, 0.12 * fade)
    local pts = {}
    for i = 0, 20 do
        local a = i / 20 * math.pi * 2
        local px, py = Iso.toScreen(z.x + math.cos(a) * r, z.y + math.sin(a) * r)
        pts[#pts + 1], pts[#pts + 2] = px, py
    end
    lg.line(pts)
end

local function update(world, z, dt)
    z.lash = math.max(0, (z.lash or 0) - dt * 4)
    z.tick = (z.tick or 0) - dt
    if z.tick > 0 then return end
    z.tick = 1 / (z.rate or 2.5)
    local any = false
    for _, e in ipairs(Combat.collect(world, z.x, z.y, z.r)) do
        if e.z < 8 then
            local l = math.sqrt((e.x - z.x) ^ 2 + (e.y - z.y) ^ 2) + 0.001
            Combat.damage(world, e, z.sting, { knockback = 20, kbx = (z.x - e.x) / l, kby = (z.y - e.y) / l, slow = z.stingSlow, procDepth = 1 })
            world:addFx({ kind = "stab", x = z.x, y = z.y, x2 = e.x, y2 = e.y, z = 3, life = 0.1, w = 1, color = { 1, 0.5, 0.75 } })
            any = true
        end
    end
    if any then
        z.lash = 1
        Audio.play("zap", { pitch = 2.2, volume = 0.35 })
    end
end

return {
    name = "Sea Anemone",
    range = function(params) return params.range or 110 end,
    fire = function(player, world, ax, ay, params, px, py)
        local range = params.range or 110
        local dx, dy = (px or player.x + ax * 60) - player.x, (py or player.y + ay * 60) - player.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > range then dx, dy = dx / d * range, dy / d * range end
        local x, y = player.x + dx, player.y + dy
        -- wither the oldest if there are too many
        local mine = {}
        for _, z in ipairs(world.hazards.zones) do if z.anemone then mine[#mine + 1] = z end end
        for i = 1, #mine - (params.max or 2) + 1 do mine[i].t = math.max(mine[i].t, mine[i].maxLife - 0.4) end
        world.hazards:addZone({ anemone = true, x = x, y = y, r = (params.radius or 26) * (1 + player.stats:get("area") / 100),
            life = params.life or 7, sting = params.damage, rate = params.rate or 2.5, stingSlow = params.slow or { 0.35, 0.8 },
            color = { 0.9, 0.4, 0.6 }, update = update, draw = draw })
        world.particles:burst(x, y, 8, { { 0.95, 0.5, 0.7 }, { 0.6, 0.85, 1 } }, 60, 40, { glow = true })
        Audio.play("equip", { pitch = 1.3 })
        local c = player.anemone or { n = params.max or 2, t = 0 }
        player.anemone = c
        c.n = c.n - 1
        if c.n < (params.max or 2) - 1 then return end
        c.t = params.cooldown
    end,
    -- charges: one refills per cooldown; while one is in hand the next plant is nearly instant
    update = function(player, world, dt, params)
        local max = params.max or 2
        local c = player.anemone
        if not c then
            c = { n = max, t = 0 }
            player.anemone = c
        end
        c.n = math.min(c.n, max)
        local sec = player.secondary
        if c.n < max then
            c.t = c.t - dt * math.max(0.2, 1 + player.stats:get("attackSpeed") / 100)
            if c.t <= 0 then
                c.n = c.n + 1
                c.t = c.n < max and params.cooldown or 0
            end
        end
        if c.n > 0 then
            sec.timer = math.min(sec.timer, 0.35)
        else
            sec.timer = math.max(sec.timer, c.t)
        end
    end,
}
