-- The aphid matriarch (the "aphid_matriarch" event): a round green aphid ambling near you. Walk
-- into her to open the cloning screen (src/states/duplicate.lua, via world.pendingDuplicate).
-- Backing out is fine, she waits; after one clone (cfg.duplicator.uses) she leaves.
local Config = require("src.config.molting")

return {
    name = "Aphid Matriarch",
    radius = 9,
    labelZ = 26,
    init = function(world, o)
        o.uses, o.anim, o.face, o.cool = 0, 0, 0, 0
    end,
    update = function(world, o, dt)
        local p = world.player
        o.cool = math.max(0, o.cool - dt)
        local tx, ty
        if o.leaving then
            tx, ty = o.exitX, o.exitY
        else
            local a = o.t * 0.2 + o.uid
            tx, ty = p.x + math.cos(a) * 70, p.y + math.sin(a) * 70
        end
        local dx, dy = tx - o.x, ty - o.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local s = (o.leaving and 70 or 36) * math.min(1, d / 20)
        o.x, o.y = o.x + dx / d * s * dt, o.y + dy / d * s * dt
        if d > 2 then o.face = math.atan2((dx + dy) * 0.5, dx - dy) end
        o.anim = o.anim + dt * 5 * math.min(1, s / 30)
        if o.leaving then
            if d < 6 then o.dead = true end
            return
        end
        if o.cool <= 0 and not p.dead and (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 < (p.radius + o.r + 4) ^ 2 then
            o.cool = 2
            if require("src.game.duplicate").anyPair(p.inventory) then
                world.pendingDuplicate = o
            else
                world:floatText(o.x, o.y - 14, "Needs two items of one rarity", { 0.8, 1, 0.7 })
            end
        end
    end,
    -- one clone done
    used = function(world, o)
        o.uses = o.uses + 1
        if o.uses >= Config.duplicator.uses then o.def.leave(world, o) end
    end,
    leave = function(world, o)
        if o.leaving then return end
        o.leaving = true
        local S = world.size
        local opts = { { 0, o.y }, { S, o.y }, { o.x, 0 }, { o.x, S } }
        table.sort(opts, function(a, b) return (a[1] - o.x) ^ 2 + (a[2] - o.y) ^ 2 < (b[1] - o.x) ^ 2 + (b[2] - o.y) ^ 2 end)
        o.exitX, o.exitY = math.max(4, math.min(S - 4, opts[1][1])), math.max(4, math.min(S - 4, opts[1][2]))
    end,
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local bob = math.floor(o.anim) % 2
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx, sy + 2, 13, 6)
        lg.setColor(0.2, 0.35, 0.12, 1)
        for i = -1, 1 do
            local k = ((math.floor(o.anim) + i) % 2) * 2 - 1
            lg.line(sx + i * 5, sy - 2, sx + i * 6 - 3, sy + 2 + k)
            lg.line(sx + i * 5, sy - 2, sx + i * 6 + 3, sy + 2 - k)
        end
        -- a plump, pear-shaped green body with a soft shine and two cornicles
        local fx, fy = math.cos(o.face), math.sin(o.face) * 0.5
        lg.setColor(0.32, 0.62, 0.22, 1)
        lg.ellipse("fill", sx - fx * 2, sy - 7 - bob, 11, 8)
        lg.setColor(0.5, 0.82, 0.35, 1)
        lg.ellipse("fill", sx - fx * 2 - 2, sy - 9 - bob, 7, 4)
        lg.setColor(0.85, 1, 0.75, 0.8)
        lg.ellipse("fill", sx - fx * 2 - 4, sy - 11 - bob, 2.5, 1.3)
        lg.setColor(0.2, 0.4, 0.12, 1)
        lg.line(sx - fx * 9 - 2, sy - 9 - bob, sx - fx * 12 - 3, sy - 13 - bob)
        lg.line(sx - fx * 9 + 2, sy - 9 - bob, sx - fx * 12 + 3, sy - 13 - bob)
        lg.setColor(0.28, 0.52, 0.18, 1)
        lg.circle("fill", sx + fx * 9, sy - 6 - bob + fy, 4)
        lg.setColor(0.6, 0.1, 0.1, 1)
        lg.circle("fill", sx + fx * 10, sy - 7 - bob + fy, 1.2)
        -- a tiny clone peeking out behind her
        if not o.leaving then
            local k = 0.5 + 0.5 * math.sin(world.time * 2 + o.uid)
            lg.setColor(0.45, 0.75, 0.3, 0.6 + 0.4 * k)
            lg.ellipse("fill", sx - fx * 12, sy - 3, 3.5, 2.5)
        end
    end,
    label = function(world, o)
        if o.leaving then return nil end
        return "CLONES ITEMS: walk into her", { 0.7, 1, 0.6 }
    end,
}
