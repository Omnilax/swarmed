-- First-run hints. Each hint shows once, the first time its moment comes up in a real run, then
-- is remembered in `tutorial.lua` in the save folder. Setting "Tutorial Hints" turns them off;
-- turning it back on shows them all again.
--
-- A hint: id, when(world, T) -> true when it should show, text(T) -> string,
-- done(world, T) -> true once the player has done it (hides it early). T is per-run scratch.
local Settings = require("src.core.settings")
local Input = require("src.core.input")
local Theme = require("src.ui.theme")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local Tutorial = { seen = {}, FILE = "tutorial.lua" }

local PAD = { a = "A", b = "B", x = "X", y = "Y", rightshoulder = "RB", leftshoulder = "LB", start = "START" }

-- What to press for an action, on whatever the player is using right now.
function Tutorial.key(id)
    local Touch = require("src.core.touch")
    if Touch.enabled() then
        return ({ dash = "the DASH button", secondary = "the SPECIAL button", inventory = "the BAG button" })[id] or id
    end
    for _, a in ipairs(Input.actions) do
        if a.id == id then
            if Input.lastDevice == "gamepad" and a.pad then return PAD[a.pad[1]] or a.pad[1]:upper() end
            if a.mouse and id ~= "attack" then return a.mouse[1] == 1 and "LEFT CLICK" or "RIGHT CLICK" end
            local k = Input.getKeys(id)[1]
            return k and k:upper() or "?"
        end
    end
    return "?"
end

local K = Tutorial.key

Tutorial.hints = {
    { id = "move",
        when = function(w) return w.time > 0.8 end,
        text = function()
            if require("src.core.touch").enabled() then return "Drag on the left side of the screen to move" end
            return Input.lastDevice == "gamepad" and "Move with the left stick" or "Move with WASD or the arrow keys"
        end,
        done = function(w, T) return (T.walked or 0) > 260 end },
    { id = "attack",
        when = function(w) return w.enemyCount > 0 and w.time > 5 end,
        text = function()
            if Settings.get("autoAttack") then return "Your bug attacks the nearest enemy on its own. Just stay alive!" end
            return "Attack with " .. K("attack")
        end,
        done = function(w) return w.kos >= 8 end },
    { id = "dash",
        when = function(w) return w.kos >= 8 end,
        text = function() return "Press " .. K("dash") .. " to dash out of trouble" end,
        done = function(w, T) return T.dashed end },
    { id = "special",
        when = function(w, T) return T.dashedAt and w.time > T.dashedAt + 4 or w.kos >= 30 end,
        text = function(w)
            local sec = w.player.secondary
            local name = sec and (sec.params.name or sec.type.name)
            return "Press " .. K("secondary") .. " for your special" .. (name and (": " .. name) or "")
        end,
        done = function(w, T) return T.specialUsed end },
    { id = "swarmed",
        when = function(w) return (w.attackers or 0) >= 5 end,
        text = function() return "Every ant touching you bites. Don't let them surround you!" end },
    { id = "items",
        when = function(w) return #w.player.inventory.order > 0 and w.spawner and w.spawner.phase == "wave" end,
        text = function() return "Your items all work from the bag at once. Open it with " .. K("inventory") .. " to arrange them, or eat one to heal" end },
    { id = "skills",
        when = function(w) local sk = w.player.skills return sk and sk.points > 0 end,
        text = function()
            if require("src.core.touch").enabled() then return "Skill point! Open the BAG, then the SKILLS tab" end
            return "Skill point! Open the bag (" .. K("inventory") .. ") and switch to the SKILLS tab ("
                .. (Input.lastDevice == "gamepad" and "RB" or "Tab") .. ")"
        end,
        done = function(w) local sk = w.player.skills return sk and sk.spent > 0 end },
    { id = "queen",
        when = function(w) return w.boss ~= nil and not w.boss.dead end,
        text = function() return "A queen! Slay her for an extra item to choose from" end },
}

