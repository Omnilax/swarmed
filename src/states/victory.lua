-- The run is won: the final boss wave (wave 15, then every 15 after) is cleared. The player can
-- keep going (waves keep getting harder, and the bag has just grown a row) or end the run here.
-- Opened by Game when world.pendingVictory is set (Spawner:chapterCleared). Keeping going closes
-- it and the usual item choice for the wave follows.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")
local Audio = require("src.core.audio")

local Victory = { transparent = true }
Victory.__index = Victory

Victory.ARM_TIME = 1.0      -- the last kill is usually a held attack: ignore input for a moment

function Victory.new(game, info)
    local self = setmetatable({ game = game, info = info or {}, t = 0 }, Victory)
    local world = game.world
    self.menu = Menu.new({
        align = "center",
        fontSize = 24,
        rowHeight = 46,
        items = {
            { type = "button", label = "Keep Going", onActivate = function()
                if not self:ready() then return end
                world.continued = true
                State.pop()
            end },
            { type = "button", label = "End Run", onActivate = function()
                if not self:ready() then return end
                world.events:emit("run_finished", world.spawner.wave)
                State.switch(require("src.states.menu").new())
            end },
        },
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = Theme.u(300)
            return math.floor((w - mw) / 2), math.floor(h * 0.64), mw, Theme.u(46) * 2
        end,
    })
    return self
end

function Victory:ready() return self.t >= Victory.ARM_TIME end

function Victory:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 0.8 })
end

function Victory:update(dt)
    self.t = self.t + dt
    if self:ready() then self.menu:update(dt) end
end

function Victory:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local world = self.game.world
    local k = math.min(1, self.t * 1.5)
    lg.setColor(0.04, 0.03, 0.02, 0.78 * k)
    lg.rectangle("fill", 0, 0, w, h)
    lg.setFont(Theme.font(56))
    Theme.printShadow(self.info.first ~= false and "COLONY BROKEN" or "STILL STANDING", 0, h * 0.17, { 1, 0.84, 0.4, k }, "center", w)
    lg.setFont(Theme.font(22))
    local t = math.floor(world.time)
    local lines = {
        ("Wave %d cleared  |  %d:%02d"):format(world.spawner.wave, math.floor(t / 60), t % 60),
        ("%d KOs  |  Best combo %d"):format(world.kos, world.bestCombo),
    }
    for i, s in ipairs(lines) do
        Theme.printShadow(s, 0, h * 0.34 + (i - 1) * Theme.u(34), { 0.92, 0.9, 0.85, k }, "center", w)
    end
    lg.setFont(Theme.font(18))
    Theme.printShadow("Your bag grew a row. The swarm will keep getting stronger.", 0, h * 0.34 + Theme.u(88),
        { 0.62, 0.85, 1, k }, "center", w)
    if self:ready() then self.menu:draw() end
end

function Victory:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Victory:mousepressed(x, y, b) if self:ready() then self.menu:mousepressed(x, y, b) end end

return Victory
