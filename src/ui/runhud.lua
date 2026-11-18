-- Run info on the HUD: the enemies-left counter with wave progress, the next-wave preview during
-- a break, and the first-sighting popup for a species you have never met (or not this run).
-- Drawn by Hud.draw; the sighting queue listens on the world's "species_seen" event.
local Settings = require("src.core.settings")
local Theme = require("src.ui.theme")
local util = require("src.core.util")

local RunHud = {}

local SIGHT_TIME = 5        -- seconds a sighting card stays up
local INTRO_TIME = 7        -- ... and the card for the species a wave introduces
local SIGHT_FADE = 0.35

-- Draw sprite `id` scaled to fit a size x size box centred on (cx, cy). False if it has none.
function RunHud.icon(id, cx, cy, size, alpha)
    local Sprites = require("src.gfx.sprites")
    local s = id and Sprites.byId and Sprites.byId[id]
    if not s or not Sprites.atlas then return false end
    local k = math.min(size / s.w, size / s.h)
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(s.image or Sprites.atlas, s.frames[1][1], math.floor(cx), math.floor(cy), 0, k, k, s.ox, s.oy)
    return true
end

-- One line on what a species does: its tip if it has one, else the first sentence of its description.
function RunHud.oneLine(def)
    local s = def.tip
    if not s or s == "" then
        s = def.description or ""
        s = s:match("^(.-[%.!?])%s") or s
    end
    return s
end

----------------------------------------------------------------------------------------------
-- First sightings

