-- Discord status:  love . --selftest --discord
-- Checks the JSON and frame encoding, what the status says on the menu, in a run, at a game
-- over and in the sandbox, and that turning the setting off stops it. With
-- SWARMED_DISCORD_APP_ID set and a Discord (or tools/fake_discord.py) listening, it also sends
-- the status over the real pipe; the fake server prints what it got.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Discord = require("src.core.discord")
local Presence = require("src.game.presence")

local function check(cond, msg)
    if not cond then error("discord: " .. msg, 2) end
    print("[selftest] discord ok: " .. msg)
end

return function(wait)
    -- encoding
    check(Discord.json({ b = "x\"y\n", a = 1, c = { 1, 2 }, d = true }) == '{"a":1,"b":"x\\"y\\n","c":[1,2],"d":true}', "json")
    local f = Discord.frame(1, "{}")
    check(#f == 10 and f:byte(1) == 1 and f:byte(5) == 2, "frame header")

    -- what the status says
    check(Presence.describe().details == "In the menus", "menu status")
    local Game = require("src.states.game")
    local game = State.switch(Game.new({ mode = "run", character = "stag_beetle", stage = "backyard", danger = 2 }))
    local t0 = love.timer.getTime()
    while game.world.spawner.wave < 1 and love.timer.getTime() - t0 < 20 do wait(0.1) end
    local a = Presence.describe()
    print("[selftest] discord run status: " .. a.details .. " / " .. tostring(a.state))
    check(a.details:find("Wave %d+ as Stag Beetle") ~= nil, "run details")
    check(a.state and a.state:find("Danger 2", 1, true) ~= nil, "run state shows danger")
    check(a.timestamps and type(a.timestamps.start) == "number", "elapsed timer")
    State.push(require("src.states.gameover").new(game))
    a = Presence.describe()
    check(a.details:find("^Fell on wave") ~= nil and not a.timestamps, "game over status")
    State.switch(Game.new({ mode = "sandbox", character = "mantis" }))
    check(Presence.describe().details:find("sandbox") ~= nil, "sandbox status")

    -- the live pipe (only when an app id is given)
    if os.getenv("SWARMED_DISCORD_APP_ID") then
        local t1 = love.timer.getTime()
        while not Discord.ready and love.timer.getTime() - t1 < 8 do wait(0.1) end
        check(Discord.ready, "handshake with Discord (" .. Discord.status .. ")")
        wait(5)
        Settings.set("discordStatus", false)
        wait(0.3)
        check(not Discord.connected, "setting off closes the pipe")
        Settings.set("discordStatus", true)
        local t2 = love.timer.getTime()
        while not Discord.ready and love.timer.getTime() - t2 < 30 do wait(0.2) end
        check(Discord.ready, "setting back on reconnects")
        wait(5)
    end
    print("[selftest] discord: all good")
end