function Tutorial.load()
    Tutorial.seen = {}
    if love.filesystem.getInfo(Tutorial.FILE) then
        local ok, chunk = pcall(love.filesystem.load, Tutorial.FILE)
        if ok and chunk then
            local ok2, data = pcall(chunk)
            if ok2 and type(data) == "table" then Tutorial.seen = data end
        end
    end
    Settings.onChange(function(key)
        if key == "tutorialHints" and Settings.get(key) then
            Tutorial.seen = {}
            Tutorial.save()
        end
    end)
end

function Tutorial.save()
    if Tutorial.noSave then return end
    pcall(love.filesystem.write, Tutorial.FILE, "return " .. util.serialize(Tutorial.seen) .. "\n")
end

-- A fresh run: per-run scratch, watching the player for the "done" checks.
function Tutorial.attach(world)
    Tutorial.run = { world = world, T = { px = world.player.x, py = world.player.y } }
    Tutorial.current = nil
    local T = Tutorial.run.T
    local p = world.player
    -- no dash/special events exist, so watch the timers
    T.lastDashCharges, T.lastSpecial = p.dashCharges, p.secondary and p.secondary.timer
end

function Tutorial.update(world, dt)
    local run = Tutorial.run
    if not run or run.world ~= world then return end
    if Tutorial.off or not Settings.get("tutorialHints") or world.mode ~= "run" or world.flags.demo then
        Tutorial.current = nil
        return
    end
    local T, p = run.T, world.player
    T.walked = (T.walked or 0) + util.len(p.x - T.px, p.y - T.py)
    T.px, T.py = p.x, p.y
    if p.dashCharges < (T.lastDashCharges or 0) or p.dashing or p.blocking then
        T.dashed = true
        T.dashedAt = T.dashedAt or world.time
    end
    T.lastDashCharges = p.dashCharges
    local sec = p.secondary
    if sec and T.lastSpecial and sec.timer > T.lastSpecial + 0.05 then T.specialUsed = true end
    T.lastSpecial = sec and sec.timer

    local cur = Tutorial.current
    if cur then
        cur.t = cur.t + dt
        local h = cur.hint
        if cur.t > 9 or (h.done and cur.t > 1.2 and h.done(world, T)) then cur.out = cur.out or cur.t end
        if cur.out and cur.t > cur.out + 0.4 then Tutorial.current = nil end
        return
    end
    if p.dead then return end
    T.gap = (T.gap or 0) - dt
    if T.gap > 0 then return end
    for _, h in ipairs(Tutorial.hints) do
        if not Tutorial.seen[h.id] and h.when(world, T) then
            Tutorial.seen[h.id] = true
            Tutorial.save()
            -- already done before we got to say it: skip quietly
            if not (h.done and h.done(world, T)) then
                Tutorial.current = { hint = h, text = h.text(world, T), t = 0 }
                Audio.play("hint")
                T.gap = 1.5
            end
            return
        end
    end
end

function Tutorial.draw(world, covered)
    local cur = Tutorial.current
    if not cur or covered or not Tutorial.run or Tutorial.run.world ~= world then return end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local k = math.min(1, cur.t / 0.25)
    if cur.out then k = math.max(0, 1 - (cur.t - cur.out) / 0.4) end
    lg.setFont(Theme.font("body"))
    local tw = math.min(lg.getFont():getWidth(cur.text), w - u(80))
    local _, lines = lg.getFont():getWrap(cur.text, tw)
    local bw, bh = tw + u(36), #lines * lg.getFont():getHeight() + u(26)
    local bx = math.floor((w - bw) / 2)
    local by = math.floor(h * 0.7 + (1 - k) * u(12))
    lg.setColor(0.06, 0.045, 0.04, 0.85 * k)
    lg.rectangle("fill", bx, by, bw, bh, u(4))
    local c = Theme.colors
    lg.setColor(c.focus[1], c.focus[2], c.focus[3], k)
    lg.rectangle("fill", bx, by, u(3), bh)
    lg.setColor(c.text[1], c.text[2], c.text[3], k)
    lg.printf(cur.text, bx + u(18), by + u(13), tw, "center")
    lg.setColor(1, 1, 1, 1)
end

return Tutorial
