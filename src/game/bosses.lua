-- Queens with phases, the Empress, and named champions (numbers and names: src/config/bosses.lua).
--
--   * A queen (world.boss) walking in gets a title card: her name and an epithet for the map.
--   * As she is hurt she enrages at each phase line: faster, and her brood rushes in around her.
--   * The last crowned queen of the final wave is the Empress, with one more phase.
--   * On the middle wave of each act the first elite is a named champion: tougher, her name on
--     a bar of her own, and bonus XP and nectar when she falls.
local Cfg = require("src.config.bosses")
local Content = require("src.content")
local Audio = require("src.core.audio")
local Theme = require("src.ui.theme")

local Bosses = { cfg = Cfg }

local function pick(list, seed)
    return list[(seed % #list) + 1]
end

function Bosses.attach(world)
    if world.mode ~= "run" then return end
    world.bosses = { seen = nil, card = nil, championDue = false }
    world.events:on("wave_started", function(n)
        local st = world.bosses
        st.championDue = false
        if world.lessons or not require("src.game.onramp").allows(world, "elites", n) then return end
        for _, w in ipairs(Cfg.championWaves) do if w == n then st.championDue = true end end
    end)
    world.events:on("elite_spawned", function(e)
        local st = world.bosses
        if not st.championDue or e.def.boss or world.champion then return end
        st.championDue = false
        Bosses.crownChampion(world, e)
    end)
    world.events:on("enemy_died", function(e)
        if not e.champion then return end
        if world.champion == e then world.champion = nil end
        local c = Cfg.champion
        world:grantXP(c.xp, e.x, e.y)
        world:addNectar(c.nectar, e.x, e.y - 10)
        world.milestone = { text = e.champion:upper() .. " FALLS", t = 0 }
        Audio.play("boom", { pitch = 0.9 })
    end)
end

function Bosses.crownChampion(world, e)
    local c = Cfg.champion
    local name = pick(Cfg.championNames, (world.seed or 0) + (world.spawner and world.spawner.wave or 0) * 7)
    e.champion = name
    e.title = name .. ", " .. e.def.name
    e.maxHp = math.floor(e.maxHp * c.hpMul + 0.5)
    e.hp = e.maxHp
    e.scale, e.baseScale = e.scale * c.scale, (e.baseScale or e.scale) * c.scale
    world.champion = e
    Bosses.card(world, name, "a champion " .. e.def.name:lower(), { 1, 0.75, 0.4 }, true)
end

-- A title card across the screen (small = the champion's shorter one).
function Bosses.card(world, title, sub, color, small)
    if not world.bosses then return end
    world.bosses.card = { title = title, sub = sub, color = color, t = 0, life = Cfg.card.time * (small and 0.75 or 1), small = small }
end

local function newQueen(world, q)
    local sp = world.spawner
    local empress = sp and sp.finalThisWave and (sp.crownLeft or 0) <= 0 and q.title ~= nil
    q.phases = { list = empress and Cfg.empressPhases or Cfg.queenPhases, i = 1 }
    local stage = world.stage and world.stage.id
    local pool = Cfg.epithets[stage] or Cfg.epithets.any
    local epithet = pick(pool, (world.seed or 0) + (sp and sp.wave or 0))
    if empress then
        q.title = "The Empress"
        q.empress = true
        Bosses.card(world, "THE EMPRESS", q.def.name .. ", mother of every colony here", { 1, 0.55, 0.85 })
    else
        Bosses.card(world, (q.title or q.def.name):upper(), epithet, { 1, 0.82, 0.45 })
    end
end

local function enrage(world, q)
    local en = Cfg.enrage
    local n = q.phases.i
    q.phases.i = n + 1
    q.speed = q.speed * en.speed
    q.enraged = n
    local brood = q.def.behaviorParams and q.def.behaviorParams.brood and Content.enemies:get(q.def.behaviorParams.brood)
    if brood then world:spawnRing(brood, en.brood + en.broodPerPhase * (n - 1), q.x, q.y, en.ring) end
    world:floatText(q.x, q.y - 26, "ENRAGED", { 1, 0.35, 0.3 }, true)
    world.camera:shake(0.35)
    Audio.play("queen", { pitch = 1.2, volume = 0.7 })
end

function Bosses.update(world, dt)
    local st = world.bosses
    if not st then return end
    if st.card then
        st.card.t = st.card.t + dt
        if st.card.t >= st.card.life then st.card = nil end
    end
    local q = world.boss
    if q and not q.dead then
        if st.seen ~= q then
            st.seen = q
            newQueen(world, q)
        end
        local ph = q.phases
        local line = ph and ph.list[ph.i]
        if line and q.hp / q.maxHp <= line then enrage(world, q) end
    end
    if world.champion and world.champion.dead then world.champion = nil end
end

-- The title card, drawn over the arena (not over menus).
function Bosses.drawHud(world, covered, alpha)
    local st = world.bosses
    local c = st and st.card
    if not c or covered then return end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local u = Theme.u
    local inT, outT = 0.35, 0.6
    local k = c.t < inT and c.t / inT or math.min(1, (c.life - c.t) / outT)
    k = math.max(0, k) * (alpha or 1)
    local y = h * 0.66      -- below your bug, clear of the wave banner and the boss bar
    local bh = u(c.small and 58 or 84)
    -- a dark band that slides in from the sides
    local slide = (1 - math.min(1, c.t / inT)) * w * 0.5
    lg.setColor(0.04, 0.03, 0.03, 0.72 * k)
    lg.rectangle("fill", -slide, y - bh / 2, w, bh)
    lg.setColor(c.color[1], c.color[2], c.color[3], 0.8 * k)
    lg.rectangle("fill", -slide, y - bh / 2, w, math.max(1, u(2)))
    lg.rectangle("fill", slide, y + bh / 2 - math.max(1, u(2)), w, math.max(1, u(2)))
    lg.setFont(Theme.font(c.small and 30 or 44))
    local th = lg.getFont():getHeight()
    Theme.printShadow(c.title, 0, y - th * 0.72, { c.color[1], c.color[2], c.color[3], k }, "center", w)
    lg.setFont(Theme.font(c.small and 15 or 18))
    Theme.printShadow(c.sub, 0, y + th * 0.32, { 0.92, 0.88, 0.8, k }, "center", w)
    lg.setColor(1, 1, 1, 1)
end

return Bosses
