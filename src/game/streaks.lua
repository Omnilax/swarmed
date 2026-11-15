-- Kill-streak buffs: every `every` kills in one combo (src/config/rewards.lua streaks) the player
-- gets a short random buff from content/streaks. The combo is World.combo (it breaks after 2.5 s
-- without a kill), so keeping the killing going keeps the buffs coming.
local Content = require("src.content")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local util = require("src.core.util")
local ItemFx = require("src.game.itemfx")

local Streaks = {}
Streaks.__index = Streaks

function Streaks.new(rewards)
    return setmetatable({ rewards = rewards, world = rewards.world, level = 0, active = {} }, Streaks)
end

function Streaks:grant(def)
    local p = self.world.player
    for stat, v in pairs(def.stats) do ItemFx.buff(p, "streak_" .. def.id .. "_" .. stat, stat, v, 0, def.time) end
    for stat, v in pairs(def.statsMult) do ItemFx.buff(p, "streakm_" .. def.id .. "_" .. stat, stat, 0, v, def.time) end
    -- one line per buff on the HUD (the same buff again refreshes it)
    for i, a in ipairs(self.active) do if a.def == def then table.remove(self.active, i) break end end
    table.insert(self.active, 1, { def = def, t = def.time })
    local col = util.hex(def.color)
    self.world:floatText(p.x, p.y - 14, def.name:upper() .. "!", col, true)
    Audio.play("ui_confirm", { pitch = 1.25 })
    self.world.camera:shake(0.15)
    self.world.events:emit("streak_buff", def, self.world.combo)
end

function Streaks:update(dt)
    local w = self.world
    local every = self.rewards.cfg.streaks.every
    local lvl = math.floor(w.combo / every)
    if lvl > self.level and not w.player.dead then
        local combo = w.combo
        local def = Content.streaks:pickWeighted(function(d) return d.weight end, function(d) return not d.minCombo or combo >= d.minCombo end)
        if def then self:grant(def) end
    end
    self.level = lvl
    for i = #self.active, 1, -1 do
        local a = self.active[i]
        a.t = a.t - dt
        if a.t <= 0 then table.remove(self.active, i) end
    end
end

-- Lines under the frenzy meter; returns the y below them.
function Streaks:drawHud(right, y, alpha)
    local u = Theme.u
    love.graphics.setFont(Theme.font(14, "bold"))
    local f = love.graphics.getFont()
    for _, a in ipairs(self.active) do
        local col = util.hex(a.def.color)
        local s = ("%s  %s  %ds"):format(a.def.name:upper(), a.def.description, math.ceil(a.t))
        Theme.printShadow(s, right - f:getWidth(s), y, { col[1], col[2], col[3], alpha * math.min(1, a.t * 2) })
        y = y + u(18)
    end
    return y
end

return Streaks
