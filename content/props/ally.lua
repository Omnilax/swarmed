-- A bug you freed from a cocoon: fights beside you for `life` seconds, then goes its own way.
-- It can't be hurt, and its bites hurt ants without your stats (src/game/envfx.lua).
local Sprites = require("src.gfx.sprites")
local Env = require("src.game.envfx")
local Audio = require("src.core.audio")

return {
    name = "Freed Ally",
    radius = 6,
    init = function(world, o)
        local c = o.char
        o.r = math.max(4, (c.radius or 6) * 0.8)
        o.sprite = Sprites.get(c.sprite)
        o.speed = math.max(90, ((c.stats or {}).moveSpeed or 90) * 1.15)
        o.cd, o.anim, o.face = 0, 0, 0
        o.life = o.life or 20
    end,
    update = function(world, o, dt)
        local p = world.player
        local wave = math.max(1, world.spawner.wave or 1)
        o.cd = math.max(0, o.cd - dt)
        local target = world:nearestEnemy(o.x, o.y, 220)
        if target and target.def.encounter then target = nil end
        local tx, ty
        if target then tx, ty = target.x, target.y
        else
            -- heel: trot after the player
            local a = o.uid * 1.7
            tx, ty = p.x + math.cos(a) * 26, p.y + math.sin(a) * 26
        end
        local dx, dy = tx - o.x, ty - o.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local reach = o.r + (target and target.radius or 0) + 3
        local mv = 0
        if d > reach then
            local s = o.speed * math.min(1, d / 10)
            o.x, o.y = o.x + dx / d * s * dt, o.y + dy / d * s * dt
            mv = s
        end
        if d > 1 then o.face = math.atan2((dx + dy) * 0.5, dx - dy) end
        o.anim = o.anim + dt * (o.sprite.fps or 8) * math.min(1.5, mv / 60)
        local S = world.size
        o.x, o.y = math.max(o.r, math.min(S - o.r, o.x)), math.max(o.r, math.min(S - o.r, o.y))
        if target and d <= reach + 2 and o.cd <= 0 then
            -- a bite that splashes onto the ants around its victim
            o.cd = 0.45
            o.lunge = 0.12
            local dmg = 7 + wave * 0.9
            Env.hurtAnt(world, target, dmg, { force = 90, kx = dx, ky = dy })
            Env.strikeCircle(world, target.x, target.y, 12, dmg * 0.5, { force = 50 })
            world.particles:sparks(target.x, target.y, 3, { 0.7, 1, 0.7 }, dx, dy)
            Audio.play("hit", { pitch = 1.2, volume = 0.6 })
        end
        o.lunge = math.max(0, (o.lunge or 0) - dt)
        if o.t >= o.life - 0.05 then
            world.particles:burst(o.x, o.y, 10, { { 0.7, 1, 0.7 }, { 1, 1, 1 } }, 60, 60, { glow = true })
        end
    end,
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local left = o.life - o.t
        local a = left < 2 and (0.4 + 0.6 * math.abs(math.sin(o.t * 10))) or 1
        -- a green ring marks it as a friend, with its time running down
        lg.setColor(0.4, 1, 0.5, 0.55 * a)
        lg.ellipse("line", sx, sy + 1, o.r * 1.7 + 3, (o.r * 1.7 + 3) * 0.5)
        lg.setColor(0.4, 1, 0.5, 0.9 * a)
        lg.arc("line", "open", sx, sy - o.r * 2.6 - 8, 3, -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.max(0, left / o.life))
        lg.setColor(0, 0, 0, 0.3)
        lg.ellipse("fill", sx, sy + 2, o.r * 1.4, o.r * 0.6)
        lg.setColor(1, 1, 1, a)
        local k = o.lunge > 0 and 1.08 or 1
        Sprites.draw(o.sprite, math.floor(o.anim) + 1, sx, sy - 2, o.face, false, k * 0.9, 0.9 / k)
    end,
}
