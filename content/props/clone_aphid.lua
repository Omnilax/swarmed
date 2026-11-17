-- The aphid matriarch (the "aphid_matriarch" event): a round green aphid ambling near you. Walk
-- into her to open the cloning screen (src/states/duplicate.lua, via world.pendingDuplicate).
-- Backing out is fine, she waits; after one clone (cfg.duplicator.uses) she leaves.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
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
        -- painted (src/gfx/propart.lua), facing the way she walks
        local flip = math.cos(o.face) < 0 and -1 or 1
        -- a tiny clone peeking out behind her
        if not o.leaving then
            local k = 0.5 + 0.5 * math.sin(world.time * 2 + o.uid)
            Paint.draw(PA.aphid(0), sx - flip * 12, sy, 0, flip * 0.35, 0.35, 0.6 + 0.4 * k)
        end
        Paint.draw(PA.aphid(math.floor(o.anim) % 2), sx, sy - bob, 0, flip, 1)
    end,
    label = function(world, o)
        if o.leaving then return nil end
        return "CLONES ITEMS: walk into her", { 0.7, 1, 0.6 }
    end,
}
