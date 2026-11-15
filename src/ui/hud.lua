-- In-run HUD: health, dash, KO counter and combo, wave and timer, held items.
local Settings = require("src.core.settings")
local Theme = require("src.ui.theme")
local Content = require("src.content")
local util = require("src.core.util")
local Daylight = require("src.game.daylight")

local Hud = {}

local rarityColors = {}
for id, r in pairs(require("src.config.rarities")) do rarityColors[id] = util.hex(r.color) end

local function bar(x, y, w, h, t, color)
    local lg = love.graphics
    lg.setColor(0, 0, 0, 0.55)
    lg.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 4, 4)
    lg.setColor(1, 1, 1, 0.08)
    lg.rectangle("fill", x, y, w, h, 3, 3)
    lg.setColor(color)
    lg.rectangle("fill", x, y, w * util.clamp(t, 0, 1), h, 3, 3)
end

-- "WAVE 7 / 15" during a run, "FINAL WAVE" on the boss wave that ends it, plain "WAVE 23" after.
function Hud.waveLabel(sp)
    if sp.endless then return "LEVEL " .. sp.wave end
    if sp.finalThisWave then return "FINAL WAVE" end
    local fw = sp.finalWave and sp:finalWave()
    if fw and sp.wave < fw then return ("WAVE %d / %d"):format(sp.wave, fw) end
    return "WAVE " .. sp.wave
end

