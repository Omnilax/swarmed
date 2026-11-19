-- Hold To Inspect (setting, key: Inspect, V / Left Alt): while held the run slows down and the
-- enemies near the pointer get a label with their name, elite kind, health and what they do.
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Iso = require("src.core.iso")

local Inspect = {}

function Inspect.active(world)
    return Settings.get("holdInspect") and not world.flags.demo and Input.down("inspect") and not world.player.dead
end

-- Time scale while held.
function Inspect.timeScale(world)
    return Inspect.active(world) and 0.35 or 1
end

-- Labels at window resolution (World:drawText).
function Inspect.draw(world, fonts)
    if not Inspect.active(world) then return end
    local lg = love.graphics
    local mx, my = world:mouseWorld()
    local Input2 = require("src.core.input")
    if Input2.lastDevice == "gamepad" or Input2.lastDevice == "touch" then
        local p = world.player
        mx, my = p.x + p.aimX * 60, p.y + p.aimY * 60
    end
    -- nearest few to the pointer
    local picks = {}
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if not e.hidden then
            local d = (e.x - mx) ^ 2 + (e.y - my) ^ 2
            if d < 110 * 110 then picks[#picks + 1] = { e = e, d = d } end
        end
    end
    table.sort(picks, function(a, b) return a.d < b.d end)
    local f = fonts.small
    lg.setFont(f)
    for i = 1, math.min(5, #picks) do
        local e = picks[i].e
        local def = e.def
        local lines = { def.name or def.id }
        if e.elite then lines[1] = (e.elite.name or "Elite") .. " " .. lines[1] end
        lines[#lines + 1] = string.format("%d / %d HP", math.ceil(math.max(0, e.hp)), math.ceil(e.maxHp or e.hp))
        if def.boss then lines[#lines + 1] = "Queen" elseif def.encounter then lines[#lines + 1] = "Beast" end
        if def.blurb or def.desc then lines[#lines + 1] = (def.blurb or def.desc):sub(1, 60) end
        local wx, wy = world:toWindow(e.x, e.y, 18)
        local tw = 0
        for _, l in ipairs(lines) do tw = math.max(tw, f:getWidth(l)) end
        local lh = f:getHeight()
        local bx, by = math.floor(wx - tw / 2 - 6), math.floor(wy - lh * #lines - 10)
        lg.setColor(0.08, 0.06, 0.05, 0.85)
        lg.rectangle("fill", bx, by, tw + 12, lh * #lines + 6, 4)
        lg.setColor(e.elite and 1 or 0.95, e.elite and 0.82 or 0.92, e.elite and 0.4 or 0.85, 1)
        for j, l in ipairs(lines) do
            lg.printf(l, bx + 6, by + 3 + (j - 1) * lh, tw, "center")
            lg.setColor(0.85, 0.82, 0.75, 1)
        end
    end
    lg.setColor(1, 1, 1, 1)
    local _ = Iso
end

return Inspect
