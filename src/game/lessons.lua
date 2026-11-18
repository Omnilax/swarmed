-- The guided tutorial (content/modes/tutorial.lua): a list of lessons, one at a time. The
-- colony's own waves are switched off; each lesson brings in just what it needs, shows one
-- instruction in a panel at the top, and moves on when the player has done it.
--
-- A lesson: id, title, text (Theme.rich, {action} draws the key), start(world, L) to set it up,
-- done(world, L) -> true when it is finished. L is per-lesson scratch.
local Settings = require("src.core.settings")
local Theme = require("src.ui.theme")
local Audio = require("src.core.audio")
local util = require("src.core.util")

local Lessons = {}

local function around(world, id, n, r, elite)
    local p = world.player
    for i = 1, n do
        local a = (i / n) * math.pi * 2 + love.math.random() * 0.3
        local d = r * (0.85 + love.math.random() * 0.3)
        world:spawnEnemy(id, p.x + math.cos(a) * d, p.y + math.sin(a) * d, elite)
    end
end

local function enemiesLeft(world)
    local n = 0
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if e and not e.dead and not e.def.boss then n = n + 1 end
    end
    return n
end

local function bossAlive(world)
    for i = 1, world.enemyCount do
        local e = world.enemies[i]
        if e and not e.dead and e.def.boss then return true end
    end
    return false
end

