-- A web cocoon with a bug wrapped up inside (the "web cocoon" event). Hit it three times (or
-- dash through it) and the bug inside breaks free and fights beside you for a while.
local PA = require("src.gfx.propart")
local Paint = require("src.gfx.paint")
local Content = require("src.content")
local Audio = require("src.core.audio")

local function freeBug(world)
    local p = world.player
    local options = {}
    for _, c in ipairs(Content.characters:all()) do
        if c.id ~= p.def.id and not c.hidden then options[#options + 1] = c end
    end
    if #options == 0 then options = Content.characters:all() end
    return options[love.math.random(#options)]
end

return {
    name = "Web Cocoon",
    radius = 8, hp = 3, dashHit = 3,
    init = function(world, o)
        o.char = o.char or freeBug(world)
        o.shake = 0
    end,
    onHit = function(world, o, hits)
        if o.dead then return end
        o.hp = o.hp - (hits or 1)
        o.shake = 0.25
        world.particles:burst(o.x, o.y, 6, { { 0.95, 0.95, 0.9 }, { 0.8, 0.8, 0.78 } }, 50, 50, { grav = 120 })
        Audio.play("hit", { pitch = 1.4 })
        if o.hp > 0 then return end
        o.dead = true
        world.particles:burst(o.x, o.y, 22, { { 1, 1, 0.95 }, { 0.85, 0.85, 0.82 } }, 110, 90, { grav = 100 })
        Audio.play("ui_confirm", { pitch = 1.2 })
        local life = o.allyLife or 20
        world.props:spawn("ally", o.x, o.y, { char = o.char, life = life })
        if world.director then
            world.director:announce("Freed: " .. o.char.name, "It fights beside you for " .. life .. " seconds", { 0.6, 1, 0.65 })
        end
        world.events:emit("ally_freed", o.char.id)
    end,
    update = function(world, o, dt) o.shake = math.max(0, o.shake - dt) end,
    draw = function(world, o, sx, sy)
        local lg = love.graphics
        local j = o.shake > 0 and math.floor((love.math.random() - 0.5) * 3) or 0
        local x = sx + j
        lg.setColor(0, 0, 0, 0.3)
        lg.ellipse("fill", sx + 1, sy + 2, 11, 5)
        -- a silk bundle lying on the ground, the bug inside stirring (src/gfx/propart.lua)
        Paint.draw(PA.cocoon(), x, sy)
        local pulse = 0.5 + 0.5 * math.sin(world.time * 3 + o.uid)
        lg.setColor(0.45, 0.3, 0.25, 0.12 + 0.12 * pulse)
        lg.ellipse("fill", x, sy - 8, 3, 5)
        -- cracks as it is hit
        lg.setColor(0.3, 0.25, 0.2, 1)
        for i = 1, (o.def.hp - o.hp) do
            lg.line(x - 2 + i * 2, sy - 14 + i, x + i, sy - 6 - i)
        end
    end,
    label = function(world, o)
        local d = math.sqrt((world.player.x - o.x) ^ 2 + (world.player.y - o.y) ^ 2)
        if d < 140 then return "HIT TO FREE", { 0.8, 1, 0.8 } end
    end,
}
