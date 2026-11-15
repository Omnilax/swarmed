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
-- startItems (item ids, from the starting items screen), seed (replays a run; nil = a fresh one),
-- daily (the daily run, src/game/daily.lua), resume (a saved run, src/game/runsave.lua),
-- practice ({ wave, species, items, god }: src/states/practice.lua)
function Game.new(params)
    local self = setmetatable({ params = params }, Game)
    self.mode = params.mode or "run"
    local RunSave = require("src.game.runsave")
    self.world = World.new({ mode = self.mode, character = params.character, stage = params.stage,
        gameMode = params.gameMode, startItems = (not params.resume) and params.startItems or nil,
        seed = params.seed, daily = params.daily })
    if params.resume then RunSave.restore(self.world, params.resume) end
    if params.practice then require("src.states.practice").apply(self.world, params.practice) end

    if self.mode == "sandbox" then
        self.world.flags.god = true
        self.sandbox = require("src.debug.sandbox").new(self)
    end
    self.world.events:on("player_died", function()
        self.deathTimer = 1.2
    end)
    -- real runs count toward stats and achievements (src/game/records.lua); practice doesn't
    if self.mode == "run" and not params.practice then
        local run = require("src.game.records").track(self.world, params)
        if params.resume then RunSave.restoreRecord(run, params.resume) end
        require("src.game.prefs").played(params)
        -- a new run replaces any saved one; the run saves itself at every wave clear
        if not params.resume then RunSave.clear() end
        self.world.events:on("wave_cleared", function() self.saveSoon = true end)
        self.world.events:on("player_died", function() RunSave.clear() end)
        self.world.events:on("run_finished", function() RunSave.clear() end)
    end
    return self
end

-- Pause > Save & Quit: save the run and go back to the title screen.
function Game:saveAndQuit()
    local RunSave = require("src.game.runsave")
    if not RunSave.save(self) then return false end
    require("src.game.records").suspend()
    self.suspended = true
    State.switch(require("src.states.menu").new())
    return true
end

-- The game is closing mid-run (love.quit): keep the run to resume next time.
function Game:closing()
    local RunSave = require("src.game.runsave")
    if RunSave.save(self) then
        require("src.game.records").suspend()
        self.suspended = true
    end
end

function Game:enter()
    self:applyCursor()
end

function Game:resume() self:applyCursor() end

function Game:leave()
    love.mouse.setVisible(true)
    local Records = require("src.game.records")
    if Records.run and Records.run.world == self.world and not self.suspended then
        Records.endRun("quit")
        -- leaving any other way (Main Menu, Restart) gives the run up
        if self.mode == "run" and not self.params.practice then require("src.game.runsave").clear() end
    end
end

function Game:applyCursor()
    local style = Settings.get("cursorStyle")
    love.mouse.setVisible(style == "system" or (self.sandbox ~= nil and self.sandbox.visible))
end

-- Same bug, same mode, same starting items (and for practice, the same setup), from wave 1.
function Game:restart()
    local p = {}
    for k, v in pairs(self.params) do p[k] = v end
    p.resume = nil
    State.switch(Game.new(p))
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
    -- autosave a beat after each wave clear (phones and browser tabs can close at any moment)
    if self.saveSoon then
        self.saveSoon = nil
        require("src.game.runsave").save(self)
    end
    -- a brood cell chest was cracked open: its fanfare first (src/states/broodcell.lua)
    local chests = self.world.pendingChests
    if chests and #chests > 0 and not self.world.player.dead then
        local c = table.remove(chests, 1)
        State.push(require("src.states.broodcell").new(self, c))
        return
    end
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
    if not f and Settings.get("pauseOnFocusLost") and State.top() == self and not self.world.player.dead then
        State.push(require("src.states.pause").new(self))
    end
end

-- Minimised / hidden behind another app: the same as losing focus.
function Game:visible(v) self:focus(v) end

-- The controller in use was unplugged (or its battery died): pause so nobody dies holding nothing.
function Game:joystickremoved(j, wasActive)
    if wasActive and Input.lastDevice == "gamepad" and State.top() == self and not self.world.player.dead then
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