-- covered: a menu (pause, bag, results) is open on top, so passing banners stay hidden.
function Hud.draw(game, covered)
    local lg = love.graphics
    local world = game.world
    local p = world.player
    local w, h = lg.getDimensions()
    local c = Theme.colors
    local alpha = Settings.get("hudOpacity") / 100
    local u = Theme.u

    -- Swarmed: red edges that deepen with the number of ants biting you
    local n = world.attackers or 0
    Hud.swarm = util.lerp(Hud.swarm or 0, n, 0.15)
    if Hud.swarm > 0.5 and not Settings.get("reduceFlashing") then
        if not Hud.vignette then
            local verts = { { 0.5, 0.5, 0, 0, 0.6, 0, 0, 0 } }
            for i = 0, 32 do
                local a = i / 32 * math.pi * 2
                verts[#verts + 1] = { 0.5 + math.cos(a) * 0.75, 0.5 + math.sin(a) * 0.75, 0, 0, 0.6, 0, 0, 1 }
            end
            Hud.vignette = love.graphics.newMesh(verts, "fan", "static")
        end
        local k = math.min(0.55, Hud.swarm * 0.035) * (0.85 + 0.15 * math.sin(love.timer.getTime() * 8))
        lg.setColor(1, 1, 1, k)
        lg.draw(Hud.vignette, 0, 0, 0, w, h)
    end

    -- Health
    local maxHp = p.stats:get("maxHp")
    local bw = u(260)
    bar(u(20), u(20), bw, u(22), p.hp / maxHp, { c.hp[1], c.hp[2], c.hp[3], alpha })
    lg.setFont(Theme.font(16))
    lg.setColor(1, 1, 1, alpha)
    lg.print(math.ceil(p.hp) .. " / " .. math.floor(maxHp), u(28), u(21))
    -- Stamina: one bar for every dash, hold mode and block (src/game/stamina.lua)
    local st = p.stamina
    if st then
        local sw, sh = u(160), u(8)
        local k = st.cur / math.max(0.01, st.max)
        local tap = not p.dashDef.stamina and not p.dashDef.blocked
        local ready = tap and st.cur >= st.cost - 1e-6 or k >= (p.dashParams.minStart or 0.25) or st.on or p.blocking
        local col = ready and { 0.55, 0.9, 0.6, alpha } or { 1, 0.6, 0.35, alpha }
        if st.on or p.blocking then col = { 0.75, 1, 0.7, alpha } end
        if st.flashT > 0 and math.floor(st.flashT * 16) % 2 == 0 then col = { 1, 0.35, 0.3, alpha } end
        bar(u(20), u(49), sw, sh, k, col)
        -- notches: one segment per pressed-dash charge, or the share needed to start a hold
        lg.setColor(0, 0, 0, 0.5 * alpha)
        if tap then
            local n = math.floor(st.max / st.cost + 0.5)
            for i = 1, n - 1 do lg.rectangle("fill", math.floor(u(20) + sw * i / n), u(49), math.max(1, u(2)), sh) end
        else
            lg.rectangle("fill", math.floor(u(20) + sw * (p.dashParams.minStart or 0.25)), u(49), math.max(1, u(2)), sh)
        end
    end
    if p.secondary then
        local sc = p.secondary
        bar(u(20), u(61), u(160), u(4), 1 - math.max(0, sc.timer) / sc.params.cooldown, { 1, 0.7, 0.35, alpha })
    end

    if n >= 3 then
        lg.setFont(Theme.font(18))
        Theme.printShadow("SWARMED x" .. n, u(20), u(71), { 1, 0.35, 0.3, alpha })
    end
    -- status effects, next to the dash bar
    local sx = u(190)
    lg.setFont(Theme.font(14))
    if p.venomT > 0 then
        Theme.printShadow("POISONED", sx, u(44), { 0.8, 0.5, 1, alpha })
        sx = sx + u(80)
    end
    if (p.slowMul or 1) < 0.95 then
        Theme.printShadow(world.latchCount > 0 and ("GRABBED x" .. world.latchCount) or "SLOWED", sx, u(44), { 1, 0.85, 0.5, alpha })
    end

    -- Boss health
    local boss = world.boss
    if boss and not boss.dead then
        local bw2 = math.min(u(520), w * 0.5)
        local bx = (w - bw2) / 2
        local by = h - u(70)
        lg.setFont(Theme.font(18))
        Theme.printShadow((boss.title or boss.def.name):upper(), 0, by - u(26), { 1, 0.8, 0.5, alpha }, "center", w)
        bar(bx, by, bw2, u(12), boss.hp / boss.maxHp, { 0.85, 0.25, 0.2, alpha })
    end

    -- XP: a thin bar along the bottom, with a nudge when skill points are waiting
    local sk = p.skills
    if sk and not world.flags.demo then
        local xw = math.min(u(420), w * 0.4)
        local xx, xy = math.floor((w - xw) / 2), h - u(game.sandbox and 40 or 16)
        bar(xx, xy, xw, u(5), sk.into / sk.toNext, { 0.35, 0.75, 1, alpha })
        lg.setFont(Theme.font(13))
        Theme.printShadow("LV " .. sk.level, xx - u(48), xy - u(5), { 0.55, 0.85, 1, alpha })
        if sk.points > 0 then
            local pulse = 0.75 + 0.25 * math.sin(love.timer.getTime() * 5)
            local key = require("src.core.input").lastDevice == "gamepad" and "{inventory}, then {pad:rightshoulder}" or "{inventory}, then {key:Tab}"
            if require("src.core.touch").enabled() then key = "BAG" end
            Theme.rich(sk.points .. " SKILL POINT" .. (sk.points > 1 and "S" or "") .. "  (" .. key .. ")", 0, xy - u(22) - u(3), w, "center",
                { 0.55, 0.9, 1 }, alpha * (sk.flashT > 0 and 1 or pulse))
        end
    end

    -- Wave and timer
    if world.mode == "run" then
        local sp = world.spawner
        lg.setFont(Theme.font(24))
        local sub
        if sp.phase == "wave" then
            Theme.printShadow(Hud.waveLabel(sp), 0, u(16), { c.text[1], c.text[2], c.text[3], alpha }, "center", w)
            sub = sp.endless and ("next level in " .. math.max(1, math.ceil(sp.levelT)))
                or (sp:remaining() .. (sp.mode.families and not require("src.core.util").contains(sp.mode.families, "ant") and " left" or " ants left"))
        else
            Theme.printShadow(sp.wave > 0 and ("WAVE " .. sp.wave .. " CLEARED") or "GET READY", 0, u(16), { c.focus[1], c.focus[2], c.focus[3], alpha }, "center", w)
            local key = (require("src.core.input").getKeys("next_wave")[1] or "N"):upper()
            if require("src.core.touch").enabled() then key = "TAP HERE" end
            sub = sp:waiting() and ("press " .. key .. " to start the next wave")
                or ("next wave in " .. math.max(1, math.ceil(sp.timer)) .. "  ·  " .. key .. " to start now")
        end
        if Settings.get("showTimer") then
            local t = math.floor(world.time)
            sub = sub .. string.format("  ·  %d:%02d", math.floor(t / 60), t % 60)
        end
        lg.setFont(Theme.font(16))
        Theme.printShadow(sub, 0, u(46), { c.dim[1], c.dim[2], c.dim[3], alpha }, "center", w)
        -- Big announcement as a wave begins
        if sp.phase == "wave" and sp.waveTime < 2.2 and not covered then
            local k = sp.waveTime < 0.25 and sp.waveTime / 0.25 or math.min(1, (2.2 - sp.waveTime) / 0.6)
            lg.setFont(Theme.font(56))
            Theme.printShadow(sp.finalThisWave and "FINAL WAVE" or (sp.endless and "LEVEL " or "WAVE ") .. sp.wave, 0, h * 0.3
, { 1, 0.86, 0.5, k * alpha }, "center", w)
        end
        -- A new species this wave: what it is and how to deal with it, while it walks in alone
        local def = sp.newSpecies
        local t0, t1 = 1.9, 11     -- after the big WAVE N has faded
        if def and sp.phase == "wave" and sp.waveTime > t0 and sp.waveTime < t1 and not covered then
            local t = sp.waveTime
            local k = math.min(1, (t - t0) / 0.3, (t1 - t) / 0.8) * alpha
            local bw2 = math.min(w - u(40), u(470))
            lg.setFont(Theme.font(15))
            local _, dl = lg.getFont():getWrap(def.description or "", bw2 - u(28))
            local _, tl = lg.getFont():getWrap(def.tip or "", bw2 - u(28))
            local bh2 = u(72) + (#dl + #tl) * u(19)
            local bx, by = math.floor((w - bw2) / 2), math.floor(u(76) - (1 - math.min(1, (t - t0) / 0.3)) * u(10))
            lg.setColor(0.06, 0.045, 0.04, 0.88 * k)
            lg.rectangle("fill", bx, by, bw2, bh2, u(4))
            lg.setColor(0.95, 0.7, 0.3, k)
            lg.rectangle("fill", bx, by, bw2, u(3))
            lg.setFont(Theme.font(13, "bold"))
            lg.setColor(0.95, 0.7, 0.3, k)
            lg.printf(sp.wave == 1 and "MEET THE COLONY" or "NEW SPECIES", bx, by + u(10), bw2, "center")
            lg.setFont(Theme.font(24, "bold"))
            Theme.printShadow(def.name, bx, by + u(26), { 1, 0.95, 0.85, k }, "center", bw2)
            lg.setFont(Theme.font(15))
            lg.setColor(c.text[1], c.text[2], c.text[3], k)
            lg.printf(def.description or "", bx + u(14), by + u(58), bw2 - u(28), "center")
            lg.setColor(0.6, 0.85, 0.5, k)
            lg.printf(def.tip or "", bx + u(14), by + u(60) + #dl * u(19), bw2 - u(28), "center")
        end
    end

    -- KO counter, Warriors style
    if Settings.get("showKoCounter") then
        lg.setFont(Theme.font(44))
        local ko = tostring(world.kos)
        Theme.printShadow(ko, w - u(40) - lg.getFont():getWidth(ko), u(12), { c.focus[1], c.focus[2], c.focus[3], alpha })
        lg.setFont(Theme.font(16))
        Theme.printShadow("KO", w - u(36), u(40), { c.text[1], c.text[2], c.text[3], alpha })
        if world.combo >= 5 then
            local pulse = 1 + math.max(0, world.comboTimer - 2.2) * 0.8
            lg.setFont(Theme.font(math.floor(22 * pulse)))
            local s = world.combo .. " HIT COMBO"
            Theme.printShadow(s, w - u(40) - lg.getFont():getWidth(s), u(72), { 1, 0.55, 0.3, alpha * math.min(1, world.comboTimer) })
        end
    end

    -- KO milestone popup (every 100 KOs)
    local m = world.milestone
    if m and not covered then
        local pop = m.t < 0.15 and (1.6 - m.t / 0.15 * 0.6) or 1
        local fade = math.min(1, (1.6 - m.t) / 0.4)
        lg.setFont(Theme.font(math.floor(48 * pop)))
        Theme.printShadow(m.text, 0, h * 0.22, { 1, 0.8, 0.3, fade * alpha }, "center", w)
    end

    -- Items: a row of small icons (one per kind, with its stack count), wrapping onto more rows
    local inv = p.inventory
    if #inv.order > 0 then
        local Sprites = require("src.gfx.sprites")
        lg.setFont(Theme.font(12))
        local size = math.floor(u(22))
        local x0, y = u(20), u(92)
        local x = x0
        for _, id in ipairs(inv.order) do
            local def = Content.items:get(id)
            local col = rarityColors[def.rarity] or c.text
            lg.setColor(0, 0, 0, 0.45 * alpha)
            lg.rectangle("fill", x, y, size, size)
            lg.setColor(col[1], col[2], col[3], 0.7 * alpha)
            lg.rectangle("fill", x, y + size - 2, size, 2)
            local icon = Sprites.get(def.icon)
            local k = math.min((size - 4) / icon.w, (size - 4) / icon.h)
            lg.setColor(1, 1, 1, alpha)
            lg.draw(Sprites.atlas, icon.frames[1][1], math.floor(x + size / 2), math.floor(y + size / 2), 0, k, k, icon.ox, icon.oy)
            local n = inv.counts[id]
            if n > 1 then Theme.printShadow(tostring(n), x + size - u(8), y + size - u(12), { 1, 1, 1, alpha }) end
            x = x + size + u(4)
            if x > x0 + (size + u(4)) * 7 then x, y = x0, y + size + u(4) end
        end
    end

    -- arrows to queens and elites off screen, first-run hints (src/game/feedback.lua)
    require("src.game.feedback").drawHud(game, covered)

    if Settings.get("showFps") then
        lg.setFont(Theme.font(14))
        lg.setColor(c.dim)
        lg.print(love.timer.getFPS() .. " fps", w - u(70), h - u(24))
    end
    lg.setColor(1, 1, 1, 1)
end

function Hud.crosshair()
    local lg = love.graphics
    local x, y = love.mouse.getPosition()
    local r = Theme.u(7)
    lg.setLineWidth(2)
    lg.setColor(0, 0, 0, 0.6)
    lg.circle("line", x + 1, y + 1, r)
    lg.setColor(1, 0.9, 0.6, 0.9)
    lg.circle("line", x, y, r)
    lg.rectangle("fill", x - 1, y - 1, 2, 2)
    lg.setLineWidth(1)
end

return Hud
