-- A brood cell chest: a capped wax cell with something wriggling inside. A slain queen drops one,
-- so does a caught treasure ant (World:dropChest). Walk into it to crack it open: a fanfare rolls
-- 1, 3 or 5 level-up cards (src/states/broodcell.lua, odds in src/config/molting.lua). One still
-- shut when the wave ends opens by itself, so it never holds anything up.
local Audio = require("src.core.audio")

local function hexPts(cx, cy, r, sq)
    local pts = {}
    for i = 0, 5 do
        local a = i / 6 * math.pi * 2 + math.pi / 6
        pts[#pts + 1] = cx + math.cos(a) * r
        pts[#pts + 1] = cy + math.sin(a) * r * sq
    end
    return pts
end

return {
    name = "Brood Cell",
    radius = 8,
    labelZ = 26,
    init = function(world, o)
        o.kind = o.kind or "queen"
        o.z, o.vz = 2, 90      -- tossed up as it drops
        o.wob = 0
        world.particles:burst(o.x, o.y, 14, { { 1, 0.85, 0.4 }, { 1, 1, 0.8 } }, 90, 60, { glow = true, grav = 120 })
        Audio.play("pickup", { pitch = 0.7 })
    end,
    update = function(world, o, dt)
        if o.z > 0 or o.vz > 0 then
            o.vz = o.vz - 320 * dt
            o.z = math.max(0, o.z + o.vz * dt)
            if o.z <= 0 then o.vz = 0 end
        end
        o.wob = o.wob + dt
        local p = world.player
        if o.t > 0.35 and not p.dead and (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 < (p.radius + o.r + 3) ^ 2 then
            o.def.open(world, o)
        end
    end,
    open = function(world, o)
        if o.dead then return end
        o.dead = true
        world.particles:burst(o.x, o.y, 26, { { 1, 0.8, 0.3 }, { 1, 0.95, 0.7 }, { 0.85, 0.6, 0.25 } }, 150, 90, { glow = true, grav = 160 })
        world:addFx({ kind = "ring", x = o.x, y = o.y, r = 30, life = 0.35, color = { 1, 0.85, 0.4 } })
        Audio.play("ui_confirm", { pitch = 0.9 })
        world:openChest(o.kind, o.x, o.y)
    end,
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local royal = o.kind == "queen"
        local s = royal and 1.15 or 0.9
        local wob = math.sin(o.wob * 9) * (0.6 + 0.4 * math.sin(o.wob * 1.7)) * 1.2
        local y = sy - o.z
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx, sy + 2, 11 * s, 5 * s)
        -- glow under it
        local pulse = 0.5 + 0.5 * math.sin(world.time * 4)
        lg.setColor(1, 0.8, 0.3, 0.12 + 0.12 * pulse)
        lg.ellipse("fill", sx, sy, 16 * s, 8 * s)
        -- the cell: wax walls (a hexagonal prism seen from above-front), a domed cap
        local cx, cy = sx + wob * 0.4, y - 8 * s
        lg.setColor(0.55, 0.36, 0.1, 1)
        lg.polygon("fill", hexPts(cx, cy + 4 * s, 9 * s, 0.6))
        lg.setColor(0.85, 0.6, 0.2, 1)
        lg.polygon("fill", hexPts(cx, cy, 9 * s, 0.6))
        lg.setColor(royal and { 1, 0.92, 0.6, 1 } or { 0.98, 0.82, 0.45, 1 })
        lg.polygon("fill", hexPts(cx, cy - 1, 6.5 * s, 0.6))
        lg.setColor(1, 1, 0.9, 0.7)
        lg.ellipse("fill", cx - 2 * s, cy - 2.5 * s, 2.2 * s, 1.1 * s)
        lg.setColor(0.42, 0.26, 0.08, 1)
        lg.setLineWidth(1)
        lg.polygon("line", hexPts(cx, cy, 9 * s, 0.6))
        -- a grub wriggling under the cap
        lg.setColor(0.7, 0.5, 0.25, 0.55)
        lg.arc("line", "open", cx + wob, cy, 3 * s, 0.3, math.pi - 0.3)
        if royal then
            -- a little crown of wax
            lg.setColor(1, 0.85, 0.3, 1)
            for i = -1, 1 do lg.polygon("fill", cx + i * 3 - 1.5, cy - 7 * s, cx + i * 3 + 1.5, cy - 7 * s, cx + i * 3, cy - 10 * s) end
        end
    end,
    label = function(world, o)
        if o.t < 0.35 then return nil end
        return o.kind == "queen" and "ROYAL BROOD CELL" or "BROOD CELL", { 1, 0.88, 0.45 }
    end,
}
