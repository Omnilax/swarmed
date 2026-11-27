-- Skill trees. Every kill gives XP (World:grantXP); XP fills levels and every level opens a
-- level-up card pick (src/game/levelups.lua) plus one skill point. Cards are stat boosts only:
-- SKIPPING a pick banks an extra skill point, so every level is a boost now or more tree. (With the
-- "levelUps" run rule on "points", every level is simply a point.) Points buy nodes in the
-- character's own tree (content/skilltrees/<character>.lua, schema in content/skilltrees/_template.lua)
-- plus a 4th "kin" branch shared by its lineage (content/skillbranches), capped by a signature
-- node only that bug has. Trees cost far more points than a run can earn and forks are
-- either/or, so every run builds the bug a different way.
--
-- A node can:
--   * change the bug's stats (stats / statsMult, like items),
--   * change its moves' params (attack / secondary / dash = { param = mod }),
--   * echo a move (it fires again a beat later), fan it (extra copies at angles),
--     empower every Nth use of it, make thrown ants land harder (throw),
--   * run procs on the same triggers as items (onHit, onKill, onHurt, onDash, ...) plus
--     onAttack, onSpecial, onDashEnd and onBlock.
-- Player:setCharacter makes player.skills; Skills:apply rebuilds params and stats after a buy.
local Audio = require("src.core.audio")
local util = require("src.core.util")

local Skills = {}
Skills.__index = Skills

Skills.MOVES = { "attack", "secondary", "dash" }
Skills.TIER_COST = { 1, 1, 2, 2, 3, 3 }    -- default point cost per rank, by tier

-- XP to go from level-1 to level. Every level is a level-up card pick (src/game/levelups.lua;
-- skipping it banks a skill point), or straight a skill point with the "levelUps" run rule on "points". The curve is in
-- src/config/levelups.lua: about one level a wave, a 15-wave run reaches ~level 15.
function Skills.xpFor(level)
    return require("src.game.levelups").xpFor(level)
end

local EMPTY = {}

----------------------------------------------------------------------------------------------
-- Tree definitions

-- A mod written in a tree: number = add, true/string = set, or { add, mul, set, base }.
local function normMod(m)
    if type(m) == "number" then return { add = m } end
    if type(m) ~= "table" then return { set = m } end
    return m
end

