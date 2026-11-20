-- The wide Bug Creator API (round 4): everything a custom bug script can read about the game
-- and change about its bug while it plays, plus the systems built on it. The guide for people
-- is docs/CUSTOM_BUGS.md; the full reference (written for AIs too) is docs/BUG_API.md.
--
-- Script fields this file builds (BugAPI.build, called from CustomBugs.build):
--   resources = { ammo = { max, start, regen, reload, color, label, show = "pips" | "bar" | false } }
--   abilities = { { name, key = "ability" | "stance" | "<any key>" | "mouse3", cooldown, cost = {...},
--                   fire(me), hold(me, dt, t), release(me, t) } }
--   stances   = { { name, stats, speed, damageTaken, color, say, attack, secondary, dash, art, look,
--                   onEnter(me), onExit(me), onTick(me, dt), onHit... } },  stanceSwitch = "key" | "code"
--   traits    = { { name, desc, onKill = fn, onTick = fn, ... any hook } }   named sets of hooks
--   hooks.onHud(me, ui) / hooks.onDraw(me, gfx)    draw on the HUD / in the world
--   evolution (built in src/game/bugextras.lua with the other versions of the bug)
--
-- At run time: BugAPI.tick (every frame from SM.tick), BugAPI.event (every game event from
-- SM.event), BugAPI.fire (events this file makes: level ups, sprees, waves ending...),
-- BugAPI.drawHud (src/ui/hud.lua), BugAPI.drawWorld (SM.draw).
local util = require("src.core.util")

local API = {}

-- Every hook name the engine calls. Scripts may also define any other on<Name> function and
-- call it themselves with me.emit("onName", data).
API.EVENTS = {
    -- fired by the game (Inventory:trigger)
    "onHit", "onKill", "onHurt", "onDodge", "onBlock", "onDash", "onDashEnd", "onWaveStart", "onEat",
    "onAttack", "onSpecial",
    -- fired by the Bug Creator systems
    "onStart", "onTick", "onLevelUp", "onEvolve", "onStanceChange", "onWaveEnd", "onSpree", "onSpreeEnd",
    "onCombo", "onLowHp", "onDeath", "onRevive", "onNectar", "onGrab", "onThrow", "onParry", "onAbility",
    "onReload", "onEmpty", "onFormChange", "onBossSpawn", "onHud", "onDraw",
}
API.known = {}
for _, k in ipairs(API.EVENTS) do API.known[k] = true end

