-- Stink cloud (stink bug): sprays a jet of foul defensive chemicals ahead that hangs as a thick
-- yellow-green cloud, drifting slowly on. Every ant inside chokes: poisoned, slowed, and it takes
-- extra damage from everything (the stink bug's whole kit feeds on this: the acid pool and the
-- shield blast both leave clouds too). Clouds overlap into a fog bank.
-- params: damage (poison per second), cooldown, range (where the puff lands, 34), radius (20),
--         life (2.6 s), drift (speed, 14), max (clouds kept, 6), weaken (damage taken x inside, 1.25),
--         choke (move speed x inside, 0.7)
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")
local Audio = require("src.core.audio")
local Combat = require("src.game.combat")

local function update(world, z, dt)
    z.x, z.y = z.x + z.vx * dt, z.y + z.vy * dt
    z.tick = (z.tick or 0) - dt
    if z.tick > 0 then return end
    z.tick = 0.3
    local list, n = world:queryEnemies(z.x, z.y, z.r)
    for k = 1, n do
        local e = list[k]
        local dx, dy = e.x - z.x, e.y - z.y
        if not e.dead and not e.hidden and dx * dx + dy * dy < (z.r + e.radius) ^ 2 then
            -- poison that keeps ticking after they stagger out
            e.poisonT = math.max(e.poisonT, 1.5)
            e.poisonDps = math.max(e.poisonDps, z.dps)
            -- choking: slowed, and every hit lands harder
            if e.corrodeT <= 0 then e.corrodeMul = 1 end
            e.corrodeMul, e.corrodeT = math.max(e.corrodeMul, z.weaken), math.max(e.corrodeT, 0.5)
            if e.slowT <= 0 then e.slowMul = 1 end
            e.slowMul, e.slowT = math.min(e.slowMul, z.choke), math.max(e.slowT, 0.5)
            if love.math.random() < 0.3 then
                world.particles:spawn(e.x, e.y, 6, 0, 0, 20, 0.5, { 0.7, 0.85, 0.2 }, 1, { glow = true, grav = -10 })
            end
        end
    end
end

local function draw(z, sx, sy, fade)
    local lg = love.graphics
    local grow = math.min(1, z.t / 0.25)
    local glow = Sprites.glow
    -- a thick, lumpy cloud: dark olive underneath, sickly yellow-green puffs on top
    for i = 0, 5 do
        local a = z.seed + i * 1.05 + z.t * 0.6
        local ox, oy = math.cos(a) * z.r * 0.5 * grow, math.sin(a) * z.r * 0.28 * grow
        local k = z.r / 7 * grow * (0.75 + 0.15 * math.sin(z.t * 2 + i))
        lg.setColor(0.32, 0.36, 0.08, 0.5 * fade)
        lg.draw(Sprites.atlas, glow, sx + ox, sy + oy - 2, 0, k, k * 0.6, 8, 8)
        lg.setColor(0.7, 0.78, 0.2, 0.42 * fade)
        lg.draw(Sprites.atlas, glow, sx + ox * 0.8, sy + oy * 0.8 - 5, 0, k * 0.7, k * 0.45, 8, 8)
    end
    lg.setColor(0.85, 0.9, 0.35, 0.28 * fade)
    lg.draw(Sprites.atlas, glow, sx, sy - 6, 0, z.r / 10 * grow, z.r / 16 * grow, 8, 8)
    -- cartoon stink lines wafting up out of it
    lg.setLineWidth(1)
    for i = 0, 2 do
        local ph = (z.t * 0.8 + i / 3 + z.seed) % 1
        local bx = sx + (i - 1) * z.r * 0.45
        local by = sy - 6 - ph * 12
        local pts = {}
        for j = 0, 4 do
            pts[#pts + 1] = bx + math.sin(j * 1.6 + z.t * 6 + i) * 1.5
            pts[#pts + 1] = by - j * 1.5
        end
        lg.setColor(0.8, 0.9, 0.3, 0.75 * fade * math.sin(ph * math.pi) * grow)
        lg.line(pts)
    end
end

-- Leave a cloud (also used by the acid pool and the stink shield).
local function cloud(world, player, params, x, y, r, vx, vy, life)
    world.hazards:addZone({ stink = true, x = x, y = y, r = r, life = life or params.life or 2.6,
        dps = (params.damage or 5) * (1 + player.stats:get("damage") / 100), vx = vx or 0, vy = vy or 0,
        weaken = params.weaken or 1.25, choke = params.choke or 0.7,
        seed = love.math.random() * 6, color = { 0.6, 0.7, 0.2 }, update = update, draw = draw })
end

return {
    name = "Stink Cloud",
    range = function(params, player) return ((params.range or 34) + (params.radius or 20)) * (1 + player.stats:get("area") / 100) end,
    fire = function(player, world, ax, ay, params)
        local area = 1 + player.stats:get("area") / 100
        local off = (params.range or 34) * area
        local mine = {}
        for _, z in ipairs(world.hazards.zones) do if z.stink then mine[#mine + 1] = z end end
        for i = 1, #mine - (params.max or 6) + 1 do mine[i].t = math.max(mine[i].t, mine[i].maxLife - 0.3) end
        local drift = params.drift or 14
        local tx, ty = player.x + ax * off, player.y + ay * off
        cloud(world, player, params, tx, ty, (params.radius or 20) * area, ax * drift, ay * drift)
        -- the spray: a visible jet from the glands out to where the cloud blooms, and the puff stings
        world:addFx({ kind = "streak", x = player.x, y = player.y, x2 = tx, y2 = ty, life = 0.18, w = 3, color = { 0.8, 0.9, 0.3 } })
        for i = 1, 10 do
            local k = i / 10
            world.particles:spawn(player.x + ax * off * k * 0.5, player.y + ay * off * k * 0.5, 3,
                ax * (120 + love.math.random() * 80) + (love.math.random() - 0.5) * 40, ay * (120 + love.math.random() * 80) + (love.math.random() - 0.5) * 40,
                10, 0.35, i % 2 == 0 and { 0.85, 0.95, 0.35 } or { 0.55, 0.62, 0.18 }, 2, { glow = i % 2 == 0, grav = -10 })
        end
        Combat.area(world, tx, ty, (params.radius or 20) * area, params.damage * 1.5, { knockback = 30 })
        world.particles:burst(tx, ty, 8, { { 0.8, 0.9, 0.3 }, { 0.5, 0.55, 0.2 } }, 50, 20, { grav = -20 })
        Audio.play("dash", { pitch = 0.5, volume = 0.5 })
    end,
    cloud = cloud,
}
