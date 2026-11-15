-- Developer console commands. Add a table to this list to add a command.
-- run(args, game, out): args are the words after the command, game is the running Game state
-- (nil on menus), out(text) prints to the console.
local Content = require("src.content")
local Settings = require("src.core.settings")
local Stats = require("src.game.stats")

local function needGame(game, out)
    if not game then out("No run active. Start one or use 'sandbox'.") end
    return game ~= nil
end

local commands = {}
local function add(c) commands[#commands + 1] = c end

add { name = "help", help = "List commands", run = function(args, game, out)
    for _, c in ipairs(commands) do out(("%-10s %s"):format(c.name, (c.usage and c.usage .. "  " or "") .. "- " .. c.help)) end
end }

add { name = "list", usage = "<kind>", help = "List content ids: enemies, items, characters, attacks, behaviors, stages, sprites", run = function(args, game, out)
    local reg = Content[args[1] or ""]
    if type(reg) ~= "table" or not reg.all then out("Unknown kind. Try: " .. table.concat(Content.order, ", ")) return end
    out(table.concat(reg:ids(), ", "))
end }

add { name = "spawn", usage = "<enemy> [n]", help = "Spawn enemies around the player", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.enemies:get(args[1] or "")
    if not def then out("Unknown enemy. " .. table.concat(Content.enemies:ids(), ", ")) return end
    local n = tonumber(args[2]) or 1
    local p = game.world.player
    game.world:spawnRing(def, n, p.x, p.y, 120)
    out(("Spawned %d %s"):format(n, def.name))
end }

add { name = "give", usage = "<item> [n]", help = "Give items", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.items:get(args[1] or "")
    if not def then out("Unknown item. " .. table.concat(Content.items:ids(), ", ")) return end
    game.world:giveItem(def.id, tonumber(args[2]) or 1)
    out("Gave " .. def.name)
end }

add { name = "take", usage = "<item> [n]", help = "Remove items", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world.player.inventory:remove(args[1] or "", tonumber(args[2]) or 1)
end }

add { name = "clear", help = "Remove all enemies", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world:clearEnemies()
end }

add { name = "killall", help = "Kill all enemies (counts KOs, triggers procs)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local w = game.world
    for i = 1, w.enemyCount do w:killEnemy(w.enemies[i]) end
end }

add { name = "god", help = "Toggle invulnerability", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world.flags.god = not game.world.flags.god
    out("God mode " .. (game.world.flags.god and "on" or "off"))
end }

add { name = "freeze", help = "Toggle enemy AI", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world.flags.freezeAI = not game.world.flags.freezeAI
    out("AI " .. (game.world.flags.freezeAI and "frozen" or "running"))
end }

add { name = "timescale", usage = "<x>", help = "Set simulation speed (1 = normal)", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world.timeScale = tonumber(args[1]) or 1
end }

add { name = "heal", help = "Restore full HP", run = function(args, game, out)
    if not needGame(game, out) then return end
    local p = game.world.player
    p.hp = p.stats:get("maxHp")
end }

add { name = "stat", usage = "<stat> <value>", help = "Set a base stat", run = function(args, game, out)
    if not needGame(game, out) then return end
    if not Stats.byId[args[1] or ""] then
        local ids = {}
        for _, d in ipairs(Stats.defs) do ids[#ids + 1] = d.id end
        out("Stats: " .. table.concat(ids, ", "))
        return
    end
    game.world.player.stats:setBase(args[1], tonumber(args[2]) or 0)
end }

add { name = "stats", help = "Print current stats", run = function(args, game, out)
    if not needGame(game, out) then return end
    local s = game.world.player.stats
    local parts = {}
    for _, d in ipairs(Stats.defs) do parts[#parts + 1] = d.id .. "=" .. Stats.format(d.id, s:get(d.id)) end
    out(table.concat(parts, "  "))
end }

add { name = "wave", usage = "<n>", help = "Jump to wave n", run = function(args, game, out)
    if not needGame(game, out) then return end
    game.world:clearEnemies()
    game.world.spawner.streams = {}
    game.world.spawner:startWave(math.max(1, tonumber(args[1]) or 1))
end }

add { name = "spawner", usage = "on|off", help = "Toggle the horde spawner", run = function(args, game, out)
    if not needGame(game, out) then return end
    local sp = game.world.spawner
    if args[1] == "on" then sp.enabled = true elseif args[1] == "off" then sp.enabled = false else sp.enabled = not sp.enabled end
    out("Spawner " .. (sp.enabled and "on" or "off"))
end }

add { name = "char", usage = "<character>", help = "Swap character, keeping items", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.characters:get(args[1] or "")
    if not def then out("Characters: " .. table.concat(Content.characters:ids(), ", ")) return end
    game.world.player:setCharacter(def)
end }

add { name = "set", usage = "<setting> <value>", help = "Change a setting (true/false/number/text)", run = function(args, game, out)
    local s = Settings.byKey[args[1] or ""]
    if not s then out("Unknown setting") return end
    local v = args[2]
    if v == "true" then v = true elseif v == "false" then v = false elseif tonumber(v) then v = tonumber(v) end
    Settings.set(args[1], v)
    Settings.save()
end }

add { name = "sandbox", help = "Open the sandbox", run = function(args, game, out)
    local State = require("src.core.state")
    State.switch(require("src.states.game").new({ mode = "sandbox" }))
end }

add { name = "weather", usage = "[id]", help = "Show the weather, or switch to another (clear, rain, storm, fog...)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local w = game.world.weather
    local def = Content.weather:get(args[1] or "")
    if not def then out("Now: " .. w:name() .. ". Options: " .. table.concat(Content.weather:ids(), ", ")) return end
    w:set(def)
    out("Weather: " .. def.name)
end }

add { name = "event", usage = "[id]", help = "Start a mid-wave event now (honeydew_rain, boot_stomp, flood, lawnmower...)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.events:get(args[1] or "")
    if not def then out("Events: " .. table.concat(Content.events:ids(), ", ")) return end
    game.world.director:start(def)
    out("Event: " .. def.name)
end }

add { name = "encounter", usage = "[id]", help = "Bring in a boss encounter now (anteater, antlion, sparrow)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.bosses:get(args[1] or "")
    if not def then out("Encounters: " .. table.concat(Content.bosses:ids(), ", ")) return end
    game.world.director:startBoss(def)
    out("Encounter: " .. def.name)
end }

add { name = "gamble", usage = "[id]", help = "Put a map gamble next to you (dewdrop_shrine, challenge_bell, gamble_flower)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local w = game.world
    local def = Content.props:get(args[1] or "")
    if not def or not def.gamble then
        local ids = {}
        for _, k in ipairs(w.gambles:kinds()) do ids[#ids + 1] = k.id end
        out("Gambles: " .. table.concat(ids, ", "))
        return
    end
    local x, y = require("src.game.envfx").pointNear(w, w.player.x, w.player.y, 70)
    w.gambles:place(def.id, x, y)
    out("Placed " .. def.name)
end }

add { name = "prop", usage = "<id> [n]", help = "Drop props near you (pebble, twig, acorn, cocoon, merchant)", run = function(args, game, out)
    if not needGame(game, out) then return end
    local def = Content.props:get(args[1] or "")
    if not def then out("Props: " .. table.concat(Content.props:ids(), ", ")) return end
    local w, p = game.world, game.world.player
    for _ = 1, tonumber(args[2]) or 1 do
        local x, y = require("src.game.envfx").pointNear(w, p.x, p.y, 60)
        w.props:spawn(def.id, x, y)
    end
    out("Placed " .. def.name)
end }

return commands
