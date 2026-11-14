-- Results screen after the player falls.
local State = require("src.core.state")
local Theme = require("src.ui.theme")
local Menu = require("src.ui.menu")

local GameOver = { transparent = true }
GameOver.__index = GameOver

function GameOver.new(game)
    local self = setmetatable({ game = game, t = 0 }, GameOver)
    self.menu = Menu.new({
        align = "center",
        fontSize = 24,
        rowHeight = 46,
        items = {
            { type = "button", label = "Try Again", onActivate = function() game:restart() end },
            { type = "button", label = "Main Menu", onActivate = function() State.switch(require("src.states.menu").new()) end },
        },
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = Theme.u(300)
            return math.floor((w - mw) / 2), math.floor(h * 0.62), mw, Theme.u(46) * 2
        end,
    })
    return self
end

function GameOver:enter() love.mouse.setVisible(true) end

function GameOver:update(dt)
    self.t = self.t + dt
    self.menu:update(dt)
end

function GameOver:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local world = self.game.world
    lg.setColor(0.05, 0.02, 0.03, math.min(0.8, self.t * 2))
    lg.rectangle("fill", 0, 0, w, h)
    lg.setFont(Theme.font("banner"))
    Theme.printShadow("SWARMED", 0, h * 0.18, Theme.colors.bad, "center", w)
    -- the run in four numbers
    local t = math.floor(world.time)
    local cells = {
        { ("%d:%02d"):format(math.floor(t / 60), t % 60), "time" },
        { tostring(world.spawner.wave), world.spawner.endless and "level" or "wave" },

        { tostring(world.kos), "KOs" },
        { tostring(world.bestCombo), "best combo" },
    }
    local u = Theme.u
    local cw = u(150)
    local x0, y0 = math.floor((w - cw * #cells) / 2), h * 0.36
    for i, cell in ipairs(cells) do
        local x = x0 + (i - 1) * cw
        lg.setFont(Theme.font("heading", "bold"))
        Theme.printShadow(cell[1], x, y0, Theme.colors.text, "center", cw)
        lg.setFont(Theme.font("label"))
        lg.setColor(Theme.colors.dim)
        lg.printf(cell[2], x, y0 + u(34), cw, "center")
    end
    if world.won then
        lg.setFont(Theme.font("body"))
        Theme.printShadow("The colony was broken. You went down fighting past it.", 0, y0 + u(80), Theme.colors.text, "center", w)
    end
    self.menu:draw()
end

function GameOver:mousemoved(x, y) self.menu:mousemoved(x, y) end
function GameOver:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return GameOver
