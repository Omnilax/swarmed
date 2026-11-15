-- The arena. Runs a World in "run" mode (escalating hordes) or "sandbox" mode (dev playground).
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Screen = require("src.core.screen")
local Theme = require("src.ui.theme")
local World = require("src.game.world")
local Hud = require("src.ui.hud")

local Game = { touchControls = "game" }
Game.__index = Game

-- params: mode ("run" | "sandbox"), character (id), stage (id), gameMode (content/modes id),
-- startItems (item ids, from the starting items screen)
function Game.new(params)
    local self = setmetatable({ params = params }, Game)
    self.mode = params.mode or "run"
    self.world = World.new({ mode = self.mode, character = params.character, stage = params.stage,
        gameMode = params.gameMode, startItems = params.startItems })

    if self.mode == "sandbox" then
        self.world.flags.god = true
        self.sandbox = require("src.debug.sandbox").new(self)
    end
    self.world.events:on("player_died", function()
        self.deathTimer = 1.2
    end)
    -- real runs count toward stats and achievements (src/game/records.lua)
    if self.mode == "run" then require("src.game.records").track(self.world, params) end
    return self
end

function Game:enter()
    self:applyCursor()
end

function Game:resume() self:applyCursor() end

function Game:leave()
    love.mouse.setVisible(true)
    local Records = require("src.game.records")
    if Records.run and Records.run.world == self.world then Records.endRun("quit") end
end

function Game:applyCursor()
    local style = Settings.get("cursorStyle")
    love.mouse.setVisible(style == "system" or (self.sandbox ~= nil and self.sandbox.visible))
end

function Game:restart()
    State.switch(Game.new(self.params))
end

function Game:update(dt)
    if Input.pressed("pause") then
        State.push(require("src.states.pause").new(self))
        return
    end
    if Input.pressed("inventory") and not self.world.player.dead then
        State.push(require("src.states.inventory").new(self))
        return
    end
    if Input.pressed("next_wave") then self:nextWave() end
    if Input.pressed("frenzy") then self.world.rewards.frenzy:unleash() end
    self.world:update(dt)
    -- final wave cleared: the run is won (keep going, or end it here); the item choice follows
    local won = self.world.pendingVictory
    if won and self.world.time >= ((self.world.pendingChoice or {}).at or 0) then
        self.world.pendingVictory = nil
        if not self.world.player.dead then
            State.push(require("src.states.victory").new(self, won))
            return
        end
    end
    -- wave cleared: choose an item (a beat after the last kill)
    local choice = self.world.pendingChoice
    if choice and self.world.time >= (choice.at or 0) then
        self.world.pendingChoice = nil
        if not self.world.player.dead then
            State.push(require("src.states.itemchoice").new(self, choice))
            return
        end
    end
    if self.sandbox then self.sandbox:update(dt) end
    if self.deathTimer then
        self.deathTimer = self.deathTimer - dt
        if self.deathTimer <= 0 then
            self.deathTimer = nil
            State.push(require("src.states.gameover").new(self))
        end
    end
end

function Game:draw()
    self.world:flushDecals()
    Screen.beginWorld({ 0.09, 0.08, 0.12, 1 }, self.world.camera:viewZoom())
    self.world:draw()
    Screen.endWorld()
    self.world:drawText({ small = Theme.font(15), big = Theme.font(22) })
    Hud.draw(self, State.top() ~= self)
    if self.sandbox then self.sandbox:draw() end
    if Settings.get("cursorStyle") == "crosshair" and not require("src.core.touch").enabled() and not (self.sandbox and self.sandbox:hovering()) and State.top() == self then
        Hud.crosshair()
    end
end

-- What the on-screen touch buttons show (src/core/touch.lua).
function Game:touchStatus()
    local p = self.world.player
    local sec = p.secondary
    local dashMax = p.dashParams.charges or 1
    local st = p.stamina
    local dashCd = 0
    if st and p.dashDef.hold then dashCd = 1 - st.cur / math.max(0.01, st.max)
    elseif st and p.dashCharges == 0 then dashCd = 1 - st.cur / math.max(0.01, st.cost) end
    local sandbox = self.sandbox
    return {
        special = sec and math.max(0, sec.timer) / math.max(0.01, sec.params.cooldown) or 0,
        specialHold = sec ~= nil and sec.type.update ~= nil,
        dash = dashCd, dashCharges = dashMax > 1 and p.dashCharges or nil,
        manualAttack = not Settings.get("autoAttack"),
        frenzyReady = self.world.rewards.frenzy:ready(),
        sandbox = sandbox,
        -- while placing bugs every tap is a click, so the left half drops them too
        blocked = function(x, y)
            return sandbox ~= nil and (sandbox.placing ~= nil or (sandbox.visible and sandbox.menu ~= nil and sandbox.menu:contains(x, y)))
        end,
    }
end

function Game:focus(f)
    if not f and Settings.get("pauseOnFocusLost") and State.top() == self then
        State.push(require("src.states.pause").new(self))
    end
end

-- Next Wave (key, pad, or a tap on the wave banner): start the wave / send the rest in early.
function Game:nextWave()
    local sp = self.world.spawner
    if self.mode ~= "run" or self.world.player.dead or not sp then return end
    if sp:nextWave() then require("src.core.audio").play("ui_confirm") end
end

function Game:mousepressed(x, y, b)
    if b == 1 and math.abs(x - love.graphics.getWidth() / 2) < Theme.u(140) and y < Theme.u(66) then self:nextWave() end
    if self.sandbox then self.sandbox:mousepressed(x, y, b) end
end

function Game:mousemoved(x, y)
    if self.sandbox then self.sandbox:mousemoved(x, y) end
end

-- The wheel scrolls the sandbox panel under the mouse, otherwise it zooms the camera
-- (finger drags also arrive as wheel moves; those never zoom, a pinch does).
function Game:wheelmoved(x, y)
    if self.sandbox and self.sandbox.visible and self.sandbox:hovering() then
        self.sandbox:wheelmoved(x, y)
    elseif Settings.get("scrollZoom") and not require("src.core.touch").dragging then
        self.world.camera:zoomBy(y)
    end
end

function Game:pinch(factor)
    self.world.camera:zoomBy(0, factor)
end

function Game:keypressed(key)
    if self.sandbox then self.sandbox:keypressed(key) end
end

return Game