-- Hook a world up (Hud calls it once per world). Real runs only, not the menu demo or sandbox.
function RunHud.attach(world)
    if world._runHud then return world._runHud end
    local st = { queue = {}, cur = nil }
    world._runHud = st
    world.events:on("species_seen", function(def)
        local mode = Settings.get("speciesPopups")
        if mode == "off" or world.mode ~= "run" or world.flags.demo then return end
        local sp = world.spawner
        local Records = require("src.game.records")
        local profile = Records.get()
        profile.seen = profile.seen or {}
        local first = not profile.seen[def.id]
        if not Records.noSave then profile.seen[def.id] = true end
        -- the species this wave introduces: always shown (first in line, a bit longer), once the
        -- big WAVE N banner has faded
        if sp and sp.newSpecies == def then
            table.insert(st.queue, 1, { def = def, t = 0, first = first, wait = 1.6, intro = INTRO_TIME,
                label = sp.wave == 1 and "MEET THE COLONY" or "NEW SPECIES" })
            return
        end
        if mode == "new" and not first then return end
        st.queue[#st.queue + 1] = { def = def, t = 0, first = first }
    end)
    return st
end

local function updateSightings(st, dt)
    if not st.cur and #st.queue > 0 then st.cur = table.remove(st.queue, 1) end
    local c = st.cur
    if c then
        if (c.wait or 0) > 0 then c.wait = c.wait - dt return end
        c.t = c.t + dt
        -- hurry along when more are waiting
        local base = c.intro or SIGHT_TIME
        local life = #st.queue > 0 and base * 0.6 or base
        if c.t > life then st.cur = nil end
        c.life = life
    end
end

function RunHud.drawSighting(world, covered, alpha)
    local st = world._runHud
    if not st then return end
    updateSightings(st, love.timer.getDelta())
    local c = st.cur
    if not c or covered or (c.wait or 0) > 0 then return end
    local lg = love.graphics
    local u = Theme.u
    local w, h = lg.getDimensions()
    local life = c.life or SIGHT_TIME
    local k = math.min(1, c.t / SIGHT_FADE, (life - c.t) / SIGHT_FADE) * alpha
    if k <= 0 then return end
    local slide = (1 - math.min(1, c.t / SIGHT_FADE)) * u(30)
    local bw = math.min(u(330), w * 0.45)
    lg.setFont(Theme.font("small"))
    local line = RunHud.oneLine(c.def)
    local _, wl = lg.getFont():getWrap(line, bw - u(70))
    local bh = math.max(u(64), u(46) + #wl * u(17))
    local x, y = math.floor(u(20) - slide), math.floor(h * 0.4)
    Theme.panel(x, y, bw, bh, false, k)
    local col = Theme.colors.focus
    lg.setColor(col[1], col[2], col[3], k)
    lg.rectangle("fill", x, y + u(8), u(3), bh - u(16))
    if not RunHud.icon(c.def.sprite, x + u(34), y + bh / 2, u(36), k) then
        lg.setColor(1, 1, 1, 0.2 * k)
        lg.circle("fill", x + u(34), y + bh / 2, u(14))
    end
    lg.setFont(Theme.font("small"))
    lg.setColor(col[1], col[2], col[3], k)
    lg.print(c.label or (c.first and "FIRST SIGHTING" or "NEW THIS RUN"), x + u(60), y + u(7))
    lg.setFont(Theme.font("label", "bold"))
    Theme.printShadow(c.def.name, x + u(60), y + u(22), { 1, 0.95, 0.85, k })
    lg.setFont(Theme.font("small"))
    local tc = Theme.colors.text
    lg.setColor(tc[1], tc[2], tc[3], k)
    lg.printf(line, x + u(60), y + u(42), bw - u(70))
end

----------------------------------------------------------------------------------------------
-- Enemies left

-- Enemies still to beat this wave (alive + on their way), and the wave's share already killed.
function RunHud.remaining(world)
    local sp = world.spawner
    if not sp or world.mode ~= "run" then return world.enemyCount, nil end
    if sp.endless then return world.enemyCount, nil end
    local left = sp.phase == "wave" and sp:remaining() or world.enemyCount
    local rs = world.runStats
    local wv = rs and rs.waves[sp.wave]
    local done = sp.phase == "wave" and wv and wv.kills or 0
    local total = done + left
    return left, total > 0 and done / total or nil
end

-- A chip under the KO counter: "142 LEFT" and a thin bar of how much of the wave is done.
function RunHud.drawEnemyCount(world, x1, y, alpha)
    if not Settings.get("showEnemyCount") or world.flags.demo then return y end
    local sp = world.spawner
    if world.mode == "run" and sp and sp.phase ~= "wave" and world.enemyCount == 0 then return y end
    local lg = love.graphics
    local u = Theme.u
    local left, frac = RunHud.remaining(world)
    local c = Theme.colors
    lg.setFont(Theme.font(20, "bold"))
    local num = tostring(left)
    local f = lg.getFont()
    lg.setFont(Theme.font("small"))
    local word = (sp and sp.mode and sp.mode.families and not util.contains(sp.mode.families, "ant")) and "LEFT" or "ANTS LEFT"
    if world.mode ~= "run" or (sp and sp.endless) then word = "ON FIELD" end
    local ww = lg.getFont():getWidth(word)
    local bw = math.max(u(110), f:getWidth(num) + ww + u(14))
    local x = x1 - bw
    lg.setFont(f)
    Theme.printShadow(num, x, y, { c.text[1], c.text[2], c.text[3], alpha })
    lg.setFont(Theme.font("small"))
    Theme.printShadow(word, x + f:getWidth(num) + u(8), y + u(6), { c.dim[1], c.dim[2], c.dim[3], alpha })
    if frac then
        local by = y + u(27)
        lg.setColor(0, 0, 0, 0.5 * alpha)
        lg.rectangle("fill", x - 1, by - 1, bw + 2, u(4) + 2)
        lg.setColor(c.focus[1], c.focus[2], c.focus[3], 0.85 * alpha)
        lg.rectangle("fill", x, by, bw * frac, u(4))
        return by + u(10)
    end
    return y + u(28)
end

----------------------------------------------------------------------------------------------
-- Next wave preview

-- During a break: what the next wave brings (queen / final wave, a new species, modifiers).
function RunHud.drawPreview(world, covered, y, alpha)
    if covered or world.mode ~= "run" or world.flags.demo or world.lessons or not (Settings.get("nextWavePreview") and Settings.get("hudDetail") ~= "clean") then return end
    local sp = world.spawner
    if not sp or sp.phase == "wave" or not sp.preview or world.finalSwarm then return end
    local pv = sp:preview()
    if not pv then return end
    local lg = love.graphics
    local u = Theme.u
    local w = lg.getWidth()
    local c = Theme.colors
    local rows = {}
    if pv.final then
        rows[#rows + 1] = { text = "FINAL WAVE: crowned queens, one after another", color = { 1, 0.6, 0.35 } }
    elseif pv.boss then
        rows[#rows + 1] = { text = "QUEEN WAVE: a queen leads the swarm", color = { 1, 0.72, 0.4 } }
    end
    if pv.newSpecies then
        rows[#rows + 1] = { text = "New: " .. pv.newSpecies.name, sub = RunHud.oneLine(pv.newSpecies), icon = pv.newSpecies.sprite, color = c.text }
    end
    for _, m in ipairs(pv.modifiers or {}) do
        local col = m.color
        if type(col) == "string" then col = util.hex(col) end
        rows[#rows + 1] = { text = m.name or tostring(m.id or "?"), sub = m.description, color = col or { 0.75, 0.85, 1 } }
    end
    if #rows == 0 then rows[1] = { text = "More of the colony you have met", color = c.dim } end
    local bw = math.min(w - u(40), u(420))
    lg.setFont(Theme.font("small"))
    local f = lg.getFont()
    local bh = u(30)
    for _, r in ipairs(rows) do
        r.h = u(22)
        if r.sub and r.sub ~= "" then
            local _, wl = f:getWrap(r.sub, bw - u(64))
            r.h = r.h + #wl * u(17)
        end
        bh = bh + r.h
    end
    local x = math.floor((w - bw) / 2)
    Theme.panel(x, y, bw, bh, false, 0.92 * alpha)
    lg.setColor(c.focus[1], c.focus[2], c.focus[3], alpha)
    lg.printf("NEXT: WAVE " .. pv.wave, x, y + u(7), bw, "center")
    local yy = y + u(28)
    for _, r in ipairs(rows) do
        local tx = x + u(16)
        if r.icon then
            RunHud.icon(r.icon, x + u(28), yy + u(10), u(24), alpha)
            tx = x + u(48)
        end
        lg.setFont(Theme.font("label", "bold"))
        Theme.printShadow(r.text, tx, yy, { r.color[1], r.color[2], r.color[3], alpha })
        if r.sub and r.sub ~= "" then
            lg.setFont(f)
            lg.setColor(c.dim[1], c.dim[2], c.dim[3], alpha)
            lg.printf(r.sub, tx, yy + u(20), bw - (tx - x) - u(16))
        end
        yy = yy + r.h
    end
end

return RunHud
