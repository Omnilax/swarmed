-- Silk wall (orb weaver): press right click to tie a strand where you point, hold and drag to
-- stretch it out, let go to fix it in place. Ants that walk into it get stuck fast and pile up
-- behind it like a wall, until it has caught too many or wears out. Up to `max` walls at once.
-- params: cooldown, range (how far from you a strand can start, 120), length (max, 130),
--         duration (8), strength (catches before it snaps, 40), hold (seconds an ant is stuck, 2.5),
--         damage (per catch), max (walls at once, 3)
local Audio = require("src.core.audio")

local function clampTo(x, y, cx, cy, maxD)
    local dx, dy = x - cx, y - cy
    local d = math.sqrt(dx * dx + dy * dy)
    if d > maxD then return cx + dx / d * maxD, cy + dy / d * maxD end
    return x, y
end

return {
    name = "Silk Wall",
    range = function(params) return params.range or 120 end,
    -- right click pressed: tie the first end
    fire = function(player, world, ax, ay, params, px, py)
        local x, y = clampTo(px or player.x + ax * 40, py or player.y + ay * 40, player.x, player.y, params.range or 120)
        player.weave = { x1 = x, y1 = y, x2 = x, y2 = y, t = 0 }
        world.particles:burst(x, y, 4, { { 1, 1, 0.95 } }, 30, 10)
        Audio.play("dash", { pitch = 2.4 })
    end,
    -- while held: the strand follows the pointer; on release it is fixed (a short tap makes a
    -- wall across your aim instead)
    update = function(player, world, dt, params, down, px, py)
        local w = player.weave
        if not w then return end
        w.t = w.t + dt
        local len = params.length or 130
        w.x2, w.y2 = clampTo(px, py, w.x1, w.y1, len)
        if down and w.t < 3 then return end
        local dx, dy = w.x2 - w.x1, w.y2 - w.y1
        if dx * dx + dy * dy < 20 * 20 then
            -- quick tap: a wall across the line between you and the knot
            local ax, ay = w.x1 - player.x, w.y1 - player.y
            local l = math.sqrt(ax * ax + ay * ay) + 0.001
            local sx, sy = -ay / l, ax / l
            local half = len * 0.35
            w.x1, w.y1, w.x2, w.y2 = w.x1 - sx * half, w.y1 - sy * half, w.x1 + sx * half, w.y1 + sy * half
        end
        world.hazards:addWall({ x1 = w.x1, y1 = w.y1, x2 = w.x2, y2 = w.y2, life = params.duration or 8,
            strength = params.strength or 40, hold = params.hold or 2.5, damage = params.damage or 2, max = params.max or 3 })
        player.weave = nil
        Audio.play("hit", { pitch = 2.4 })
    end,
    -- the strand being spun, from the knot to the pointer
    draw = function(player, world, params)
        local w = player.weave
        if not w then return end
        local Hazards = require("src.game.hazards")
        Hazards.drawStrand(w.x1, w.y1, w.x2, w.y2, 0.6 + 0.3 * math.sin(w.t * 20), 0.5, w.t)
        local Iso = require("src.core.iso")
        local x1, y1 = Iso.toScreen(player.x, player.y, 4)
        local x2, y2 = Iso.toScreen(w.x2, w.y2, 3)
        love.graphics.setColor(1, 1, 0.95, 0.35)
        love.graphics.line(x1, y1, x2, y2)
    end,
}
