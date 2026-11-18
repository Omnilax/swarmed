-- Run codes: a short line that starts the same run on another machine (same bug, map, mode,
-- danger, seed and artifacts). Copied from the game over and victory screens, played from mode
-- select ("Play a Run Code", read from the clipboard).
--
--   swarmed1.rhino_beetle.backyard.colony.d0.k3f9a2.glass+giants
--
-- The bug must be one you have unlocked; artifacts in a code are on whether you own them or
-- not (like the weekly challenge). Keepsakes are not part of a code.
local Content = require("src.content")

local RunCode = { PREFIX = "swarmed1" }

local function b36(n)
    n = math.floor(math.abs(n))
    local digits, s = "0123456789abcdefghijklmnopqrstuvwxyz", ""
    repeat
        local r = n % 36
        s = digits:sub(r + 1, r + 1) .. s
        n = math.floor(n / 36)
    until n == 0
    return s
end

-- The code for a world's run (nil for runs a code can't repeat: practice, custom waves, the tutorial).
function RunCode.encode(world)
    if not world or world.mode ~= "run" or (world.flags and world.flags.practice) then return nil end
    local m = world.modeDef
    if m and (m.custom or m.tutorial) then return nil end
    local danger = world.danger and world.danger.level or 0
    local stage = (world.actRoute and world.actRoute[1]) or world.stage.id
    local parts = { RunCode.PREFIX, world.player.def.id, stage, world.gameMode or "colony",
        "d" .. danger, b36(world.seed or 0) }
    if world.artifacts and #world.artifacts > 0 then parts[#parts + 1] = table.concat(world.artifacts, "+") end
    return table.concat(parts, ".")
end

-- Game params for a code, or nil and why not.
function RunCode.decode(code)
    if type(code) ~= "string" then return nil, "No code" end
    code = code:gsub("%s", "")
    local parts = {}
    for p in code:gmatch("[^%.]+") do parts[#parts + 1] = p end
    if parts[1] ~= RunCode.PREFIX or #parts < 6 then return nil, "Not a run code" end
    local char, stage, mode = Content.characters:get(parts[2]), Content.stages:get(parts[3]), Content.modes:get(parts[4])
    if not (char and stage and mode) then return nil, "This code names a bug, map or mode this game doesn't have" end
    if mode.custom or mode.tutorial or mode.hidden then return nil, "That mode can't be shared" end
    if not require("src.game.unlocks").bug(char.id) then return nil, char.name .. " isn't unlocked yet" end
    local danger = tonumber((parts[5] or ""):match("^d(%d+)$"))
    local seed = tonumber(parts[6], 36)
    if not danger or not seed then return nil, "Not a run code" end
    local arts = {}
    for id in (parts[7] or ""):gmatch("[^+]+") do
        if Content.artifacts:get(id) then arts[#arts + 1] = id end
    end
    return { mode = "run", character = char.id, stage = stage.id, gameMode = mode.id, danger = danger,
        seed = seed, artifacts = arts, keepsake = false, shared = true }
end

return RunCode