local function num(v, default, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    return math.max(lo, math.min(hi, v))
end
local function hexColor(c, default)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x") then
        local h = util.hex(c:sub(1, 7))
        return { h[1], h[2], h[3] }
    end
    if type(c) == "table" and tonumber(c[1]) then return { num(c[1], 1, 0, 1), num(c[2], 1, 0, 1), num(c[3], 1, 0, 1) } end
    return default
end
local function text(v, max) return type(v) == "string" and v:gsub("[%c]", " "):sub(1, max) or nil end
local function SM() return require("src.game.scriptmoves") end

-- Full Lua access (Settings > Developer): scripts get me.engine with the real game tables.
local Settings
function API.fullAccess()
    Settings = Settings or require("src.core.settings")
    return Settings.values.scriptFullAccess == true
end

----------------------------------------------------------------------------------------------
-- Building (from CustomBugs.build)

local function buildHookSet(t, where, errs, warns)
    local out
    for k, fn in pairs(t) do
        if type(k) == "string" and k:match("^on%u") then
            if type(fn) == "function" then out = out or {} out[k] = fn
            else errs[#errs + 1] = where .. "." .. k .. " must be a function(me, ...)" end
        end
    end
    return out
end
API.buildHookSet = buildHookSet

function API.build(raw, def, errs, warns)
    -- resources: ammo, rage, heat, charge... any number the bug keeps
    if type(raw.resources) == "table" then
        def.resources, def.resourceOrder = {}, {}
        local names = {}
        for name in pairs(raw.resources) do if type(name) == "string" then names[#names + 1] = name end end
        table.sort(names)
        for _, name in ipairs(names) do
            local r = raw.resources[name]
            if type(r) ~= "table" then warns[#warns + 1] = "resources." .. name .. " must be a table (dropped)"
            elseif not name:match("^[%a_][%w_]*$") then warns[#warns + 1] = "resources: '" .. name .. "' isn't a plain name (dropped)"
            elseif #def.resourceOrder >= 8 then warns[#warns + 1] = "resources: 8 at most" break
            else
                local max = num(r.max, 10, 0.01, 1e6)
                def.resources[name] = { name = name, max = max, start = num(r.start, max, -1e6, 1e6),
                    regen = num(r.regen, 0, -1e5, 1e5), reload = r.reload and num(r.reload, 1, 0, 60) or nil,
                    min = num(r.min, 0, -1e6, 1e6), color = hexColor(r.color, { 1, 0.82, 0.35 }),
                    label = text(r.label, 16) or (name:sub(1, 1):upper() .. name:sub(2)),
                    show = r.show == false and false or ((r.show == "bar" or (r.show == nil and max > 12)) and "bar" or "pips"),
                    regenDelay = num(r.regenDelay, 0, 0, 60), autoReload = r.autoReload ~= false }
                def.resourceOrder[#def.resourceOrder + 1] = name
            end
        end
        if #def.resourceOrder == 0 then def.resources, def.resourceOrder = nil, nil end
    end
    -- abilities: extra buttons
    if type(raw.abilities) == "table" then
        def.abilities = {}
        for i, a in ipairs(raw.abilities) do
            if i > 6 then warns[#warns + 1] = "abilities: 6 at most" break end
            if type(a) == "table" and (type(a.fire) == "function" or type(a.hold) == "function" or type(a.release) == "function") then
                local cost
                if type(a.cost) == "table" then
                    cost = {}
                    for k, v in pairs(a.cost) do if type(k) == "string" and tonumber(v) then cost[k] = tonumber(v) end end
                end
                def.abilities[#def.abilities + 1] = { name = text(a.name, 24) or ("Ability " .. i),
                    key = type(a.key) == "string" and a.key:sub(1, 16) or (i == 1 and "ability" or nil),
                    cooldown = num(a.cooldown, 1, 0, 600), cost = cost, fire = a.fire, hold = a.hold, release = a.release,
                    color = hexColor(a.color, { 0.6, 0.85, 1 }), desc = text(a.desc, 120) }
            else
                warns[#warns + 1] = "abilities[" .. i .. "] needs fire, hold or release functions (dropped)"
            end
        end
        if #def.abilities == 0 then def.abilities = nil else def.scripted = true end
    end
    -- traits: named sets of hooks (code passives), all running alongside hooks
    if type(raw.traits) == "table" then
        def.traits = {}
        for i, t in ipairs(raw.traits) do
            if i > 12 then warns[#warns + 1] = "traits: 12 at most" break end
            if type(t) == "table" then
                local hs = buildHookSet(t, "traits[" .. i .. "]", errs, warns)
                if hs then def.traits[#def.traits + 1] = { name = text(t.name, 24) or ("Trait " .. i), desc = text(t.desc, 160), hooks = hs } end
            end
        end
        if #def.traits == 0 then def.traits = nil else def.scripted = true end
    end
    def.lowHp = raw.lowHp and num(raw.lowHp, 0.3, 0.01, 0.99) or 0.3
    def.spreeGap = raw.spreeGap and num(raw.spreeGap, 3, 0.2, 30) or 3
    def.spreeEvery = raw.spreeEvery and math.floor(num(raw.spreeEvery, 5, 1, 1000)) or 5
end

-- Stances are built with the other versions of the bug (they may swap moves and body):
-- bugextras.lua calls this with its variant builder.
function API.buildStances(raw, def, errs, warns, variant)
    if type(raw.stances) ~= "table" then return end
    local Stats = require("src.game.stats")
    def.stances = {}
    for i, s in ipairs(raw.stances) do
        if i > 6 then warns[#warns + 1] = "stances: 6 at most" break end
        if type(s) == "table" then
            local st = { name = text(s.name, 24) or ("Stance " .. i), index = i, say = text(s.say, 30),
                speed = s.speed and num(s.speed, 1, 0, 5) or nil, damageTaken = s.damageTaken and num(s.damageTaken, 1, 0, 10) or nil,
                color = hexColor(s.color), stats = {}, hooks = buildHookSet(s, "stances[" .. i .. "]", errs, warns) }
            for k, v in pairs(type(s.stats) == "table" and s.stats or {}) do
                if Stats.byId[k] and type(v) == "number" then st.stats[k] = math.max(-1000, math.min(1000, v))
                else warns[#warns + 1] = "stances[" .. i .. "].stats: '" .. tostring(k) .. "' dropped" end
            end
            -- its own moves / body: a whole version of the bug
            if variant and (s.attack ~= nil or s.secondary ~= nil or s.dash ~= nil or s.art ~= nil or s.look ~= nil) then
                local over = {}
                for _, k in ipairs({ "attack", "secondary", "dash", "art", "look", "anims", "colors" }) do over[k] = s[k] end
                st.def = variant(over, "stances[" .. i .. "]", "_s" .. i)
            end
            def.stances[#def.stances + 1] = st
        end
    end
    if #def.stances == 0 then def.stances = nil return end
    def.stanceSwitch = raw.stanceSwitch == "code" and "code" or "key"
    def.stanceStart = math.floor(num(raw.stanceStart, 1, 1, #def.stances))
    def.scripted = true
end

----------------------------------------------------------------------------------------------
-- Resources

local function base(player) return player.def.baseDef or player.def end

function API.res(player, name)
    local b = base(player)
    local R = b.resources and b.resources[name]
    if not R then return nil end
    player.res = player.res or {}
    local r = player.res[name]
    if not r then
        r = { cur = math.max(R.min, math.min(R.max, R.start)), max = R.max, def = R, delay = 0, reloadT = nil }
        player.res[name] = r
    end
    return r
end

function API.resChanged(player, r, old)
    if r.cur <= r.def.min + 1e-9 and old > r.def.min + 1e-9 then
        API.fire(player, "onEmpty", { name = r.def.name })
        if r.def.reload and r.def.autoReload and not r.reloadT then r.reloadT = r.def.reload end
    end
end

----------------------------------------------------------------------------------------------
-- Stances

function API.setStance(player, n)
    local b = base(player)
    local list = b.stances
    if not list then return false end
    if type(n) == "string" then
        for i, s in ipairs(list) do if s.name:lower() == n:lower() then n = i break end end
    end
    n = tonumber(n)
    if not n then return false end
    n = math.max(1, math.min(#list, math.floor(n)))
    local old = player.stanceIndex
    if old == n then return true end
    local from = old and list[old]
    local to = list[n]
    if from and from.hooks and from.hooks.onExit then SM().run(from.hooks.onExit, player, nil, nil, nil, { label = "onExit" }) end
    player.stanceIndex = n
    -- moves / body: the stance's own, or back to the bug's current version
    local Extras = require("src.game.bugextras")
    local cur = Extras.currentDef(player)
    if to.def or (from and from.def) then
        local keep = player.dashParams
        Extras.swapDef(player, to.def or cur, "stance_moves")
        player.stats:removeSource("stance_moves")
        if not (to.def and to.def.dash) then player.dashParams = keep end
    end
    player.stanceSpeed, player.stanceHurt = to.speed, to.damageTaken
    player.stats:removeSource("stance")
    for k, v in pairs(to.stats) do player.stats:addModifier("stance", k, v, 0) end
    player.stats:recompute()
    local w = player.world
    if w and old then
        local col = to.color or { 0.8, 0.9, 1 }
        w:floatText(player.x, player.y - 12, to.say or to.name, col, false)
        w:addFx({ kind = "ring", x = player.x, y = player.y, r = 20, life = 0.22, color = col })
    end
    if to.hooks and to.hooks.onEnter then SM().run(to.hooks.onEnter, player, nil, nil, nil, { label = "onEnter" }) end
    if old then API.fire(player, "onStanceChange", { from = from and from.name, to = to.name, index = n }) end
    return true
end

function API.stance(player)
    local b = base(player)
    local s = b.stances and b.stances[player.stanceIndex or 1]
    return s
end

----------------------------------------------------------------------------------------------
-- Events

-- Runs a hook on the bug, its traits and its stance. ev must be a plain table (never engine
-- tables). Returns the first value a hook returned (onDeath uses it).
function API.dispatch(player, name, ev, depth, ...)
    local res
    local def = player.def
    local opts = { depth = depth or 0, label = name }
    local hooks = def.hooks
    local fn = hooks and hooks[name]
    if fn then res = SM().run(fn, player, nil, nil, nil, opts, ev, ...) end
    local b = base(player)
    if b.traits then
        for _, t in ipairs(b.traits) do
            local f = t.hooks[name]
            if f then
                opts.label = t.name .. "." .. name
                local r = SM().run(f, player, nil, nil, nil, opts, ev, ...)
                if res == nil then res = r end
            end
        end
    end
    local st = b.stances and b.stances[player.stanceIndex or 1]
    local f = st and st.hooks and st.hooks[name]
    if f and name ~= "onEnter" and name ~= "onExit" then
        opts.label = st.name .. "." .. name
        local r = SM().run(f, player, nil, nil, nil, opts, ev, ...)
        if res == nil then res = r end
    end
    return res
end

-- An event the Bug Creator systems make (not one of the game's item triggers).
function API.fire(player, name, ev)
    if not player.def.custom then return end
    if (player.apiDepth or 0) >= 4 then return end
    player.apiDepth = (player.apiDepth or 0) + 1
    local r = API.dispatch(player, name, ev or {}, player.apiDepth)
    player.apiDepth = player.apiDepth - 1
    return r
end

-- Game events (from SM.event, before the bug's hooks run).
function API.event(player, name, ctx)
    if name == "onKill" then
        local now = player.world and player.world.time or 0
        local k = player.killLog
        if not k then k = { n = 0 } player.killLog = k end
        k.n = k.n % 256 + 1
        k[k.n] = now
        player.killsTotal = (player.killsTotal or 0) + 1
        if ctx.target and ctx.target.def and ctx.target.def.boss then player.bossKills = (player.bossKills or 0) + 1 end
        player.spree = (player.spree or 0) + 1
        player.spreeAt = now
        local every = base(player).spreeEvery or 5
        if player.spree % every == 0 then API.fire(player, "onSpree", { count = player.spree }) end
    elseif name == "onHurt" then
        player.lastHurtAt = player.world and player.world.time or 0
        player.damageTaken = (player.damageTaken or 0) + (ctx.damage or 0)
    elseif name == "onHit" then
        player.lastHitAt = player.world and player.world.time or 0
        player.damageDealt = (player.damageDealt or 0) + (ctx.damage or 0)
    end
end

----------------------------------------------------------------------------------------------
-- Every frame

local function abilityDown(player, a)
    local Input = require("src.core.input")
    local k = a.key
    if not k then return false end
    -- scripted buttons (move previews, tests): world.pilot = { down = { ability = true } }
    local pilot = player.world.pilot
    if pilot then return pilot.down[k] == true end
    if k == "ability" or k == "stance" or k == "attack" or k == "secondary" or k == "dash" or k == "frenzy" then return Input.down(k) end
    local b = k:match("^mouse(%d)$")
    if b then return love.mouse.isDown(tonumber(b)) end
    local ok, d = pcall(love.keyboard.isDown, k)
    return ok and d
end

local function payCost(player, cost, check)
    if not cost then return true end
    for k, v in pairs(cost) do
        if k == "stamina" then
            local s = require("src.game.stamina").state(player)
            if s.cur < v * s.max then if not check then s.flashT = 0.3 end return false end
        elseif k == "hp" then
            if player.hp <= v then return false end
        elseif k == "nectar" then
            if (player.world.nectar or 0) < v then return false end
        else
            local r = API.res(player, k)
            if not r or r.cur < v then return false end
        end
    end
    if check then return true end
    for k, v in pairs(cost) do
        if k == "stamina" then
            local Stamina = require("src.game.stamina")
            Stamina.spend(player, v * Stamina.state(player).max, 0.4)
        elseif k == "hp" then player.hp = player.hp - v
        elseif k == "nectar" then player.world:spendNectar(v)
        else
            local r = API.res(player, k)
            local old = r.cur
            r.cur, r.delay = r.cur - v, r.def.regenDelay
            API.resChanged(player, r, old)
        end
    end
    return true
end
API.payCost = payCost

function API.tick(player, world, dt)
    local b = base(player)
    if world.mode == "menu" then return end
    local live = not world.flags.demo
    local pilot = world.pilot
    -- stance to start in
    if b.stances and not player.stanceIndex then API.setStance(player, b.stanceStart or 1) end
    -- resources refill / reload
    if b.resourceOrder then
        for _, name in ipairs(b.resourceOrder) do
            local r = API.res(player, name)
            local R = r.def
            if r.reloadT then
                r.reloadT = r.reloadT - dt
                if r.reloadT <= 0 then
                    r.reloadT, r.cur = nil, r.max
                    API.fire(player, "onReload", { name = name })
                end
            elseif r.delay > 0 then r.delay = r.delay - dt
            elseif R.regen ~= 0 then
                local old = r.cur
                r.cur = math.max(R.min, math.min(r.max, r.cur + R.regen * dt))
                if R.regen < 0 then API.resChanged(player, r, old) end
            end
        end
    end
    -- abilities
    if b.abilities and live then
        player.abil = player.abil or {}
        for i, a in ipairs(b.abilities) do
            local s = player.abil[i]
            if not s then s = { cd = 0, held = false, t = 0 } player.abil[i] = s end
            s.cd = math.max(0, s.cd - dt)
            local down = (not player.dead) and (player.stunT or 0) <= 0 and abilityDown(player, a)
            if down and not s.held then
                if s.cd <= 0 and payCost(player, a.cost, true) then
                    payCost(player, a.cost)
                    s.held, s.t, s.cd = true, 0, a.cooldown
                    if a.fire then SM().run(a.fire, player, a, nil, nil, { label = a.name }) end
                    API.fire(player, "onAbility", { name = a.name, index = i })
                end
            elseif down and s.held then
                s.t = s.t + dt
                if a.hold then SM().run(a.hold, player, a, nil, nil, { label = a.name }, dt, s.t) end
            elseif not down and s.held then
                s.held = false
                if a.release then SM().run(a.release, player, a, nil, nil, { label = a.name }, s.t) end
            end
        end
    end
    -- the stance key cycles stances
    if b.stances and b.stanceSwitch == "key" and live and not player.dead then
        local Input = require("src.core.input")
        if (pilot and pilot.pressed.stance) or (not pilot and Input.pressed("stance")) then API.setStance(player, (player.stanceIndex or 1) % #b.stances + 1) end
    end
    local st = b.stances and b.stances[player.stanceIndex or 1]
    if st and st.hooks and st.hooks.onTick then SM().run(st.hooks.onTick, player, nil, nil, nil, { label = st.name .. ".onTick" }, dt) end
    if b.traits then
        for _, t in ipairs(b.traits) do
            if t.hooks.onTick then SM().run(t.hooks.onTick, player, nil, nil, nil, { label = t.name .. ".onTick" }, dt) end
        end
    end
    -- sprees end after a gap without kills
    if player.spree and player.spree > 0 and world.time - (player.spreeAt or 0) > (b.spreeGap or 3) then
        local n = player.spree
        player.spree = 0
        API.fire(player, "onSpreeEnd", { count = n })
    end
    -- the world's combo, every 10
    local combo = world.combo or 0
    if combo >= 10 and math.floor(combo / 10) > math.floor((player.lastCombo or 0) / 10) then
        API.fire(player, "onCombo", { combo = combo })
    end
    player.lastCombo = combo
    -- low health, once per dip
    local maxHp = player.stats:get("maxHp")
    local low = player.hp / math.max(1, maxHp) <= (b.lowHp or 0.3)
    if low and not player.wasLow and not player.dead then API.fire(player, "onLowHp", { hp = player.hp, maxHp = maxHp }) end
    player.wasLow = low
    -- level ups, waves ending, nectar, bosses
    local level = player.skills and player.skills.level or 0
    if player.seenLevel and level > player.seenLevel then
        for l = player.seenLevel + 1, level do API.fire(player, "onLevelUp", { level = l }) end
    end
    player.seenLevel = level
    local sp = world.spawner
    local phase = sp and sp.phase
    if player.seenPhase == "wave" and phase == "break" then API.fire(player, "onWaveEnd", { wave = sp.wave }) end
    player.seenPhase = phase
    local nectar = world.nectar or 0
    if player.seenNectar and nectar > player.seenNectar then API.fire(player, "onNectar", { amount = nectar - player.seenNectar, total = nectar }) end
    player.seenNectar = nectar
    local boss = world.boss
    if boss and boss ~= player.seenBoss and not boss.dead then
        API.fire(player, "onBossSpawn", { x = boss.x, y = boss.y, hp = boss.hp, maxHp = boss.maxHp, id = boss.def and boss.def.id })
    end
    player.seenBoss = boss
    -- parry window
    if player.parryT then
        player.parryT = player.parryT - dt
        if player.parryT <= 0 then player.parryT = nil end
    end
    -- key edges for me.keyPressed
    local ks = player.keyState
    if ks then
        for k, v in pairs(ks.now) do ks.prev[k] = v end
        ks.now = {}
    end
end

-- Player:hurt asks this before damage (stance damageTaken, parry window). Returns true to
-- cancel the hit, or a multiplier for it.
function API.ward(player, amount, source)
    if player.parryT and player.parryT > 0 then
        local ev = { damage = amount }
        if type(source) == "table" and source.x then ev.x, ev.y = source.x, source.y end
        player.parryT = nil
        player.world:addFx({ kind = "ring", x = player.x, y = player.y, r = 26, life = 0.2, color = { 1, 1, 0.7 } })
        require("src.core.audio").play("hit", { pitch = 2 })
        API.fire(player, "onParry", ev)
        return true
    end
end

-- Death: onDeath may return true (or call me.revive) to stay alive.
function API.onDeath(player)
    if not player.def.custom then return false end
    player.reviveTo = nil
    local r = API.fire(player, "onDeath", { wave = player.world.spawner and player.world.spawner.wave or 0 })
    local to = player.reviveTo or (r == true and 0.25)
    player.reviveTo = nil
    if to then
        player.hp = math.max(1, player.stats:get("maxHp") * to)
        player.iframes = math.max(player.iframes, 1)
        player.flash = 0.2
        API.fire(player, "onRevive", { hp = player.hp })
        return true
    end
    return false
end

----------------------------------------------------------------------------------------------
-- Drawing: resource pips / bars, ability cooldowns, then the script's own onHud.

local function hudUi(lg, Theme)
    local ui = { w = lg.getWidth(), h = lg.getHeight(), n = 0 }
    local function col(c, a) local cc = hexColor(c, { 1, 1, 1 }) return cc[1], cc[2], cc[3], num(a, 1, 0, 1) end
    local function ok() ui.n = ui.n + 1 return ui.n <= 400 end
    function ui.u(v) return Theme.u(num(v, 1, -1e4, 1e4)) end
    function ui.text(s, x, y, c, size)
        if not ok() then return end
        lg.setFont(Theme.font(math.floor(num(size, 16, 14, 64))))
        Theme.printShadow(tostring(s):sub(1, 120), num(x, 0, -1e4, 1e4), num(y, 0, -1e4, 1e4), { col(c) })
    end
    function ui.rect(x, y, w, h, c, alpha, line)
        if not ok() then return end
        lg.setColor(col(c, alpha))
        lg.rectangle(line and "line" or "fill", num(x, 0, -1e4, 1e4), num(y, 0, -1e4, 1e4), num(w, 10, 0, 1e4), num(h, 10, 0, 1e4))
    end
    function ui.circle(x, y, r, c, alpha, line)
        if not ok() then return end
        lg.setColor(col(c, alpha))
        lg.circle(line and "line" or "fill", num(x, 0, -1e4, 1e4), num(y, 0, -1e4, 1e4), num(r, 5, 0, 2000))
    end
    function ui.bar(x, y, w, h, frac, c, alpha)
        if not ok() then return end
        x, y, w, h = num(x, 0, -1e4, 1e4), num(y, 0, -1e4, 1e4), num(w, 100, 0, 1e4), num(h, 8, 0, 1e4)
        lg.setColor(0, 0, 0, 0.55 * num(alpha, 1, 0, 1))
        lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2)
        lg.setColor(col(c, alpha))
        lg.rectangle("fill", x, y, w * num(frac, 0, 0, 1), h)
    end
    return ui
end

function API.drawHud(player, world, alpha)
    local b = base(player)
    if not (b.resourceOrder or b.abilities or (player.def.hooks and player.def.hooks.onHud)) then return end
    local lg = love.graphics
    local Theme = require("src.ui.theme")
    local u = Theme.u
    local x, y = u(20), u(96)
    lg.setFont(Theme.font(14))
    for _, name in ipairs(b.resourceOrder or {}) do
        local r = API.res(player, name)
        local R = r.def
        if R.show then
            local c = R.color
            Theme.printShadow(R.label, x, y - u(2), { c[1], c[2], c[3], alpha })
            local bx = x + u(70)
            if R.show == "pips" and r.max <= 40 then
                local n = math.floor(r.max + 0.5)
                local pw = math.max(3, math.min(u(12), math.floor(u(160) / math.max(1, n)) - 2))
                for i = 1, n do
                    local full = r.cur >= i - 1e-6
                    lg.setColor(0, 0, 0, 0.5 * alpha)
                    lg.rectangle("fill", bx + (i - 1) * (pw + 2) - 1, y - 1, pw + 2, u(10) + 2)
                    lg.setColor(c[1], c[2], c[3], (full and 1 or 0.18) * alpha)
                    lg.rectangle("fill", bx + (i - 1) * (pw + 2), y, pw, u(10))
                end
            else
                lg.setColor(0, 0, 0, 0.55 * alpha)
                lg.rectangle("fill", bx - 1, y - 1, u(160) + 2, u(8) + 2)
                lg.setColor(c[1], c[2], c[3], alpha)
                lg.rectangle("fill", bx, y, u(160) * math.max(0, math.min(1, (r.cur - R.min) / math.max(1e-6, r.max - R.min))), u(8))
                Theme.printShadow(tostring(math.floor(r.cur)), bx + u(166), y - u(4), { 1, 1, 1, alpha })
            end
            if r.reloadT then Theme.printShadow("reloading", bx + u(166), y - u(4), { 1, 0.8, 0.5, alpha }) end
            y = y + u(18)
        end
    end
    if b.abilities then
        local Input = require("src.core.input")
        for i, a in ipairs(b.abilities) do
            local s = player.abil and player.abil[i]
            local cd = s and s.cd or 0
            local ready = cd <= 0 and payCost(player, a.cost, true)
            local c = a.color
            local key = tostring(a.key or "code")
            if a.key == "ability" or a.key == "stance" then key = Input.getKeys(a.key)[1] or a.key end
            Theme.printShadow(("[%s] %s"):format(tostring(key):upper(), a.name), x, y - u(2), ready and { c[1], c[2], c[3], alpha } or { 0.6, 0.6, 0.6, alpha })
            if cd > 0 and a.cooldown > 0 then
                lg.setColor(c[1], c[2], c[3], 0.6 * alpha)
                lg.rectangle("fill", x, y + u(14), u(120) * (1 - cd / a.cooldown), u(2))
            end
            y = y + u(20)
        end
    end
    local st = b.stances and b.stances[player.stanceIndex or 1]
    if st and #b.stances > 1 then
        local c = st.color or { 0.8, 0.9, 1 }
        Theme.printShadow("Stance: " .. st.name, x, y - u(2), { c[1], c[2], c[3], alpha })
        y = y + u(20)
    end
    local hooks = player.def.hooks
    if hooks and hooks.onHud then
        local ui = hudUi(lg, Theme)
        ui.top = y
        SM().run(hooks.onHud, player, nil, nil, nil, { label = "onHud" }, ui)
    end
    lg.setColor(1, 1, 1, 1)
end

-- hooks.onDraw(me, gfx): shapes in the world, at world positions (drawn over the floor).
function API.drawWorld(player, world)
    local hooks = player.def.hooks
    if not (hooks and hooks.onDraw) then return end
    local Iso = require("src.core.iso")
    local lg = love.graphics
    local n = 0
    local function ok() n = n + 1 return n <= 300 end
    local function col(c, a) local cc = hexColor(c, { 1, 1, 1 }) return cc[1], cc[2], cc[3], num(a, 1, 0, 1) end
    local function at(x, y, z) return Iso.toScreen(num(x, player.x, -1e5, 1e5), num(y, player.y, -1e5, 1e5), num(z, 0, -500, 500)) end
    local gfx = {}
    function gfx.circle(x, y, r, c, alpha, line)
        if not ok() then return end
        local sx, sy = at(x, y)
        r = num(r, 6, 0, 2000)
        lg.setColor(col(c, alpha))
        lg.ellipse(line and "line" or "fill", sx, sy, r, r * 0.5)
    end
    function gfx.line(x1, y1, x2, y2, c, alpha, width)
        if not ok() then return end
        local ax, ay = at(x1, y1)
        local bx, by = at(x2, y2)
        lg.setColor(col(c, alpha))
        lg.setLineWidth(num(width, 1, 0.5, 12))
        lg.line(ax, ay, bx, by)
        lg.setLineWidth(1)
    end
    function gfx.text(s, x, y, c)
        if not ok() then return end
        local sx, sy = at(x, y, 12)
        lg.setColor(col(c))
        lg.print(tostring(s):sub(1, 40), math.floor(sx), math.floor(sy))
    end
    SM().run(hooks.onDraw, player, nil, nil, nil, { label = "onDraw" }, gfx)
    lg.setColor(1, 1, 1, 1)
end

----------------------------------------------------------------------------------------------
-- The `me` toolkit, round 4: added to the one scriptmoves.lua builds.
--   U = run engine code unguarded, cx = what the call is about, dirOf(t) = aim + t.turn.

function API.extend(me, player, cx, U, dirOf)
    local function world() return player.world end
    local Combat = require("src.game.combat")

    -- reading the bug -------------------------------------------------------------------------
    -- Plain fields (me.x, me.vx, me.facing, me.kills...) are refreshed before every call by
    -- API.refresh. These functions work it out when asked.
    function me.stat(id)
        if type(id) ~= "string" or not require("src.game.stats").byId[id] then return nil end
        return player.stats:get(id)
    end
    function me.angleTo(x, y)
        return math.atan2(num(y, player.y, -1e5, 1e5) - player.y, num(x, player.x, -1e5, 1e5) - player.x)
    end
    function me.distTo(x, y)
        local dx, dy = num(x, player.x, -1e5, 1e5) - player.x, num(y, player.y, -1e5, 1e5) - player.y
        return math.sqrt(dx * dx + dy * dy)
    end
    -- is (x, y) within `tolerance` radians (default 0.5) of where the bug faces?
    function me.isFacing(x, y, tolerance)
        local a = me.angleTo(x, y)
        return math.abs(util.angleDiff(player.wangle or 0, a)) <= num(tolerance, 0.5, 0, math.pi)
    end
    -- the mouse in the world (on a pad / touch: a point 100 px ahead along the aim)
    function me.cursor()
        return U(function() return player:pointer() end)
    end
    function me.facingCursor(tolerance)
        local x, y = me.cursor()
        return me.isFacing(x, y, tolerance)
    end
    -- the angle between where the bug faces and where it walks (0 = forwards, pi = backwards)
    function me.moveVsFacing()
        if not player.moving then return 0 end
        return math.abs(util.angleDiff(player.wangle or 0, math.atan2(player.moveDirY or 0, player.moveDirX or 1)))
    end
    function me.killsIn(seconds)
        local k = player.killLog
        if not k then return 0 end
        local now, s, n = world().time, num(seconds, 3, 0, 600), 0
        for i = 1, math.min(256, #k) do if k[i] and now - k[i] <= s then n = n + 1 end end
        return n
    end
    function me.cooldowns()
        local a, s = player.attack, player.secondary
        local out = { attack = a and math.max(0, a.timer) or 0, secondary = s and math.max(0, s.timer) or 0 }
        if player.abil then
            for i, st in ipairs(player.abil) do out[i] = st.cd end
        end
        return out
    end
    function me.items()
        local out = {}
        for id, n in pairs(player.inventory and player.inventory.counts or {}) do if n > 0 then out[id] = n end end
        return out
    end
    function me.hasItem(id) return player.inventory and player.inventory:count(tostring(id)) or 0 end
    function me.status()
        return { poisoned = (player.venomT or 0) > 0, slowed = (player.slowMul or 1) < 1, stunned = (player.stunT or 0) > 0,
            blinded = (player.blindT or 0) > 0, gummed = (player.gumT or 0) > 0, iframes = player.iframes or 0,
            cloaked = player.cloakT ~= nil, dead = player.dead and true or false }
    end
    function me.waveInfo()
        local sp = world().spawner
        if not sp then return { number = 0 } end
        return { number = sp.wave, phase = sp.phase, time = sp.waveTime or 0, left = U(function() return sp:remaining() end),
            alive = world().enemyCount or 0, final = U(function() return sp:isFinal() end) and true or false,
            boss = world().boss ~= nil and not world().boss.dead, breakTime = sp.phase == "break" and sp.timer or 0 }
    end
    function me.run()
        local w = world()
        return { kills = w.kos or 0, combo = w.combo or 0, bestCombo = w.bestCombo or 0, nectar = w.nectar or 0,
            nectarEarned = w.nectarEarned or 0, xp = w.xp or 0, time = w.time or 0, mode = w.mode,
            frenzy = w.rewards and w.rewards.frenzy.charge / math.max(1, w.rewards.frenzy.max) or 0,
            frenzyActive = w.rewards and w.rewards.frenzy.active ~= nil or false,
            stage = w.stage and w.stage.id, daylight = U(function() return w:daylight() end) }
    end
    -- ants with more detail: { x, y, vx, vy, hp, maxHp, id, boss, elite, queen, flying, held,
    --   dist, angle, facingMe } sorted nearest first. opts: radius, max, x, y, filter = fn(e) -> bool
    function me.enemiesNear(opts)
        opts = type(opts) == "table" and opts or { radius = opts }
        local filter = type(opts.filter) == "function" and opts.filter
        local list = U(function()
            local out = {}
            local cx0, cy0 = num(opts.x, player.x, -1e5, 1e5), num(opts.y, player.y, -1e5, 1e5)
            for _, e in ipairs(Combat.collect(world(), cx0, cy0, num(opts.radius, 120, 1, 3000))) do
                local dx, dy = e.x - player.x, e.y - player.y
                out[#out + 1] = { x = e.x, y = e.y, vx = e.vx or 0, vy = e.vy or 0, hp = e.hp, maxHp = e.maxHp, id = e.def.id,
                    name = e.def.name, boss = e.def.boss and true or false, elite = e.elite and true or false,
                    queen = e.def.queen and true or false, flying = (e.z or 0) > 4, held = e.held and true or false,
                    hazard = e.def.hazard and true or false, dist = math.sqrt(dx * dx + dy * dy), angle = math.atan2(dy, dx),
                    poisoned = (e.poisonT or 0) > 0, slowed = (e.slowT or 0) > 0, stunned = (e.stunT or 0) > 0, uid = e.uid }
            end
            table.sort(out, function(a, b2) return a.dist < b2.dist end)
            return out
        end)
        local max = math.floor(num(opts.max, 60, 1, 400))
        local out = {}
        for _, e in ipairs(list) do
            if #out >= max then break end
            if not filter or filter(e) then out[#out + 1] = e end
        end
        return out
    end
    -- props (pebbles, twigs, leaves, acorns...) with detail, nearest first
    function me.propsNear(radius)
        return U(function()
            local out, props = {}, world().props
            if not props then return out end
            local Props = require("src.game.props")
            for _, o in ipairs(props.list) do
                if not o.dead then
                    local d = Props.distance(o, player.x, player.y)
                    if d <= num(radius, 120, 1, 3000) then
                        out[#out + 1] = { x = o.x, y = o.y, id = o.def.id, size = o.r, dist = d, pushable = o.isProp and true or false, held = o.held and true or false, mass = o.mass, angle = math.atan2(o.y - player.y, o.x - player.x) }
                    end
                end
            end
            table.sort(out, function(a, b2) return a.dist < b2.dist end)
            while #out > 60 do table.remove(out) end
            return out
        end)
    end
    -- nectar beads and pickups on the floor near the bug
    function me.pickupsNear(radius)
        return U(function()
            local out = {}
            local beads = world().beads
            local r2 = num(radius, 150, 1, 3000) ^ 2
            for _, list in ipairs({ beads and beads.beads or {}, beads and beads.pickups or {} }) do
                for _, o in ipairs(list) do
                    if #out >= 60 then break end
                    if o.x and (o.x - player.x) ^ 2 + (o.y - player.y) ^ 2 <= r2 and not o.dead then
                        out[#out + 1] = { x = o.x, y = o.y, value = o.value, id = o.id or (o.def and o.def.id) or "nectar" }
                    end
                end
            end
            return out
        end)
    end

    -- input -----------------------------------------------------------------------------------
    local function liveInput() local w = world() return not (w.flags.demo or w.pilot) end
    -- is a game action held? ("attack", "secondary", "dash", "ability", "stance", "frenzy", "move_up"...)
    function me.action(id)
        local pilot = world().pilot
        if pilot then return pilot.down[id] == true end
        if not liveInput() or type(id) ~= "string" then return false end
        local Input = require("src.core.input")
        local ok, d = pcall(Input.down, id)
        return ok and d or false
    end
    function me.actionPressed(id)
        local pilot = world().pilot
        if pilot then return pilot.pressed[id] == true end
        if not liveInput() or type(id) ~= "string" then return false end
        return require("src.core.input").pressed(id) and true or false
    end
    -- a raw key ("1", "e", "lctrl", "mouse3"...)
    local function rawDown(k)
        local b = k:match("^mouse(%d)$")
        if b then return love.mouse.isDown(tonumber(b)) end
        local ok, d = pcall(love.keyboard.isDown, k)
        return ok and d or false
    end
    function me.keyDown(k)
        if not liveInput() or type(k) ~= "string" then return false end
        return rawDown(k)
    end
    function me.keyPressed(k)
        if not liveInput() or type(k) ~= "string" then return false end
        local ks = player.keyState
        if not ks then ks = { now = {}, prev = {} } player.keyState = ks end
        local d = ks.now[k]
        if d == nil then d = rawDown(k) ks.now[k] = d end
        return d and not ks.prev[k]
    end
    -- the walk stick / keys as a world direction (0, 0 when not walking)
    function me.moveInput() return player.moveDirX or 0, player.moveDirY or 0 end

    -- changing the bug ------------------------------------------------------------------------
    -- a stat change for some seconds (or for good: seconds = 0 / nil): add and mult (0.2 = +20%)
    function me.buff(stat, add, mult, seconds, key)
        if type(stat) ~= "string" or not require("src.game.stats").byId[stat] then return false end
        return U(function()
            local k = "script_" .. (type(key) == "string" and key:sub(1, 24) or stat)
            local secs = num(seconds, 0, 0, 3600)
            if secs > 0 then
                require("src.game.itemfx").buff(player, k, stat, num(add, 0, -1e4, 1e4), num(mult, 0, -10, 100), secs)
            else
                player.stats:removeSource(k)
                player.stats:addModifier(k, stat, num(add, 0, -1e4, 1e4), num(mult, 0, -10, 100))
                player.stats:recompute()
            end
            return true
        end)
    end
    function me.unbuff(key)
        if type(key) ~= "string" then return end
        return U(function()
            player.stats:removeSource("script_" .. key:sub(1, 24))
            player.stats:removeSource("buff:script_" .. key:sub(1, 24))
            player.stats:recompute()
        end)
    end
    function me.teleport(x, y)
        return U(function()
            local S, r = world().size, player.radius
            player.x = util.clamp(num(x, player.x, -1e5, 1e5), r, S - r)
            player.y = util.clamp(num(y, player.y, -1e5, 1e5), r, S - r)
        end)
    end
    -- a shove on the bug itself (like being knocked back): along (dx, dy) with force
    function me.knock(dx, dy, force)
        return U(function() player:knock(num(dx, 0, -1e3, 1e3), num(dy, 0, -1e3, 1e3), num(force, 200, 0, 3000)) end)
    end
    function me.face(x, y)
        return U(function()
            local nx, ny, l = util.normalize(num(x, player.x, -1e5, 1e5) - player.x, num(y, player.y, -1e5, 1e5) - player.y)
            if l > 0 then
                player.aimX, player.aimY = nx, ny
                cx.ax, cx.ay = nx, ny
                player.wangle = math.atan2(ny, nx)
            end
        end)
    end
    function me.damage(n)
        return U(function() player:hurt(num(n, 1, 0, 1e5), { x = player.x, y = player.y, script = true }) end)
    end
    function me.setHp(n)
        return U(function() player.hp = math.max(0.5, math.min(player.stats:get("maxHp"), num(n, player.hp, 0, 1e6))) end)
    end
    function me.revive(frac) player.reviveTo = num(frac, 0.25, 0.01, 1) return true end
    function me.parry(seconds) player.parryT = num(seconds, 0.25, 0, 3) end
    function me.giveItem(id, n)
        return U(function()
            local Content = require("src.content")
            if not Content.items:get(tostring(id)) then return false end
            world():giveItem(tostring(id), math.floor(num(n, 1, 1, 20)))
            return true
        end)
    end
    function me.addNectar(n) return U(function() world():addNectar(math.floor(num(n, 1, 0, 1e5)), player.x, player.y) end) end
    function me.addXP(n) return U(function() world():grantXP(num(n, 1, 0, 1e5), player.x, player.y, true) end) end
    function me.magnet() return U(function() world():magnetNectar() end) end
    function me.frenzy(amount)
        return U(function()
            local fr = world().rewards and world().rewards.frenzy
            if fr then fr:add(num(amount, 0.1, -1, 1) * fr.max, true) end
        end)
    end

    -- resources (ammo...) ---------------------------------------------------------------------
    function me.res(name)
        local r = type(name) == "string" and API.res(player, name)
        if not r then return nil end
        return r.cur, r.max
    end
    me.ammo = me.res
    function me.spend(name, n)
        local r = type(name) == "string" and API.res(player, name)
        if not r then return false end
        n = num(n, 1, 0, 1e6)
        if r.reloadT or r.cur < n then return false end
        local old = r.cur
        r.cur, r.delay = r.cur - n, r.def.regenDelay
        API.resChanged(player, r, old)
        return true
    end
    function me.gain(name, n)
        local r = type(name) == "string" and API.res(player, name)
        if not r then return false end
        r.cur = math.min(r.max, r.cur + num(n, 1, -1e6, 1e6))
        if r.cur < r.def.min then r.cur = r.def.min end
        return true
    end
    function me.setRes(name, v, max)
        local r = type(name) == "string" and API.res(player, name)
        if not r then return false end
        if max then r.max = num(max, r.max, 0.01, 1e6) end
        r.cur = math.max(r.def.min, math.min(r.max, num(v, r.cur, -1e6, 1e6)))
        return true
    end
    function me.reload(name, seconds)
        local r = type(name) == "string" and API.res(player, name)
        if not r or r.reloadT then return false end
        r.reloadT = num(seconds, r.def.reload or 1, 0, 60)
        return true
    end
    function me.reloading(name)
        local r = type(name) == "string" and API.res(player, name)
        return r and r.reloadT ~= nil or false
    end

    -- stances, evolution, events ---------------------------------------------------------------
    function me.stance(n)
        if n == nil then local s = API.stance(player) return s and s.name, player.stanceIndex or 1 end
        return U(function() return API.setStance(player, n) end)
    end
    function me.evolve(n)
        return U(function() return require("src.game.bugextras").evolve(player, n) end)
    end
    function me.emit(name, data)
        if type(name) ~= "string" or not name:match("^on%u") then return end
        local ev = {}
        if type(data) == "table" then for k, v in pairs(data) do if type(v) ~= "function" then ev[k] = v end end end
        return API.fire(player, name, ev)
    end
    function me.cooldownOf(i) local s = player.abil and player.abil[math.floor(num(i, 1, 1, 6))] return s and s.cd or 0 end
    function me.resetCooldown(which)
        if which == "attack" and player.attack then player.attack.timer = 0
        elseif which == "secondary" and player.secondary then player.secondary.timer = 0
        elseif tonumber(which) and player.abil and player.abil[tonumber(which)] then player.abil[tonumber(which)].cd = 0 end
    end

    -- grab / throw props and ants -------------------------------------------------------------
    function me.held()
        local Grab = require("src.game.grab")
        local h = player.scriptHeld
        if not (h and Grab.valid(h)) then return nil end
        local e = h.e
        return { id = e.def and e.def.id, prop = e.isProp and true or false, hp = e.hp, maxHp = e.maxHp, x = e.x, y = e.y }
    end
    function me.drop()
        return U(function()
            local h = player.scriptHeld
            player.scriptHeld = nil
            if h then require("src.game.grab").release(h) return true end
            return false
        end)
    end

    -- full access (Settings > Developer > Full Lua Access): the real tables, no safety net
    if API.fullAccess() then
        me.engine = { player = player, world = player.world, require = require, love = love, _G = _G }
    end
end

-- Plain fields on `me`, set before every call (kept cheap: this runs for every hit).
function API.refresh(me, player)
    local w = player.world
    me.vx, me.vy = player.vx or 0, player.vy or 0
    me.speedNow = math.sqrt(me.vx * me.vx + me.vy * me.vy)
    me.facing = player.wangle or 0
    me.facingX, me.facingY = math.cos(me.facing), math.sin(me.facing)
    me.z = player.z or 0
    me.dashing = (player.dashT or 0) > 0
    me.holdMode = player.holdMode ~= nil or (player.stamina and player.stamina.on) or false
    me.radius, me.scale = player.radius, player.def.scale or 1
    me.kills = player.killsTotal or 0
    me.spree = player.spree or 0
    me.combo = w and w.combo or 0
    me.nectar = w and w.nectar or 0
    me.formIndex = player.formIndex or 1
    me.stage = player.evoStage or 0
    me.stanceIndex = player.stanceIndex or 1
    local b = player.def.baseDef or player.def
    local st = b.stances and b.stances[me.stanceIndex]
    me.stanceName = st and st.name or nil
    me.xp = player.skills and player.skills.xp or 0
    me.hpFrac = me.hp and me.maxHp and me.maxHp > 0 and me.hp / me.maxHp or 1
    me.dead = player.dead and true or false
    me.mode = w and w.mode or "menu"
end

-- The ward that me.block and me.parry use (scriptmoves installs the block one).
function API.installWard(player) SM().installWard(player) end

return API
