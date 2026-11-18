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
            { type = "button", label = "Run Summary", onActivate = function() State.push(require("src.states.runsummary").new(game)) end },
            { type = "button", label = "Change Bug", onActivate = function() GameOver.changeBug(game) end },
            { type = "button", label = "Main Menu", onActivate = function() State.switch(require("src.states.menu").new()) end },
        },
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = Theme.u(300)
            return math.floor((w - mw) / 2), math.floor(h * 0.66), mw, Theme.u(46) * 4
        end,
    })
    return self
end

-- Back to bug select for the same mode (or the practice screen, for a practice run).
function GameOver.changeBug(game)
    State.switch(require("src.states.menu").new())
    if game.params.practice then
        State.push(require("src.states.practice").new())
        return
    end
    State.push(require("src.states.modeselect").new())
    State.push(require("src.states.charselect").new({ gameMode = game.params.gameMode }))
end

function GameOver:enter() love.mouse.setVisible(true) end

function GameOver:update(dt)
    self.t = self.t + dt
    -- a held attack or dash key must not restart by accident the instant the bug falls
    if self.t > 0.6 and require("src.core.input").pressed("quick_restart") then self.game:restart() return end
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
    local ry = y0 + u(66)
    -- what the run paid toward the Burrow (src/game/amber.lua): no run is wasted
    local amber = require("src.game.amber").runLine(world)
    if amber then
        lg.setFont(Theme.font("body"))
        Theme.printShadow(amber, 0, ry, { 1, 0.75, 0.3 }, "center", w)
        ry = ry + u(30)
    end
    if world.won then
        lg.setFont(Theme.font("body"))
        Theme.printShadow("The colony was broken. You went down fighting past it.", 0, ry, Theme.colors.text, "center", w)
        ry = ry + u(30)
    end
    GameOver.drawRecap(world, ry, w)
    self.menu:draw()
    local Pause = require("src.states.pause")
    local hints = Pause.hints()
    Theme.footer({ hints[1], hints[2] })
end

-- Death recap: what finished you and the last few hits you took (src/game/runstats.lua).
function GameOver.drawRecap(world, y, w)
    local rs = world.runStats
    if not rs then return end
    local lg = love.graphics
    local u = Theme.u
    local c = Theme.colors
    local k = rs.killer
    lg.setFont(Theme.font("label"))
    if k then
        local s = "Killed by " .. k.name
        Theme.printShadow(s, 0, y, c.bad, "center", w)
    end
    local hits = rs.hits
    if #hits == 0 then return end
    local bw = math.min(w - u(40), u(420))
    local x = math.floor((w - bw) / 2)
    y = y + u(26)
    lg.setFont(Theme.font("small"))
    lg.setColor(c.dim)
    lg.printf("LAST HITS TAKEN", x, y, bw, "center")
    y = y + u(20)
    local now = (k and k.time) or hits[#hits].time     -- seconds counted back from the last hit
    for i = #hits, 1, -1 do
        local h = hits[i]
        local fade = i == #hits and 1 or 0.75
        local name = h.name .. (h.count > 1 and ("  x" .. h.count) or "")
        lg.setColor(c.text[1], c.text[2], c.text[3], fade)
        lg.print(name, x, y)
        local dmg = ("-%d"):format(math.max(1, math.floor(h.amount + 0.5)))
        local ago = now - h.time
        local tail = i == #hits and (k and "  final blow" or "  last hit") or ("  %.1fs before"):format(ago)
        lg.setColor(c.dim[1], c.dim[2], c.dim[3], fade)
        local tw = lg.getFont():getWidth(tail)
        lg.print(tail, x + bw - tw, y)
        lg.setColor(c.hp[1], c.hp[2], c.hp[3], fade)
        lg.print(dmg, x + bw - tw - lg.getFont():getWidth(dmg), y)
        y = y + u(19)
    end
end

function GameOver:mousemoved(x, y) self.menu:mousemoved(x, y) end
function GameOver:mousepressed(x, y, b) self.menu:mousepressed(x, y, b) end

return GameOver
