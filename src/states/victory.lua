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

-- info.swarm: the Final Swarm just ended (src/game/finalswarm.lua): { survived, kills, time }.
function Victory.new(game, info)
    local self = setmetatable({ game = game, info = info or {}, t = 0 }, Victory)
    local world = game.world
    local items = {}
    if not self.info.swarm then
        items[#items + 1] = { type = "button", label = "Keep Going", onActivate = function()
            if not self:ready() then return end
            world.continued = true
            State.pop()
        end }
        -- the last stand: once per run, after the first win
        if self.info.first ~= false and not world.swarmTried then
            items[#items + 1] = { type = "button", label = "Final Swarm", onActivate = function()
                if not self:ready() then return end
                world.swarmTried = true
                require("src.game.finalswarm").start(world)
                State.pop()
            end }
        end
    end
    self.menu = Menu.new({
        align = "center",
        fontSize = 24,
        rowHeight = 46,
        items = {
            { type = "button", label = "Run Summary", onActivate = function()
                if not self:ready() then return end
                State.push(require("src.states.runsummary").new(game))
            end },
            require("src.states.gameover").codeItem(game),
            { type = "button", label = "End Run", onActivate = function()
                if not self:ready() then return end
                world.events:emit("run_finished", world.spawner.wave)
                State.switch(require("src.states.menu").new())
            end },
        },
        rect = function()
            local w, h = love.graphics.getDimensions()
            local mw = Theme.u(300)
            local n = #self.menu.items
            return math.floor((w - mw) / 2), math.floor(math.min(h * 0.6, h - Theme.u(46) * n - Theme.u(20))), mw, Theme.u(46) * n
        end,
    })
    -- Keep Going / Final Swarm first, then Run Summary / End Run
    for i = #items, 1, -1 do table.insert(self.menu.items, 1, items[i]) end
    self.menu:setItems(self.menu.items)
    return self
end

function Victory:ready() return self.t >= Victory.ARM_TIME end

function Victory:enter()
    love.mouse.setVisible(true)
    Audio.play("ui_confirm", { pitch = 0.8 })
end

-- One line that closes the story of the run: the maps it crossed and how it ended.
function Victory.ending(world, info)
    if info.swarm or info.first == false then return nil end
    local Content = require("src.content")
    local names = {}
    for _, id in ipairs(world.actRoute or {}) do
        local st = Content.stages:get(id)
        if st and names[#names] ~= st.name then names[#names + 1] = st.name end
    end
    local path = #names > 1 and ("From " .. table.concat(names, " to ") .. ". ") or ""
    local m = world.modeDef
    if m and m.ending then return path .. m.ending end
    return path .. "The Empress has fallen."
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
    local sw = self.info.swarm
    local title = sw and "SWARM SURVIVED" or (self.info.first ~= false and "COLONY BROKEN" or "STILL STANDING")
    Theme.printShadow(title, 0, h * 0.17, { 1, 0.84, 0.4, k }, "center", w)
    -- the ending: where the run went, and who fell (src/game/acts.lua, src/game/bosses.lua)
    local ending = Victory.ending(world, self.info)
    if ending then
        lg.setFont(Theme.font(18))
        local mw = math.min(w - Theme.u(80), Theme.u(640))
        Theme.printShadow(ending, (w - mw) / 2, h * 0.17 + Theme.u(64), { 0.95, 0.8, 0.9, k }, "center", mw)
    end
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
    local note = "Your bag grew a row. The swarm will keep getting stronger."
    if sw then
        note = ("%d ants fell in the Final Swarm. The colony is broken for good."):format(sw.kills or 0)
    elseif world.danger and world.danger.level > 0 then
        note = note .. "  Danger " .. world.danger.level .. " beaten."
    end
    Theme.printShadow(note, 0, h * 0.34 + Theme.u(88), { 0.62, 0.85, 1, k }, "center", w)
    local amber = require("src.game.amber").runLine(world)
    if amber then Theme.printShadow(amber, 0, h * 0.34 + Theme.u(118), { 1, 0.75, 0.3, k }, "center", w) end
    if self:ready() then self.menu:draw() end
end

function Victory:mousemoved(x, y) self.menu:mousemoved(x, y) end
function Victory:mousepressed(x, y, b) if self:ready() then self.menu:mousepressed(x, y, b) end end

return Victory
