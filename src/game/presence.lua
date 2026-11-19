-- What Swarmed tells Discord you're doing (src/core/discord.lua does the talking).
-- Looks at the screen stack about once a second and builds a status like
--   Playing Swarmed
--   Wave 7 as Stag Beetle
--   Colony · Danger 2
-- Off when the Discord Status setting is off, in tests, on the web and on phones.
local State = require("src.core.state")
local Settings = require("src.core.settings")
local Discord = require("src.core.discord")
local cfg = require("src.config.discord")

local Presence = { t = 0, off = false }

-- Menu screens by module name -> what the status says there.
local SCREENS = {
    { "src.states.charselect", "Picking a bug" },
    { "src.states.loadout", "Picking a bug" },
    { "src.states.modeselect", "Picking a mode" },
    { "src.states.creator", "Building a bug" },
    { "src.states.bugmixer", "Building a bug" },
    { "src.states.codeeditor", "Building a bug" },
    { "src.states.wavebuilder", "Designing waves" },
    { "src.states.practice", "Setting up practice" },
    { "src.states.catalogue", "Reading the field guide" },
    { "src.states.itemcatalogue", "Reading the field guide" },
    { "src.states.spawncatalogue", "Reading the field guide" },
    { "src.states.records", "Looking at records" },
    { "src.states.cosmetics", "Trying on skins" },
    { "src.states.settings", "In the settings" },
}

local function isA(state, modName)
    local cls = package.loaded[modName]
    return cls ~= nil and type(state) == "table" and getmetatable(state) == cls
end

local runStart = setmetatable({}, { __mode = "k" })  -- world -> os.time() the run was first seen

local function runActivity(game, ending)
    local w = game.world
    local p = w.player
    local bug = p and p.def and p.def.name or "a bug"
    local wave = w.spawner and w.spawner.wave or 0
    local a = {}
    if game.mode == "sandbox" then
        a.details = "Messing about in the sandbox"
        a.state = "as " .. bug
    else
        if ending == "won" then
            a.details = "Won a run as " .. bug
        elseif ending == "lost" or (p and p.dead) then
            a.details = "Fell on wave " .. wave .. " as " .. bug
        else
            a.details = (wave > 0 and ("Wave " .. wave .. " as ") or "Starting out as ") .. bug
        end
        local parts = {}
        if w.daily then parts[#parts + 1] = "Daily Run"
        elseif game.params and game.params.practice then parts[#parts + 1] = "Practice"
        elseif w.modeDef and w.modeDef.name then parts[#parts + 1] = w.modeDef.name end
        local danger = w.danger and w.danger.level or 0
        if danger > 0 then parts[#parts + 1] = "Danger " .. danger end
        if #parts > 0 then a.state = table.concat(parts, " · ") end
    end
    if not runStart[w] then runStart[w] = os.time() - math.floor(w.time or 0) end
    if not ending then a.timestamps = { start = runStart[w] } end
    return a
end

-- The activity for whatever is on screen now (nil = just "Playing Swarmed").
function Presence.describe()
    local stack = State.stack or {}
    local top = stack[#stack]
    local Game = package.loaded["src.states.game"]
    local game = Game and State.find(Game)
    if game and game.world then
        local ending
        if isA(top, "src.states.victory") then ending = "won"
        elseif isA(top, "src.states.gameover") then ending = "lost" end
        return runActivity(game, ending)
    end
    for i = #stack, 1, -1 do
        for _, s in ipairs(SCREENS) do
            if isA(stack[i], s[1]) then return { details = s[2] } end
        end
    end
    return { details = "In the menus" }
end

-- SWARMED_DISCORD_APP_ID in the environment overrides the app id (handy for trying another app)
function Presence.appId()
    local env = os.getenv("SWARMED_DISCORD_APP_ID")
    if env and env ~= "" then return env end
    return cfg.appId
end

local function withArt(a)
    a = a or {}
    if cfg.largeImage and cfg.largeImage ~= "" then
        a.assets = { large_image = cfg.largeImage, large_text = cfg.largeText or "Swarmed" }
    end
    return a
end

function Presence.init(flags)
    flags = flags or {}
    -- tests and the balance bot never show up on anyone's Discord
    if (flags["--selftest"] and not flags["--discord"]) or flags["--profile"] or flags["--balance"] then
        Presence.off = true
        return
    end
    if Settings.get("discordStatus") == false then return end
    Discord.init(Presence.appId())
end

function Presence.update(dt)
    if Presence.off then return end
    local want = Settings.get("discordStatus") ~= false
    if not want then
        if Discord.enabled then Discord.shutdown(); Discord.enabled = false end
        return
    end
    if not Discord.enabled then
        -- turned back on in the settings (init is cheap and quiet when it can't run)
        Presence.t = Presence.t - dt
        if Presence.t > 0 then return end
        Presence.t = 5
        if not Discord.init(Presence.appId()) then return end
    end
    Presence.t = Presence.t - dt
    if Presence.t <= 0 then
        Presence.t = 1
        local ok, a = pcall(Presence.describe)
        if ok then Discord.setActivity(withArt(a)) end
    end
    Discord.update(dt)
end

function Presence.quit()
    Discord.shutdown()
end

return Presence