-- Fills in defaults (cost, requires, fork exclusions) and checks a tree. Called by the registry.
function Skills.validateTree(def)
    local Stats = require("src.game.stats")
    def.nodes = {}
    if type(def.branches) ~= "table" or #def.branches == 0 then return false, "needs at least one branch" end
    for bi, br in ipairs(def.branches) do
        if not br.name then return false, "branch #" .. bi .. " needs a name" end
        br.nodes = br.nodes or {}
        br.index = bi
        local byTier = {}
        for _, n in ipairs(br.nodes) do
            if not n.id or not n.name then return false, "every node needs an id and a name (branch '" .. br.name .. "')" end
            if def.nodes[n.id] then return false, "duplicate node id '" .. n.id .. "'" end
            def.nodes[n.id] = n
            n.branch = bi
            n.tier = n.tier or 1
            n.col = n.col or 0
            n.ranks = n.ranks or 1
            n.cost = n.cost or Skills.TIER_COST[n.tier] or 3
            n.desc = n.desc or ""
            byTier[n.tier] = byTier[n.tier] or {}
            table.insert(byTier[n.tier], n)
            for _, field in ipairs({ "stats", "statsMult" }) do
                for id in pairs(n[field] or EMPTY) do
                    if not Stats.byId[id] then return false, "node '" .. n.id .. "': unknown stat '" .. id .. "'" end
                end
            end
            for _, mv in ipairs(Skills.MOVES) do
                for k, m in pairs(n[mv] or EMPTY) do n[mv][k] = normMod(m) end
            end
            if n.empower then
                for k, m in pairs(n.empower.mods or EMPTY) do n.empower.mods[k] = normMod(m) end
            end
            for i, p in ipairs(n.procs or EMPTY) do
                if not p.trigger or not p.effect then return false, "node '" .. n.id .. "' proc #" .. i .. " needs trigger and effect" end
            end
        end
        for tier, list in pairs(byTier) do
            for _, n in ipairs(list) do
                -- by default a node needs any node one tier down in its branch
                if n.requires == nil then
                    n.requires = {}
                    for _, o in ipairs(byTier[tier - 1] or EMPTY) do n.requires[#n.requires + 1] = o.id end
                end
                -- nodes sharing a tier are a fork: taking one locks the others (fork = false opts out)
                n.excludes = n.excludes or {}
                if n.fork ~= false and #list > 1 then
                    for _, o in ipairs(list) do
                        if o ~= n and o.fork ~= false then n.excludes[#n.excludes + 1] = o.id end
                    end
                end
            end
        end
    end
    for id, n in pairs(def.nodes) do
        for _, r in ipairs(n.requires) do
            if not def.nodes[r] then return false, "node '" .. id .. "' requires missing node '" .. r .. "'" end
        end
        for _, r in ipairs(n.excludes) do
            if not def.nodes[r] then return false, "node '" .. id .. "' excludes missing node '" .. r .. "'" end
        end
    end
    return true
end

-- The kin branch for a character: the content/skillbranches entry sharing one of its tags with
-- the highest priority (an entry with no tags fits every bug, at its priority).
function Skills.kinFor(charDef)
    local Content = require("src.content")
    if not (charDef and Content.skillbranches) then return nil end
    local tags = {}
    for _, t in ipairs(charDef.tags or EMPTY) do tags[t] = true end
    local best
    for _, b in ipairs(Content.skillbranches:all()) do
        local fits = #b.tags == 0
        for _, t in ipairs(b.tags) do if tags[t] then fits = true end end
        if fits and (not best or b.priority > best.priority) then best = b end
    end
    return best
end

-- Called before a tree is validated: appends its bug's kin branch (a copy, so trees never share
-- node tables) and the tree's own `signature` node on top of it (tier 5 by default). A tree can
-- opt out with `kin = false`, or name a kin branch by id with `kin = "<id>"`.
function Skills.attachKin(def, charDef)
    if def.kin == false or def.kinAttached then return end
    local Content = require("src.content")
    local kin = type(def.kin) == "string" and Content.skillbranches:get(def.kin) or Skills.kinFor(charDef)
    if not kin and not def.signature then return end
    local br = { name = kin and kin.name or "Signature", color = kin and kin.color or { 1, 0.85, 0.4 },
        blurb = kin and kin.blurb or "", kin = kin and kin.id, nodes = {} }
    for _, n in ipairs(kin and kin.nodes or EMPTY) do br.nodes[#br.nodes + 1] = Skills.copy(n) end
    local sig = def.signature
    if sig then
        local topTier = 0
        for _, n in ipairs(br.nodes) do topTier = math.max(topTier, n.tier or 1) end
        sig.tier = sig.tier or topTier + 1
        sig.cost = sig.cost or 3
        sig.signature = true
        br.nodes[#br.nodes + 1] = sig
    end
    def.branches[#def.branches + 1] = br
    def.kinAttached = true
end

-- Points spent in one branch (the tree screen shows it under the branch's name).
function Skills:spentIn(bi)
    local n = 0
    local br = self.tree and self.tree.branches[bi]
    for _, node in ipairs(br and br.nodes or EMPTY) do n = n + self:rank(node.id) * node.cost end
    return n
end

function Skills.treeFor(charId)
    local Content = require("src.content")
    -- a custom bug can borrow a built-in bug's tree (skillTree = "mantis")
    local c = Content.characters:get(charId)
    if c and c.custom then
        if c.ownTree then return c.ownTree end      -- its own, written in its script
        if not c.skillTree then
            -- a ready-made tree (src/config/presettrees.lua), made once per bug
            if not c._preset then c._preset = require("src.config.presettrees").make(c.presetTree or "brawler", c) end
            return c._preset
        end
        charId = c.skillTree
    end
    for _, t in ipairs(Content.skilltrees:all()) do
        if t.character == charId then return t end
    end
end

----------------------------------------------------------------------------------------------
-- Params

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepCopy(v) end
    return o
end
Skills.copy = deepCopy

-- Apply accumulated mods { ["key"] or ["key.1"] = { add, mul, set, base } } to a params table.
local function applyMods(params, mods)
    for key, m in pairs(mods) do
        local t, k = params, key
        local dot = key:find(".", 1, true)
        if dot then
            local head = key:sub(1, dot - 1)
            if type(params[head]) ~= "table" then params[head] = {} end
            t, k = params[head], tonumber(key:sub(dot + 1)) or key:sub(dot + 1)
        end
        if m.set ~= nil then
            t[k] = m.set
        else
            local v = t[k]
            if type(v) ~= "number" then v = m.base or 0 end
            t[k] = (v + (m.add or 0)) * (1 + (m.mul or 0))
        end
    end
    return params
end

-- Sum one node's mods (times its rank) into acc.
local function addMods(acc, mods, rank)
    for key, m in pairs(mods) do
        local a = acc[key]
        if not a then a = {}; acc[key] = a end
        if m.set ~= nil then a.set = m.set end
        if m.add then a.add = (a.add or 0) + m.add * rank end
        if m.mul then a.mul = (a.mul or 0) + m.mul * rank end
        if m.base then a.base = m.base end
    end
end

-- A copy of params with its damage fields multiplied (echoes and fans hit softer).
local DAMAGE_KEYS = { "damage", "ram", "bite" }
function Skills.scaled(params, mult)
    local q = {}
    for k, v in pairs(params) do q[k] = v end
    if mult and mult ~= 1 then
        for _, k in ipairs(DAMAGE_KEYS) do
            if type(q[k]) == "number" then q[k] = q[k] * mult end
        end
    end
    return q
end

----------------------------------------------------------------------------------------------
-- A player's progress

-- xp: carried over when the sandbox swaps characters (points are refunded).
function Skills.new(player, xp)
    local self = setmetatable({ player = player, xp = 0, into = 0, level = 0, points = 0, spent = 0,
        ranks = {}, counters = {}, cds = {}, flashT = 0 }, Skills)
    self.tree = Skills.treeFor(player.def.id)
    self.toNext = Skills.xpFor(1)
    if xp and xp > 0 then self:gainXP(xp, true) end
    return self
end

-- Level-up cards instead of points? (Real runs, unless the "levelUps" run rule says points.)
function Skills:cardsMode()
    local w = self.player.world
    return w and w.levelups and w.levelups:enabled() or false
end

-- silent: XP handed back quietly (resumed runs, practice, sandbox swaps). Silent levels always
-- give skill points, so nothing is lost when no card pick can be shown. In card mode a level
-- gives a point too, and skipping its card pick banks an extra one (LevelUps:take a "point" card).
function Skills:gainXP(n, silent)
    self.xp = self.xp + n
    self.into = self.into + n
    while self.into >= self.toNext do
        self.into = self.into - self.toNext
        self.level = self.level + 1
        self.toNext = Skills.xpFor(self.level + 1)
        local p = self.player
        local lu = p.world and p.world.levelups
        if not silent and self:cardsMode() then
            -- every level is a skill point AND a card pick; skipping the pick banks one more
            self.points = self.points + 1
            lu:onLevel(self.level)
            self.flashT = 2.5
            lu:fanfare(p, "LEVEL UP!")
        else
            self.points = self.points + 1
            if not silent then
                self.flashT = 2.5
                if lu then lu:fanfare(p, "SKILL POINT!")
                elseif p.world and not p.world.flags.demo then Audio.play("ui_confirm", { pitch = 1.35 }) end
            end
        end
    end
end

function Skills:rank(id) return self.ranks[id] or 0 end

-- "maxed" | "available" | "poor" (not enough points) | "locked" (needs an earlier node) |
-- "excluded" (the other side of a fork was taken) | "owned" (some ranks, more to buy but locked?)
function Skills:status(node)
    local r = self:rank(node.id)
    if r >= node.ranks then return "maxed" end
    for _, x in ipairs(node.excludes) do
        if self:rank(x) > 0 then return "excluded" end
    end
    if #node.requires > 0 then
        local ok = false
        for _, q in ipairs(node.requires) do
            if self:rank(q) > 0 then ok = true break end
        end
        if not ok then return "locked" end
    end
    if self.points < node.cost then return "poor" end
    return "available"
end

function Skills:buy(id)
    local node = self.tree and self.tree.nodes[id]
    if not node or self:status(node) ~= "available" then return false end
    self.ranks[id] = self:rank(id) + 1
    self.points = self.points - node.cost
    self.spent = self.spent + node.cost
    self:apply()
    return true
end

-- Total points the whole tree costs (for the "x / y" readout).
function Skills:treeCost()
    local n = 0
    for _, node in pairs(self.tree and self.tree.nodes or EMPTY) do n = n + node.cost * node.ranks end
    return n
end

-- Rebuild the player's stats and move params from the character def plus every owned node.
function Skills:apply()
    local p = self.player
    local def = p.def
    p.stats:removeSource("skill")
    local mods = { attack = {}, secondary = {}, dash = {} }
    self.echoes, self.fans, self.empowers, self.throws, self.procs = {}, {}, {}, {}, {}
    local owned = {}
    for id, r in pairs(self.ranks) do
        if r > 0 and self.tree and self.tree.nodes[id] then owned[#owned + 1] = self.tree.nodes[id] end
    end
    table.sort(owned, function(a, b) return a.id < b.id end)
    for _, n in ipairs(owned) do
        local r = self.ranks[n.id]
        for stat, v in pairs(n.stats or EMPTY) do p.stats:addModifier("skill", stat, v * r, 0) end
        for stat, v in pairs(n.statsMult or EMPTY) do p.stats:addModifier("skill", stat, 0, v * r) end
        for _, mv in ipairs(Skills.MOVES) do
            if n[mv] then addMods(mods[mv], n[mv], r) end
        end
        local function list(t, x) if x then x.rank = r; t[x.move or "attack"] = t[x.move or "attack"] or {}; table.insert(t[x.move or "attack"], x) end end
        list(self.echoes, n.echo)
        list(self.fans, n.fan)
        list(self.empowers, n.empower)
        if n.throw then self.throws[#self.throws + 1] = { t = n.throw, rank = r } end
        for _, pr in ipairs(n.procs or EMPTY) do
            self.procs[pr.trigger] = self.procs[pr.trigger] or {}
            table.insert(self.procs[pr.trigger], { proc = pr, rank = r, node = n })
        end
    end
    -- a character's own innate procs (def.procs: velvet worm's bursting ants), always on
    for _, pr in ipairs(def.procs or EMPTY) do
        self.procs[pr.trigger] = self.procs[pr.trigger] or {}
        table.insert(self.procs[pr.trigger], { proc = pr, rank = 1 })
    end
    p.attack.params = applyMods(deepCopy(def.attack), mods.attack)
    if p.secondary and def.secondary then p.secondary.params = applyMods(deepCopy(def.secondary), mods.secondary) end
    p.dashParams = applyMods(deepCopy(def.dash or { type = "dash" }), mods.dash)
    if p.hp then p.hp = math.min(p.hp, p.stats:get("maxHp")) end
end

----------------------------------------------------------------------------------------------
-- Hooks (called by Player:update around each attack, special and dash)

local function moveSlot(p, move) return move == "attack" and p.attack or p.secondary end

-- Before a move fires: counts uses and returns the params to fire with (empowered every Nth).
function Skills:before(move, params)
    self.player.curMove = move
    local list = self.empowers and self.empowers[move]
    if not list then return params end
    self.counters[move] = (self.counters[move] or 0) + 1
    for _, e in ipairs(list) do
        if self.counters[move] % e.every == 0 then
            params = applyMods(deepCopy(params), e.mods or EMPTY)
            local p = self.player
            if e.text then p.world:floatText(p.x, p.y - 8, e.text, e.color or { 1, 0.85, 0.4 }, true) end
            if e.shake then p.world.camera:shake(e.shake) end
        end
    end
    return params
end

-- After a move fired: echoes, fans and the onAttack / onSpecial procs.
function Skills:after(move, ax, ay, px, py, params)
    local p = self.player
    local world = p.world
    if not self.replaying then
        local slot = moveSlot(p, move)
        for _, f in ipairs(self.fans and self.fans[move] or EMPTY) do
            local n = (f.count or 2) + (f.perRank or 0) * (f.rank - 1)
            local q = Skills.scaled(params, f.mult or 0.6)
            self.replaying = true
            for i = 1, n do
                local side = (i % 2 == 1) and 1 or -1
                local a = side * math.ceil(i / 2) * (f.spread or 0.4)
                local c, s = math.cos(a), math.sin(a)
                local fx, fy = ax * c - ay * s, ax * s + ay * c
                local qx, qy
                if px then
                    local dx, dy = px - p.x, py - p.y
                    qx, qy = p.x + dx * c - dy * s, p.y + dx * s + dy * c
                end
                slot.type.fire(p, world, fx, fy, q, qx, qy)
            end
            self.replaying = false
        end
        local seq = 0     -- several echoes of one move go off one after another
        for _, e in ipairs(self.echoes and self.echoes[move] or EMPTY) do
            if not e.chance or love.math.random() < e.chance * (e.rank or 1) then
                local q = Skills.scaled(params, e.mult or 0.6)
                local delay = e.delay or 0.15
                if delay == "dash" then delay = p.dashT + 0.06 end
                local times = (e.times or 1) + (e.perRank or 0) * (e.rank - 1)
                for _ = 1, times do
                    seq = seq + 1
                    p:after(delay * seq, function(pl, w)
                        if pl.dead then return end
                        local sx, sy = pl:pointer()
                        local bx, by = pl.aimX, pl.aimY
                        if e.sameAim then bx, by = ax, ay end
                        self.replaying = true
                        pl.curMove = move
                        moveSlot(pl, move).type.fire(pl, w, bx, by, q, sx, sy)
                        self.replaying = false
                        pl.lungeT = 0.18
                        if e.text then w:floatText(pl.x, pl.y - 8, e.text, e.color or { 0.8, 0.95, 1 }, false) end
                    end)
                end
            end
        end
        p.inventory:trigger(move == "attack" and "onAttack" or "onSpecial", { world = world, player = p, move = move,
            ax = ax, ay = ay, px = px, py = py, params = params, procDepth = 0 })
    end
    p.curMove = nil
end

-- Grab.fling asks here: thrown ants land with bigger blasts (and whatever else nodes add).
function Skills:throwOpts(opts)
    if not self.throws or #self.throws == 0 then return opts end
    local o = {}
    for k, v in pairs(opts) do o[k] = v end
    local landFns = {}
    if o.onLand then landFns[1] = o.onLand end
    for _, th in ipairs(self.throws) do
        local t, r = th.t, th.rank
        o.landDamage = ((o.landDamage or 0) + (t.landDamage or 0) * r) * (1 + (t.landMul or 0) * r)
        o.radius = (o.radius or 26) * (1 + (t.radiusMul or 0) * r)
        o.damage = (o.damage or 8) * (1 + (t.bowlMul or 0) * r)
        if t.onLand then landFns[#landFns + 1] = function(w, x, y) t.onLand(w, x, y, r, o) end end
    end
    if #landFns > 0 then
        o.onLand = function(w, x, y) for _, f in ipairs(landFns) do f(w, x, y) end end
    end
    return o
end

-- What the player is doing right now, for procs that only answer one move.
function Skills:moveNow()
    local p = self.player
    if p.curMove then return p.curMove end
    if self.dashing and (p.dashT > 0 or p.grapple or p.holdMode) then return "dash" end
end

-- Runs this tree's procs for a trigger (Inventory:trigger forwards every trigger here).
function Skills:trigger(name, ctx)
    if name == "onTick" then
        local p = self.player
        if self.flashT > 0 then self.flashT = self.flashT - ctx.dt end
        if self.dashing and p.dashT <= 0 and not p.grapple and not p.holdMode then
            self.dashing = false
            local ectx = { world = ctx.world, player = p, procDepth = 0 }
            self:trigger("onDashEnd", ectx)
            if p.def.custom then require("src.game.scriptmoves").event(p, "onDashEnd", ectx) end
        end
    elseif name == "onDash" then
        self.dashing = true
    end
    local list = self.procs and self.procs[name]
    if not list then return end
    local now = self.player.world.time
    for _, a in ipairs(list) do
        local pr = a.proc
        if (not pr.move or pr.move == self:moveNow()) and (not pr.cooldown or (self.cds[pr] or -1) <= now)
            and (not pr.condition or pr.condition(ctx, a.rank)) then
            local chance = pr.chance
            if type(chance) == "function" then chance = chance(a.rank) end
            if chance == nil or love.math.random() < chance then
                if pr.cooldown then self.cds[pr] = now + pr.cooldown end
                pr.effect(ctx, a.rank, self)
            end
        end
    end
end

----------------------------------------------------------------------------------------------
-- Effect helpers for tree files (Skills.fx). Damage passes procDepth + 1 so procs can't loop.

local fx = {}
Skills.fx = fx

local function depth(ctx) return { procDepth = ((ctx and ctx.procDepth) or 0) + 1 } end

local function merge(a, b)
    for k, v in pairs(b or EMPTY) do a[k] = v end
    return a
end

-- A blast with a ring, shake and boom.
function fx.explode(ctx, x, y, r, dmg, color, opts)
    local Combat = require("src.game.combat")
    r = r * (1 + ctx.player.stats:get("area") / 100)
    return Combat.explode(ctx.world, x, y, r, dmg, merge(merge(depth(ctx), { color = color }), opts))
end

-- A quiet burst (ring only) hitting everything around a point.
function fx.nova(ctx, x, y, r, dmg, color, opts)
    local Combat = require("src.game.combat")
    r = r * (1 + ctx.player.stats:get("area") / 100)
    ctx.world:addFx({ kind = "ring", x = x, y = y, r = r, life = 0.2, color = color or { 1, 1, 1 } })
    return Combat.area(ctx.world, x, y, r, dmg, merge(merge(depth(ctx), { knockback = 80 }), opts))
end

-- Damage along a line from (x, y) in direction (dx, dy).
function fx.line(ctx, x, y, dx, dy, len, width, dmg, color, opts)
    local Combat = require("src.game.combat")
    local x2, y2 = x + dx * len, y + dy * len
    local hits = Combat.collectLine(ctx.world, x, y, x2, y2, width)
    for _, e in ipairs(hits) do
        Combat.damage(ctx.world, e, dmg, merge(merge(depth(ctx), { knockback = 90, kbx = dx, kby = dy }), opts))
    end
    ctx.world:addFx({ kind = "stab", x = x, y = y, x2 = x2, y2 = y2, w = 3, life = 0.15, color = color or { 1, 1, 1 } })
    return #hits
end

-- Lightning-like jumps from an ant to the next.
function fx.chain(ctx, from, jumps, range, dmg, color, opts)
    local Combat = require("src.game.combat")
    return Combat.chain(ctx.world, from, jumps, range, dmg, merge(merge(depth(ctx), { color = color }), opts))
end

-- Projectiles flying out in a ring (or a cone: opts.angle, opts.spread).
function fx.shards(ctx, x, y, n, dmg, color, opts)
    opts = opts or EMPTY
    local speed, range = opts.speed or 220, opts.range or 80
    for i = 1, n do
        local a
        if opts.angle then a = opts.angle + ((i - 0.5) / n - 0.5) * (opts.spread or 1)
        else a = i / n * math.pi * 2 + love.math.random() * 0.3 end
        ctx.world.hazards:friendlyShot({ x = x, y = y, z = 5, vx = math.cos(a) * speed, vy = math.sin(a) * speed, r = 3,
            damage = dmg, life = range / speed, color = color or { 1, 0.9, 0.6 }, pierce = opts.pierce or 1,
            knockback = opts.knockback or 50, procDepth = ((ctx.procDepth or 0) + 1), slow = opts.slow, poison = opts.poison })
    end
end

-- A damaging patch on the ground (poison and/or slow).
function fx.patch(ctx, x, y, r, life, dps, slow, color)
    require("src.game.itemfx").patch(ctx.world, { x = x, y = y, r = r, life = life, dps = dps, slow = slow, color = color or { 0.6, 1, 0.4 } })
end

-- A temporary stat buff (refreshes when it fires again).
function fx.buff(ctx, key, stat, add, mult, time)
    require("src.game.itemfx").buff(ctx.player, "skill_" .. key, stat, add, mult, time)
end

-- Grab an ant and hurl it (it bowls over ants and crashes down), like the stag beetle's throw.
function fx.fling(ctx, e, dx, dy, dist, opts)
    if not e or e.dead or e.hp <= 0 or e.held or e.def.boss then return end
    local Grab = require("src.game.grab")
    local speed = 400
    Grab.fling(ctx.world, Grab.hold(e), dx * speed, dy * speed, dist / speed,
        merge({ damage = 8, landDamage = 8, radius = 22, height = 12, spin = 18 }, opts))
end

-- Venom on one ant (keeps the stronger dose).
function fx.poison(e, dps, time)
    if e.dead then return end
    e.poisonT = math.max(e.poisonT, time)
    e.poisonDps = math.max(e.poisonDps, dps)
end

-- Slow one ant to `mul` x speed (0 = pinned) for `time` seconds.
function fx.slow(e, mul, time)
    if e.dead then return end
    e.slowMul = math.min(e.slowT > 0 and e.slowMul or 1, mul)
    e.slowT = math.max(e.slowT, time)
end

-- A sticky web on the ground (like the orb weaver's).
function fx.web(ctx, x, y, r, life, slow)
    ctx.world.hazards:addZone({ kind = "web", web = true, x = x, y = y, r = r, life = life or 3, enemySlow = slow or 0.3,
        color = { 0.95, 0.95, 0.9 } })
end

-- Drag every ant within r of (x, y) toward it.
function fx.pull(ctx, x, y, r, force)
    local Combat = require("src.game.combat")
    for _, e in ipairs(Combat.collect(ctx.world, x, y, r)) do
        if not e.held then
            local dx, dy = util.normalize(x - e.x, y - e.y)
            e.kvx, e.kvy = e.kvx + dx * force / e.mass, e.kvy + dy * force / e.mass
        end
    end
end

function fx.heal(ctx, n)
    ctx.player:heal(n)
end

-- A context for helpers called outside a proc (e.g. a throw's landing).
function fx.ctx(world, d)
    return { world = world, player = world.player, procDepth = d or 1 }
end

-- A random live ant near a point.
function fx.near(ctx, x, y, r)
    return require("src.game.itemfx").randomEnemy(ctx.world, x, y, r)
end

-- True on every nth call for this key (signature nodes: "every 4th punch..."). skills is the
-- third argument a proc's effect gets.
function fx.every(skills, key, n)
    local c = (skills.counters[key] or 0) + 1
    skills.counters[key] = c
    return c % n == 0
end

-- Little text over the player.
function fx.say(ctx, text, color)
    local p = ctx.player
    ctx.world:floatText(p.x, p.y - 8, text, color or { 1, 0.9, 0.5 }, false)
end

-- Direction from the player to (x, y), or the aim.
function fx.dir(ctx, x, y)
    local p = ctx.player
    local dx, dy, l = util.normalize(x - p.x, y - p.y)
    if l < 0.5 then return p.aimX, p.aimY end
    return dx, dy
end

return Skills