Lessons.list = {
    { id = "move", title = "Move",
        text = function()
            if require("src.core.touch").enabled() then return "Drag on the left side of the screen to walk around." end
            return "Walk around with {key:W}{key:A}{key:S}{key:D}, the arrow keys or {pad:leftstick}."
        end,
        done = function(w, L) return (L.walked or 0) > 320 end },
    { id = "attack", title = "Attack",
        text = function()
            if Settings.get("autoAttack") then return "Ants! Your bug attacks the nearest one by itself. Walk close and clear them out." end
            return "Ants! Attack with {attack}. Clear them out."
        end,
        start = function(w) around(w, "worker_ant", 6, 150) end,
        done = function(w) return enemiesLeft(w) == 0 end },
    { id = "dash", title = "Dash",
        text = "Press {dash} to dash. Dashing spends stamina, the thin bar under your health.",
        done = function(w, L) return L.dashed end },
    { id = "special", title = "Special",
        text = function(w)
            local sec = w.player.secondary
            local name = sec and (sec.params.name or sec.type.name)
            return "Every bug has a special move" .. (name and (": " .. name) or "") .. ". Use it with {secondary}."
        end,
        start = function(w) around(w, "worker_ant", 8, 120) end,
        done = function(w, L) return L.special end },
    { id = "swarm", title = "The swarm",
        text = "Every ant touching you bites. Keep moving, dash through gaps and don't get surrounded.",
        start = function(w) around(w, "worker_ant", 24, 190) end,
        done = function(w) return enemiesLeft(w) == 0 end },
    { id = "nectar", title = "Nectar",
        text = "Fallen ants spill golden nectar. Walk near the beads to collect them: they give XP and nectar to spend.",
        start = function(w, L) L.n0 = w.nectar or 0 end,
        done = function(w, L) return (w.nectar or 0) >= L.n0 + 8 or L.t > 14 end },
    { id = "levelup", title = "Level up",
        text = "Level up! Pick one card. Skipping a card gives a skill point for your skill tree instead.",
        start = function(w) require("src.game.levelups").grant(w, 1, { source = "tutorial", now = true }) end,
        done = function(w, L) return L.t > 0.5 and #w.levelups.queue == 0 end },
    { id = "item", title = "Items",
        text = "After every wave you choose an item. Pick one now.",
        start = function(w, L)
            L.items0 = #w.player.inventory.order
            w.pendingChoice = { count = 3, wave = 1, opened = true, at = w.time }
        end,
        done = function(w, L) return #w.player.inventory.order > L.items0 end },
    { id = "bag", title = "The bag",
        text = "Open your bag with {inventory}. Every item in it works at once. Fit the shapes together, or eat an item to heal. Close it to go on.",
        done = function(w, L) return L.bagSeen and L.t > 0.5 end },
    { id = "shop", title = "The shop",
        text = "Here is some nectar. Open the bag, switch to the SHOP tab and buy something.",
        start = function(w)
            local Economy = require("src.game.economy")
            Economy.add(w, math.max(0, 120 - (w.nectar or 0)))
            Economy.restock(w)
        end,
        done = function(w, L) return L.bought end },
    { id = "frenzy", title = "Frenzy",
        text = "Kills fill the frenzy meter. It's full now: press {frenzy} to unleash your bug's super move.",
        start = function(w)
            around(w, "worker_ant", 30, 170)
            local f = w.rewards.frenzy
            f:add(f.max, true)
        end,
        done = function(w, L) return L.frenzy and enemiesLeft(w) == 0 end },
    { id = "elite", title = "Elites",
        text = "A glowing ant is an elite: tougher, with a trick of its own. Take it down.",
        start = function(w)
            local p = w.player
            w:spawnEnemy("soldier_ant", p.x + 160, p.y, "armored")
            around(w, "worker_ant", 6, 200)
        end,
        done = function(w) return enemiesLeft(w) == 0 end },
    { id = "queen", title = "A queen",
        text = "Every fifth wave a queen leads the colony. Slay her for an extra item to choose from.",
        start = function(w)
            local p = w.player
            local q = w:spawnEnemy("queen_worker", p.x + 200, p.y + 40)
            if q then q.hp, q.maxHp = q.hp * 0.4, q.maxHp * 0.4 end
            around(w, "worker_ant", 10, 220)
        end,
        done = function(w, L) return L.t > 1 and not bossAlive(w) end },
    { id = "done", title = "Ready",
        text = "That's the basics! Everything else is explained the first time you meet it, and in the Field Guide on the main menu.",
        done = function(w, L) return L.t > 7 end },
}

function Lessons.on(world) return world.modeDef and world.modeDef.tutorial and world.mode == "run" end

-- Set up the tutorial in a fresh world (World.new calls it).
function Lessons.attach(world)
    if not Lessons.on(world) then return end
    world.spawner.enabled = false
    local T = { i = 0, world = world, px = world.player.x, py = world.player.y }
    world.lessons = T
    local ev = world.events
    ev:on("bag_opened", function() local L = T.L if L then L.bagSeen = true end end)
    ev:on("shop_bought", function() local L = T.L if L then L.bought = true end end)
    ev:on("frenzy_unleashed", function() local L = T.L if L then L.frenzy = true end end)
    Lessons.next(world)
end

function Lessons.current(world)
    local T = world.lessons
    return T and Lessons.list[T.i]
end

function Lessons.next(world)
    local T = world.lessons
    T.i = T.i + 1
    T.L = { t = 0 }
    T.shown = 0
    local l = Lessons.list[T.i]
    if not l then
        T.finished = true
        world.events:emit("tutorial_done")
        return
    end
    if l.start then l.start(world, T.L) end
    if T.i > 1 then Audio.play("ui_confirm", { pitch = 1.2 }) end
end

function Lessons.update(world, dt)
    local T = world.lessons
    if not T or T.finished then return end
    local l, L, p = Lessons.list[T.i], T.L, world.player
    L.t = L.t + dt
    T.shown = T.shown + dt
    L.walked = (L.walked or 0) + util.len(p.x - T.px, p.y - T.py)
    T.px, T.py = p.x, p.y
    if p.dashing or p.blocking then L.dashed = true end
    local sec = p.secondary
    if sec and T.lastSpecial and sec.timer > T.lastSpecial + 0.05 then L.special = true end
    T.lastSpecial = sec and sec.timer
    -- nobody fails the tutorial
    local maxHp = p.stats:get("maxHp")
    if p.hp < maxHp * 0.3 then p.hp = maxHp * 0.7 end
    if l.done(world, L) then
        if not T.doneAt then T.doneAt = 0 end
        T.doneAt = T.doneAt + dt
        if T.doneAt > 0.8 then
            T.doneAt = nil
            Lessons.next(world)
        end
    end
end

function Lessons.draw(world, covered)
    local T = world.lessons
    if not T or covered then return end
    local l = Lessons.list[T.i]
    if not l then return end
    local lg = love.graphics
    local w = lg.getDimensions()
    local u, c = Theme.u, Theme.colors
    local text = type(l.text) == "function" and l.text(world) or l.text
    local k = math.min(1, T.shown / 0.3)
    lg.setFont(Theme.font("body"))
    local tw, n = Theme.richSize(text, math.min(w - u(80), u(620)))
    local lh = lg.getFont():getHeight()
    local head = Theme.font("label", "bold")
    local bw = math.max(tw, u(260)) + u(40)
    local bh = n * lh + head:getHeight() + u(34)
    local bx, by = math.floor((w - bw) / 2), u(64)
    lg.setColor(0.06, 0.045, 0.04, 0.88 * k)
    lg.rectangle("fill", bx, by, bw, bh, u(4))
    lg.setColor(c.focus[1], c.focus[2], c.focus[3], k)
    lg.rectangle("fill", bx, by, u(3), bh)
    lg.setFont(head)
    local done = T.doneAt ~= nil
    local title = ("LESSON %d / %d  ·  %s"):format(T.i, #Lessons.list, l.title:upper()) .. (done and "  ·  DONE" or "")
    lg.setColor(done and 0.55 or c.focus[1], done and 0.9 or c.focus[2], done and 0.5 or c.focus[3], k)
    lg.printf(title, bx, by + u(10), bw, "center")
    Theme.rich(text, bx + u(20), by + u(16) + head:getHeight(), bw - u(40), "center", c.text, k)
    lg.setColor(1, 1, 1, 1)
end

return Lessons
