-- The merchant beetle (the "merchant" event): wanders the arena with a pack of wares while
-- the wave goes on. Its price is paid in KOs made while it is around; walk into it once you
-- have enough and the ware goes straight into your bag (never on the ground). Two sales, then
-- it packs up, and it leaves when the wave ends.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
local Audio = require("src.core.audio")
local Sprites = require("src.gfx.sprites")

local PRICE = { common = 18, uncommon = 30, rare = 45, legendary = 70 }

local function nextWare(world, o)
    o.ware = world:rollItem()
    local base = PRICE[o.ware.def.rarity] or 30
    o.price = math.floor(base * (1 + (o.sold or 0) * 0.5) * (1 + math.max(0, (world.spawner.wave or 1) - 2) * 0.06))
end

local function scrip(world, o) return world.kos - o.kos0 - o.spent end

return {
    name = "Merchant Beetle",
    radius = 9,
    labelZ = 30,
    init = function(world, o)
        o.kos0, o.spent, o.sold, o.anim, o.face = world.kos, 0, 0, 0, 0
        o.say = 0
        o.maxSales = o.maxSales or 2
        nextWare(world, o)
    end,
    update = function(world, o, dt)
        local p = world.player
        o.say = math.max(0, o.say - dt)
        local tx, ty
        if o.leaving then
            tx, ty = o.exitX, o.exitY
        else
            -- keeps a little way off the player, ambling round them
            local a = o.t * 0.25 + o.uid
            tx, ty = p.x + math.cos(a) * 75, p.y + math.sin(a) * 75
        end
        local dx, dy = tx - o.x, ty - o.y
        local d = math.sqrt(dx * dx + dy * dy) + 0.0001
        local s = 48 * math.min(1, d / 20)
        if o.leaving then s = 80 end
        o.x, o.y = o.x + dx / d * s * dt, o.y + dy / d * s * dt
        if d > 2 then o.face = math.atan2((dx + dy) * 0.5, dx - dy) end
        o.anim = o.anim + dt * 6 * math.min(1, s / 40)
        if o.leaving then
            if d < 6 then o.dead = true end
            return
        end
        -- a sale: touch it with enough KOs
        if not p.dead and (p.x - o.x) ^ 2 + (p.y - o.y) ^ 2 < (p.radius + o.r + 4) ^ 2 and o.say <= 0 then
            local have = scrip(world, o)
            if have >= o.price then
                o.spent = o.spent + o.price
                o.sold = o.sold + 1
                local name = o.ware.def.name
                local eaten = world:giveItem(o.ware.def.id)
                world:floatText(o.x, o.y - 14, (eaten > 0 and "Bag full, ate " or "Bought ") .. name, { 1, 0.9, 0.4 }, true)
                Audio.play("pickup", { pitch = 1.1 })
                world.events:emit("merchant_sale", o.ware.def.id)
                if o.sold >= o.maxSales then o.packedUp = true o.def.leave(world, o) else nextWare(world, o) end
            else
                world:floatText(o.x, o.y - 14, ("%d more KOs"):format(o.price - have), { 1, 0.7, 0.5 })
            end
            o.say = 1.4
        end
    end,
    -- off to the nearest edge
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
        local bob = (math.floor(o.anim) % 2)
        lg.setColor(0, 0, 0, 0.35)
        lg.ellipse("fill", sx, sy + 2, 14, 6)
        -- an iridescent beetle with a big pack on its back (src/gfx/propart.lua)
        local flip = math.cos(o.face) < 0 and -1 or 1
        Paint.draw(PA.merchant(math.floor(o.anim) % 2), sx, sy - bob, 0, flip, 1)
    end,
    drawAir = function(world, o, sx, sy)
        if o.leaving then return end
        local lg = love.graphics
        -- the ware on offer floating above, with a bar filling up as the KOs come in
        local y = sy - 34 + math.sin(world.time * 2) * 1.5
        local icon = Sprites.get(o.ware.def.icon)
        local k = math.min(1, scrip(world, o) / o.price)
        lg.setColor(0.08, 0.06, 0.05, 0.85)
        lg.rectangle("fill", sx - 11, y - 11, 22, 26, 3)
        lg.setColor(k >= 1 and 1 or 0.8, k >= 1 and 0.85 or 0.7, 0.35, 1)
        lg.rectangle("line", sx - 11, y - 11, 22, 26, 3)
        local sc = math.min(16 / icon.w, 16 / icon.h)
        lg.setColor(1, 1, 1, 1)
        lg.draw(Sprites.atlas, icon.frames[1][1], sx, y - 2, 0, sc, sc, icon.ox, icon.oy)
        lg.setColor(0.2, 0.15, 0.1, 1)
        lg.rectangle("fill", sx - 8, y + 9, 16, 2)
        lg.setColor(1, 0.85, 0.3, 1)
        lg.rectangle("fill", sx - 8, y + 9, math.floor(16 * k), 2)
    end,
    label = function(world, o)
        if o.leaving then return o.packedUp and "SOLD OUT" or nil, { 0.8, 0.8, 0.7 } end
        local have = math.max(0, scrip(world, o))
        if have >= o.price then return o.ware.def.name .. ": walk in to buy", { 1, 0.9, 0.4 } end
        return ("%s  %d / %d KO"):format(o.ware.def.name, have, o.price), { 0.95, 0.85, 0.7 }
    end,
}
