-- Acid pool (stink bug): squirts a glob of caustic secretion where you point. It splashes into
-- a sizzling pool that burns any ant standing in it, and the stench is so foul that ants won't
-- walk in: they're turned away at the edge and go around, so a pool walls off a whole lane.
-- The splash also throws up one of the stink bug's clouds over it.
-- params: damage (per second inside), cooldown, range (130), radius (34), life (6 s), max (3)
local Iso = require("src.core.iso")
local Combat = require("src.game.combat")
local Sprites = require("src.gfx.sprites")
local Audio = require("src.core.audio")

local function update(world, z, dt)
    local r = z.r * math.min(1, z.t / 0.3)
    local list, n = world:queryEnemies(z.x, z.y, r + 14)
    z.tick = (z.tick or 0) - dt
    local burn = z.tick <= 0
    if burn then z.tick = 0.25 end
    for k = 1, n do
        local e = list[k]
        if not e.dead and not e.hidden and not e.def.boss and e.z < 6 then
            local dx, dy = e.x - z.x, e.y - z.y
            local d = math.sqrt(dx * dx + dy * dy) + 0.001
            local edge = r + e.radius
            if d < edge + 10 then
                -- repelled: turned around at the edge and shoved back out
                local nx, ny = dx / d, dy / d
                local inward = e.mx * nx + e.my * ny
                if inward < 0 then e.mx, e.my = e.mx - nx * inward * 1.6, e.my - ny * inward * 1.6 end
                if d < edge then e.x, e.y = e.x + nx * math.min(edge - d, 140 * dt), e.y + ny * math.min(edge - d, 140 * dt) end
            end
            if burn and d < edge then
                Combat.damage(world, e, z.burn * 0.25, { knockback = 0, noCrit = true, dot = true, procDepth = 1 })
                world.particles:spawn(e.x, e.y, 2, 0, 0, 20, 0.4, { 0.8, 1, 0.3 }, 1, { glow = true, grav = -30 })
            end
        end
    end
    if love.math.random() < dt * 8 then
        local a, rr = love.math.random() * 6.28, love.math.random() * r
        world.particles:spawn(z.x + math.cos(a) * rr, z.y + math.sin(a) * rr, 1, 0, 0, 25, 0.5, { 0.75, 1, 0.35 }, 1, { glow = true, grav = -20 })
    end
end

local function draw(z, sx, sy, fade)
    local lg = love.graphics
    local grow = math.min(1, z.t / 0.3)
    local k = z.r / 9 * grow
    local blobs = Sprites.blobs
    lg.setColor(0.3, 0.42, 0.08, 0.75 * fade)
    lg.draw(Sprites.atlas, blobs[(z.seed % #blobs) + 1], sx, sy, 0, k * 1.1, k, 9, 5)
    lg.setColor(0.55, 0.75, 0.15, 0.7 * fade)
    lg.draw(Sprites.atlas, blobs[((z.seed + 2) % #blobs) + 1], sx - k, sy - k * 0.4, 0, k * 0.8, k * 0.7, 9, 5)
    -- sizzling bubbles
    for i = 0, 5 do
        local a = z.seed + i * 1.1 + z.t * 0.3
        local rr = z.r * 0.6 * ((i * 0.37 + z.t * 0.5) % 1)
        local bx, by = Iso.toScreen(z.x + math.cos(a) * rr, z.y + math.sin(a) * rr)
        lg.setColor(0.85, 1, 0.45, 0.8 * fade)
        lg.rectangle("fill", math.floor(bx), math.floor(by), 1, 1)
    end
end

return {
    name = "Acid Pool",
    range = function(params) return params.range or 130 end,
    fire = function(player, world, ax, ay, params, px, py)
        local range = params.range or 130
        local dx, dy = (px or player.x + ax * 80) - player.x, (py or player.y + ay * 80) - player.y
        local d = math.sqrt(dx * dx + dy * dy)
        if d > range then dx, dy = dx / d * range, dy / d * range end
        local tx, ty = player.x + dx, player.y + dy
        local area = 1 + player.stats:get("area") / 100
        local mine = {}
        for _, z in ipairs(world.hazards.zones) do if z.acidPool then mine[#mine + 1] = z end end
        for i = 1, #mine - (params.max or 3) + 1 do mine[i].t = math.max(mine[i].t, mine[i].maxLife - 0.4) end
        -- the glob arcs over and splashes down, then the pool spreads
        world.hazards:friendlyShot({ x = player.x, y = player.y, z = 6, vx = dx / 0.3, vy = dy / 0.3, vz = 70, grav = 420, r = 3,
            damage = params.damage, life = 0.3, color = { 0.7, 1, 0.3 }, pierce = 0, knockback = 0,
            onEnd = function(w, s)
                w.hazards:addZone({ acidPool = true, x = tx, y = ty, r = (params.radius or 34) * area, life = params.life or 6,
                    burn = params.damage, seed = love.math.random(1, 50), color = { 0.5, 0.8, 0.15 }, update = update, draw = draw })
                Combat.area(w, tx, ty, (params.radius or 34) * area, params.damage, { knockback = 90 })
                -- the splash throws up a stink cloud over the pool (content/attacks/stinkcloud.lua)
                local atk = player.attack
                if atk and atk.type.cloud then atk.type.cloud(w, player, atk.params, tx, ty, (params.radius or 34) * area * 0.7, 0, 0, 3) end
                w.particles:burst(tx, ty, 10, { { 0.7, 1, 0.3 }, { 0.5, 0.8, 0.15 } }, 90, 40, { glow = true, grav = 260 })
                Audio.play("hit", { pitch = 0.5 })
            end })
        Audio.play("dash", { pitch = 1.6, volume = 0.6 })
    end,
}
