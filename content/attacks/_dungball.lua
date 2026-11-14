-- (Helper module, not an attack: the leading _ keeps the registry from loading it.)
-- The dung ball (dung beetle). Shared by the beetle's attack (dungbash) and special (dungthrow):
-- the beetle always has a ball in front of it that grows as it rolls it around and as it
-- picks up the remains of the ants it squashes with it. player.dung = { r, push, spin, thrown }.
-- A big ball is heavy: the beetle walks slower and bashes slower the bigger it gets, and a big
-- throw takes longer to recover from. With a big enough ball the beetle can climb on and ride it
-- (content/dashes/dungride.lua: d.ride puts the ball under the beetle).
local Combat = require("src.game.combat")
local Iso = require("src.core.iso")
local Sprites = require("src.gfx.sprites")
local util = require("src.core.util")

local Dung = {}
Dung.MIN, Dung.MAX = 4, 20

function Dung.get(player, params)
    local d = player.dung
    if not d then
        d = { r = (params and params.minSize) or Dung.MIN, push = 0, spin = 0, thrown = {}, lx = player.x, ly = player.y }
        player.dung = d
    end
    return d
end

-- How heavy the ball is, 0 (fresh) .. 1 (as big as balls get).
function Dung.weight(d)
    return math.max(0, math.min(1, (d.r - Dung.MIN) / (Dung.MAX - Dung.MIN)))
end

-- Ball centre in the world (it sits just in front of the head; a bash shoves it out).
function Dung.pos(player, d)
    if d.ride then return player.x, player.y end
    local fx, fy = math.cos(player.wangle), math.sin(player.wangle)
    local out = player.radius + d.r + 1 + math.sin(math.min(1, d.push) * math.pi) * 16
    return player.x + fx * out, player.y + fy * out
end

function Dung.grow(player, d, amount, params)
    local maxR = (params and params.maxSize or Dung.MAX) * (1 + player.stats:get("area") / 200)
    d.r = math.min(maxR, d.r + amount)
end

-- Every frame (from dungthrow.update): rolling grows it, the ball shoves ants out of its way,
-- and thrown balls roll on.
function Dung.update(player, world, dt, params)
    local d = Dung.get(player, params)
    local moved = math.sqrt((player.x - d.lx) ^ 2 + (player.y - d.ly) ^ 2)
    d.lx, d.ly = player.x, player.y
    if moved > 0 and moved < 40 then
        Dung.grow(player, d, moved * (params.grow or 0.008), params)
        d.spin = d.spin + moved / d.r
    end
    d.push = d.push > 0 and d.push + dt / 0.25 or 0
    if d.push >= 1 then d.push = 0 end
    -- the weight of it: slower walking (not while riding on top), and the recovery the last
    -- bash or throw asked for
    player.moveMul = not d.ride and 1 - Dung.weight(d) * (params.slowMax or 0.45) or nil
    if d.bashSlow then
        player.attack.timer = player.attack.timer + d.bashSlow
        d.bashSlow = nil
    end
    if d.throwSlow and player.secondary then
        player.secondary.timer = player.secondary.timer + d.throwSlow
        d.throwSlow = nil
    end
    -- the ball is solid: ants in the way get rolled aside
    local bx, by = Dung.pos(player, d)
    for _, e in ipairs(Combat.collect(world, bx, by, d.r)) do
        if not e.held and e.z < 4 then
            local nx, ny, l = util.normalize(e.x - bx, e.y - by)
            local push = d.r + e.radius - l
            if push > 0 then e.x, e.y = e.x + nx * push * 0.5, e.y + ny * push * 0.5 end
        end
    end
    -- thrown balls roll on, bowling ants over, and slow down
    for i = #d.thrown, 1, -1 do
        local b = d.thrown[i]
        b.t = b.t + dt
        local sp = math.sqrt(b.vx * b.vx + b.vy * b.vy)
        b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
        b.spin = b.spin + sp * dt / b.r
        local drag = 1 - util.damp(b.drag, dt)
        b.vx, b.vy = b.vx * drag, b.vy * drag
        local S = world.size
        if b.x < b.r or b.y < b.r or b.x > S - b.r or b.y > S - b.r then b.vx, b.vy, sp = 0, 0, 0 end
        for _, e in ipairs(Combat.collect(world, b.x, b.y, b.r)) do
            if not b.hit[e] then
                b.hit[e] = true
                local nx, ny = util.normalize(e.x - b.x, e.y - b.y)
                Combat.damage(world, e, b.damage * math.min(1, 0.4 + sp / 300), { knockback = b.knockback, kbx = nx * 0.6 + b.vx / (sp + 1), kby = ny * 0.6 + b.vy / (sp + 1) })
                -- each ant flattened slows it a little
                b.vx, b.vy = b.vx * b.toll, b.vy * b.toll
            end
        end
        if world.time % 0.04 < dt and sp > 40 then
            world.particles:spawn(b.x, b.y, 1, -b.vx * 0.1, -b.vy * 0.1, 10, 0.4, { 0.42, 0.3, 0.18 }, 1, { grav = 80 })
        end
        if sp < 25 or b.t > 3 then
            table.remove(d.thrown, i)
            if b.r >= (params.burstSize or 9) then
                Combat.explode(world, b.x, b.y, b.r * 3, b.damage * 0.8, { knockback = 200, color = { 0.75, 0.55, 0.3 } })
            end
            world.particles:burst(b.x, b.y, math.floor(6 + b.r), { { 0.36, 0.24, 0.12 }, { 0.5, 0.36, 0.2 }, { 0.75, 0.62, 0.35 } }, 70 + b.r * 6, 50, { stain = true, grav = 300 })
            world.pendingSplats[#world.pendingSplats + 1] = { kind = "splat", b.x, b.y, { 0.3, 0.2, 0.1 }, math.floor(2 + b.r * 0.5), 0, 0 }
        end
    end
end

local function drawBall(x, y, r, spin)
    local sx, sy = Iso.toScreen(x, y)
    local spr = Sprites.get("dung_ball")
    local s = r / 7
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.ellipse("fill", sx, sy + 1, r * 0.9, r * 0.45)
    love.graphics.setColor(1, 1, 1, 1)
    Sprites.draw(spr, 1, sx, sy - r * 0.7, spin, false, s)
end

function Dung.draw(player, world)
    local d = player.dung
    if not d or player.dead then return end
    for _, b in ipairs(d.thrown) do drawBall(b.x, b.y, b.r, b.spin) end
    local bx, by = Dung.pos(player, d)
    drawBall(bx, by, d.r, d.spin)
end

return Dung
