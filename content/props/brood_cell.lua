-- A brood cell chest: a capped wax cell with something wriggling inside. A slain queen drops one,
-- so does a caught treasure ant (World:dropChest). Walk into it to crack it open: a fanfare rolls
-- 1, 3 or 5 level-up cards (src/states/broodcell.lua, odds in src/config/molting.lua). One still
-- shut when the wave ends opens by itself, so it never holds anything up.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
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
        -- the cell: a painted wax prism with a domed cap (src/gfx/propart.lua)
        local cx = sx + wob * 0.4
        Paint.draw(PA.broodCell(royal), cx, y)
        -- a grub wriggling under the cap
        lg.setColor(0.7, 0.5, 0.25, 0.45)
        lg.arc("line", "open", cx + wob, y - 8 * s - 4, 3 * s, 0.3, math.pi - 0.3)
    end,
    label = function(world, o)
        if o.t < 0.35 then return nil end
        return o.kind == "queen" and "ROYAL BROOD CELL" or "BROOD CELL", { 1, 0.88, 0.45 }
    end,
}
