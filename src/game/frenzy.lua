-- The frenzy meter: kills fill it (src/config/rewards.lua frenzy), and a full meter can be
-- unleashed (the Frenzy key, a tap on the FRENZY button, or by itself with Settings > Gameplay >
-- Auto Frenzy) as the character's super move from content/frenzies. The player can't be hurt
-- while it runs, the game drops into slow motion for a moment, and a short buff follows.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")
local util = require("src.core.util")

local Frenzy = {}
Frenzy.__index = Frenzy

-- The super move for a character: its own `frenzy`, else a frenzy tagged like it, else the default.
function Frenzy.defFor(charDef, cfg)
    if charDef.frenzy then return Content.frenzies:require(charDef.frenzy) end
    for _, f in ipairs(Content.frenzies:all()) do
        for _, t in ipairs(f.tags) do
            if util.contains(charDef.tags or {}, t) then return f end
        end
    end
    return Content.frenzies:get(cfg.default) or Content.frenzies:all()[1]
end

function Frenzy.new(rewards)
    local cfg = rewards.cfg.frenzy
    return setmetatable({ rewards = rewards, world = rewards.world, charge = 0, max = cfg.max, flashT = 0, readyT = 0 }, Frenzy)
end

function Frenzy:def() return Frenzy.defFor(self.world.player.def, self.rewards.cfg.frenzy) end

function Frenzy:ready() return self.charge >= self.max and not self.active end

-- Fill the meter (not while the move itself runs, unless `force`: bonus rewards).
function Frenzy:add(amount, force)
    if self.active and not force then return end
    local was = self.charge >= self.max
    self.charge = math.min(self.max, self.charge + amount)
    if not was and self.charge >= self.max then
        self.readyT = 0
        Audio.play("ui_confirm", { pitch = 1.4 })
        self.world.events:emit("frenzy_ready")
    end
end

-- Unleash it. Returns true if it went off.
function Frenzy:unleash()
    local w, p = self.world, self.world.player
    if not self:ready() or p.dead then return false end
    local def = self:def()
    self.charge = 0
    local ctx = { world = w, player = p, params = def.params, def = def, t = 0 }
    self.active = ctx
    def.start(ctx)
    local f = self.rewards.cfg.feel
    self.rewards:slowmo(f.frenzySlow, f.frenzySlowTime)
    self.rewards:punch(f.frenzyPunch)
    w.milestone = { text = def.name:upper() .. "!", t = 0 }
    self.flashT = 0.35
    w.events:emit("frenzy_unleashed", def)
    return true
end

function Frenzy:update(dt)
    local w, p = self.world, self.world.player
    self.flashT = math.max(0, self.flashT - dt)
    self.readyT = self.readyT + dt
    local ctx = self.active
    if ctx then
        ctx.t = ctx.t + dt
        local done
        if ctx.def.update then done = ctx.def.update(ctx, dt) else done = ctx.t >= (ctx.params.duration or 1) end
        if done or p.dead then
            self.active = nil
            local b = ctx.def.buff
            if b and not p.dead then
                local ItemFx = require("src.game.itemfx")
                for stat, v in pairs(b.stats or {}) do ItemFx.buff(p, "frenzy_" .. stat, stat, v[1], v[2], b.time) end
                self.buffT, self.buffMax = b.time, b.time
            end
        end
    end
    if self.buffT then
        self.buffT = self.buffT - dt
        if self.buffT <= 0 then self.buffT = nil end
    end
    if self:ready() and Settings.get("frenzyAuto") and w.enemyCount >= 8 then self:unleash() end
end

-- The player can't be hurt while the move runs (Player:hurt asks).
function Frenzy:shielded() return self.active ~= nil end

function Frenzy:drawHud(right, y, alpha)
    local lg = love.graphics
    local u = Theme.u
    local def = self:def()
    local col = util.hex(def.color)
    local bw, bh = u(170), u(9)
    local x = right - bw
    local k = self.charge / self.max
    lg.setColor(0, 0, 0, 0.55 * alpha)
    lg.rectangle("fill", x - 2, y - 2, bw + 4, bh + 4, 4, 4)
    lg.setColor(1, 1, 1, 0.08 * alpha)
    lg.rectangle("fill", x, y, bw, bh, 3, 3)
    local ready = self:ready()
    local pulse = ready and (0.75 + 0.25 * math.sin(love.timer.getTime() * 8)) or 0.85
    if self.active then k, pulse = 1 - math.min(1, self.active.t / math.max(0.1, self.active.params.time or self.active.params.duration or 1)), 1 end
    lg.setColor(col[1], col[2], col[3], pulse * alpha)
    lg.rectangle("fill", x, y, bw * util.clamp(k, 0, 1), bh, 3, 3)
    lg.setFont(Theme.font(14, "bold"))
    local label
    if self.active then
        label = def.name:upper() .. "!"
    elseif ready then
        local Input = require("src.core.input")
        local key = Input.lastDevice == "gamepad" and "R3" or (Input.getKeys("frenzy")[1] or "Q"):upper()
        if require("src.core.touch").enabled() then key = "TAP" end
        label = "FRENZY READY  [" .. key .. "]"
    else
        label = "FRENZY"
    end
    local f = lg.getFont()
    Theme.printShadow(label, right - f:getWidth(label), y + bh + u(2), { col[1], col[2], col[3], (ready and pulse or 0.8) * alpha })
    if self.buffT then
        local s = ("+%ds"):format(math.ceil(self.buffT))
        lg.setFont(Theme.font(14))
        Theme.printShadow(s, x, y + bh + u(2), { 1, 0.9, 0.7, 0.8 * alpha })
    end
    -- a flash over the whole screen as it goes off
    if self.flashT > 0 and not Settings.get("reduceFlashing") then
        local w, h = lg.getDimensions()
        lg.setColor(col[1], col[2], col[3], self.flashT * 0.6)
        lg.rectangle("fill", 0, 0, w, h)
    end
end

return Frenzy
