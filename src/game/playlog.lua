-- Playtest Log (Settings > Developer): one CSV line per cleared wave, and one when the run ends,
-- appended to playtest_log.csv in the save folder. Columns are in HEADER. Only real runs log.
local Settings = require("src.core.settings")

local PlayLog = { FILE = "playtest_log.csv" }

local HEADER = "date,run,bug,mode,wave,event,run_time_s,wave_time_s,hp,max_hp,damage_taken,kos,wave_kos,level,items,nectar\n"

local function csv(v)
    v = tostring(v == nil and "" or v)
    if v:find("[,\"\n]") then v = '"' .. v:gsub('"', '""') .. '"' end
    return v
end

function PlayLog.on(world)
    return not PlayLog.off and Settings.get("playtestLog") and world.mode == "run"
        and not (world.flags and (world.flags.demo or world.flags.practice))
end

function PlayLog.write(world, event)
    if not PlayLog.on(world) then return end
    local L, p = world._playlog, world.player
    local Records = require("src.game.records")
    local sp = world.spawner
    local row = {
        os.date("%Y-%m-%d %H:%M"), Records.get().runs or 0, p.def.id, world.gameMode or "colony",
        sp and sp.wave or 0, event, ("%.1f"):format(world.time or 0), ("%.1f"):format((world.time or 0) - L.waveT),
        math.ceil(p.hp), math.floor(p.stats and p.stats:get("maxHp") or 0), math.floor(L.hurt),
        world.kos or 0, (world.kos or 0) - L.waveKos, p.skills and p.skills.level or 0,
        p.inventory and #p.inventory.order or 0, math.floor(world.nectar or 0),
    }
    for i, v in ipairs(row) do row[i] = csv(v) end
    local line = table.concat(row, ",") .. "\n"
    if not love.filesystem.getInfo(PlayLog.FILE) then pcall(love.filesystem.write, PlayLog.FILE, HEADER) end
    pcall(love.filesystem.append, PlayLog.FILE, line)
end

function PlayLog.attach(world)
    world._playlog = { waveT = 0, waveKos = 0, hurt = 0 }
    local L, ev = world._playlog, world.events
    ev:on("wave_started", function() L.waveT, L.waveKos, L.hurt = world.time or 0, world.kos or 0, 0 end)
    ev:on("player_hurt", function(ctx) L.hurt = L.hurt + (ctx.damage or 0) end)
    ev:on("wave_cleared", function() PlayLog.write(world, "cleared") end)
    ev:on("player_died", function() PlayLog.write(world, "died") end)
    ev:on("run_won", function() PlayLog.write(world, "won") end)
end

return PlayLog
