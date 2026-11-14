-- Run feedback that lives outside the simulation: drives the adaptive music, plays sounds for big
-- moments (wave start/clear, a queen arriving, victory, defeat), a heartbeat at low health,
-- first-run hints (src/game/tutorial.lua) and arrows pointing at queens and elites off screen.
-- main.lua calls Feedback.update every frame; it finds the running Game on the state stack by
-- itself and hooks the world's events the first time it sees a new world.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Audio = require("src.core.audio")
local Music = require("src.core.music")
local Theme = require("src.ui.theme")
local Tutorial = require("src.game.tutorial")
local Elites = require("src.game.elites")

local Feedback = {}

local function attach(world)
    Feedback.world = world
    Feedback.swarmT, Feedback.beatT, Feedback.boss = 0, 0, nil
    local ev = world.events
    ev:on("wave_started", function()
        if world.flags.demo or world.mode ~= "run" then return end
        Audio.play("wave_start", { pitch = world.spawner.finalThisWave and 0.8 or 1 })
    end)
    ev:on("wave_cleared", function() Audio.play("wave_clear") end)
    ev:on("run_won", function() Audio.play("victory") end)
    ev:on("chapter_cleared", function() Audio.play("victory", { pitch = 1.06 }) end)
    ev:on("player_died", function() Audio.play("defeat") end)
    Tutorial.attach(world)
    local p = world.player
    Music.setCharacter(p.def, p.radius, p.stats:get("moveSpeed"))
end

-- What else the music follows: low health, a kill combo, and the night.
local function extras(world)
    local p = world.player
    local frac = p.hp / math.max(1, p.stats:get("maxHp"))
    local danger = 0
    if not p.dead and not world.flags.god then danger = math.max(0, math.min(1, (0.35 - frac) / 0.25)) end
    local frenzy = math.max(0, math.min(1, ((world.combo or 0) - 20) / 50))
    local night = world.daylight and 1 - world:daylight() or 0
    local ex = Feedback.ex or {}
    Feedback.ex = ex
    ex.danger, ex.frenzy, ex.night = danger, frenzy, night
    return ex
end

-- The mood of the fight, for the music.
local function mood(world, dt)
    local p, sp = world.player, world.spawner
    if p.dead then return "dead" end
    if sp and sp.finalThisWave and sp.phase == "wave" then return "final" end
    if world.boss and not world.boss.dead then return "boss" end
    if world.mode == "run" and sp and sp.phase ~= "wave" and world.enemyCount == 0 then return "break" end
    if world.mode ~= "run" and world.enemyCount == 0 then return "break" end
    -- a big crowd (or being bitten by many) brings the lead in; it lingers a few seconds
    if world.enemyCount > 140 or (world.attackers or 0) >= 6 or world.combo >= 60 then Feedback.swarmT = 5 end
    Feedback.swarmT = math.max(0, Feedback.swarmT - dt)
    return Feedback.swarmT > 0 and "swarm" or "wave"
end

function Feedback.update(dt)
    local game = State.find(require("src.states.game"))
    if not game then
        Feedback.game = nil
        return
    end
    local world = game.world
    if world ~= Feedback.world then attach(world) end
    Feedback.game = game
    local top = State.top() == game
    local over = not top and world.player.dead
    Music.drive(mood(world, dt), (top or over) and 1 or 0.45, extras(world))
    if not top then return end

    -- a queen walks in
    local boss = world.boss
    if boss ~= Feedback.boss then
        Feedback.boss = boss
        if boss and not boss.dead then Audio.play("queen") end
    end
    -- heartbeat under a third of max health, quicker the lower it gets
    local p = world.player
    local frac = p.hp / math.max(1, p.stats:get("maxHp"))
    if not p.dead and frac < 0.3 and not world.flags.god then
        Feedback.beatT = Feedback.beatT - dt
        if Feedback.beatT <= 0 then
            Audio.play("heartbeat", { volume = 0.6 + (0.3 - frac) * 1.5 })
            Feedback.beatT = 0.55 + frac * 2
        end
    else
        Feedback.beatT = 0
    end
    Tutorial.update(world, dt)
end

-- Arrows at the screen edge for queens and elites that are out of view, and for every ant
-- once only a handful are left in the wave.
function Feedback.drawMarkers(world, covered)
    if covered or not Settings.get("offscreenMarkers") or world.flags.demo then return end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local m = u(26)
    local t = love.timer.getTime()
    local shown = 0
    local function arrow(e, col, size)
        local sx, sy = world:toWindow(e.x, e.y, 0)
        if sx > 0 and sx < w and sy > 0 and sy < h then return end
        local cx, cy = w / 2, h / 2
        local dx, dy = sx - cx, sy - cy
        local k = math.min((w / 2 - m) / math.max(1e-3, math.abs(dx)), (h / 2 - m) / math.max(1e-3, math.abs(dy)))
        local ax, ay = cx + dx * k, cy + dy * k
        local a = math.atan2(dy, dx)
        local s = size * (1 + 0.12 * math.sin(t * 6))
        lg.setColor(0, 0, 0, 0.5)
        lg.polygon("fill", ax + math.cos(a) * s * 1.3, ay + math.sin(a) * s * 1.3 + 2,
            ax + math.cos(a + 2.4) * s, ay + math.sin(a + 2.4) * s + 2, ax + math.cos(a - 2.4) * s, ay + math.sin(a - 2.4) * s + 2)
        lg.setColor(col[1], col[2], col[3], 0.9)
        lg.polygon("fill", ax + math.cos(a) * s * 1.3, ay + math.sin(a) * s * 1.3,
            ax + math.cos(a + 2.4) * s, ay + math.sin(a + 2.4) * s, ax + math.cos(a - 2.4) * s, ay + math.sin(a - 2.4) * s)
        shown = shown + 1
    end
    local boss = world.boss
    if boss and not boss.dead then arrow(boss, { 1, 0.75, 0.3 }, u(13)) end
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if shown >= 8 then break end
        if e and e.elite and not e.dead and e ~= boss then arrow(e, Elites.color(e.elite), u(8)) end
    end
    local sp = world.spawner
    if world.mode == "run" and sp and sp.phase == "wave" and #sp.queue == 0 and #sp.streams == 0 and world.enemyCount <= 8 then
        for i = 1, world.enemyCount do
            local e = world.enemies[i]
            if e and not e.dead and not e.elite and e ~= boss then arrow(e, { 1, 0.45, 0.35 }, u(7)) end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

function Feedback.drawHud(game, covered)
    Feedback.drawMarkers(game.world, covered)
    Tutorial.draw(game.world, covered)
end

return Feedback
