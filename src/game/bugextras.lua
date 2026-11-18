-- More things a custom bug can have (Bug Creator round 3, docs/CUSTOM_BUGS.md). All plain data
-- in the script, checked by Extras.build (called from CustomBugs.build):
--
--   hitFx     = { number = "#80ff80", crit = "#ffd040", sparks = { color, count }, sound = "name" }
--   soundPack = { attack, special, dash, hurt, death, kill = "name" | { sound, pitch, volume } | synth }
--   statuses  = { burn = { name, color, time, dps, slow, stun, confuse, charm, weaken, spread, stacks } }
--   pets      = { { name, ai = "hunt" | "guard" | "orbit" | "shooter", count, art, palette, color,
--                   damage, speed, range, rate, status, size } }
--   ultimate  = { name, color, charge, duration, fire = function(me) | blocks, tick, buff }
--   forms     = { { name, attack, secondary, stats, colors, look, art, say } }  (hold Shift: form 2)
--   molt      = { wave = 10, name, attack, secondary, dash, stats, art, look, colors, scale, say }
--   card      = { motto, color = "#hex", frame = "leaf" | "gold" | "bone" | "web" | "plain" }
--   challenges = { { name, goal = "win" | "wave" | "kills" | "nodash" | "nohit" | "fast", n } }
--   anims.idle / anims.death / anims.victory   poses (any anims clip)
--
-- At run time: Extras.tick (pets, statuses, idle pose), Extras.event (molt, kills), applyStatus,
-- setForm, sfx.
local Combat = require("src.game.combat")
local util = require("src.core.util")

local Extras = {}

local function clamp(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then v = default end
    if v == nil then return nil end
    return math.max(lo, math.min(hi, v))
end
local function hex(c, default)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x") then
        local h = util.hex(c:sub(1, 7))
        return { h[1], h[2], h[3] }
    end
    if type(c) == "table" then return { clamp(c[1], 0, 1, 1), clamp(c[2], 0, 1, 1), clamp(c[3], 0, 1, 1) } end
    return default
end
local function text(v, max) return type(v) == "string" and v:gsub("[%c]", " "):sub(1, max) or nil end
Extras.hex = hex

-- built-in sounds a pack may name (src/core/audio.lua)
Extras.SOUNDS = { "boom", "zap", "dash", "hit", "swing", "special", "chime", "drop", "kill", "pickup", "equip", "bell", "hurt" }
local SOUND_SET = {}
for _, s in ipairs(Extras.SOUNDS) do SOUND_SET[s] = true end
Extras.PACK_SLOTS = { "attack", "special", "dash", "hurt", "death", "kill", "hit" }

-- name | { sound = name, pitch, volume } | synth table -> { id, pitch, volume } (synths are
-- added to def.sounds as "pack_<slot>")
local function soundRef(def, slot, v, warns, where)
    local name, pitch, volume = v, 1, 1
    if type(v) == "table" then
        if v.wave or v.freq or v.notes then
            def.sounds = def.sounds or {}
            def.sounds["pack_" .. slot] = Extras.buildSound and Extras.buildSound(v) or nil
            if not def.sounds["pack_" .. slot] then warns[#warns + 1] = where .. ": that sound didn't build" return nil end
            name = "pack_" .. slot
        else
            name = v.sound or v[1]
        end
        pitch, volume = clamp(v.pitch, 0.2, 4, 1), clamp(v.volume, 0, 1, 1)
    end
    if type(name) ~= "string" then return nil end
    if def.sounds and def.sounds[name] then return { id = def.id .. ":" .. name, pitch = pitch, volume = volume } end
    if SOUND_SET[name] then return { id = name, pitch = pitch, volume = volume } end
    warns[#warns + 1] = where .. ": no sound '" .. name .. "' (own sounds, or " .. table.concat(Extras.SOUNDS, ", ") .. ")"
    return nil
end

Extras.FRAMES = { "plain", "leaf", "gold", "bone", "web", "shell" }
local FRAME_SET = {}
for _, f in ipairs(Extras.FRAMES) do FRAME_SET[f] = true end

Extras.PET_AI = { "hunt", "guard", "orbit", "shooter" }
local AI_SET = { hunt = true, guard = true, orbit = true, shooter = true }

Extras.GOALS = {
    win = { text = function(n) return "Win a run" end },
    wave = { text = function(n) return "Reach wave " .. n end, n = 15 },
    kills = { text = function(n) return "Defeat " .. n .. " ants in one run" end, n = 500 },
    nodash = { text = function(n) return "Reach wave " .. n .. " without dashing" end, n = 10 },
    nohit = { text = function(n) return "Clear a whole wave without getting hit" end },
    fast = { text = function(n) return "Win in under " .. n .. " minutes" end, n = 20 },
    ultimate = { text = function(n) return "Use the ultimate " .. n .. " times in a run" end, n = 5 },
}
Extras.DEFAULT_CHALLENGES = { { goal = "wave", n = 5 }, { goal = "wave", n = 15 }, { goal = "win" }, { goal = "nohit" },
    { goal = "nodash", n = 10 }, { goal = "kills", n = 1000 } }

-- A small pixel picture (pets): rows of palette letters -> clean rows, or nil.
local function pixelRows(rows, pal, maxW, maxH)
    if type(rows) ~= "table" or #rows == 0 or #rows > maxH then return nil end
    local out = {}
    for i, r in ipairs(rows) do
        if type(r) ~= "string" or #r > maxW then return nil end
        for c = 1, #r do
            local ch = r:sub(c, c)
            if ch ~= "." and ch ~= " " and not pal[ch] then return nil end
        end
        out[i] = r
    end
    return out
end

function Extras.build(raw, def, errs, warns, rebuild)
    -- hit look
    if type(raw.hitFx) == "table" then
        local h = raw.hitFx
        local sp = type(h.sparks) == "table" and h.sparks or nil
        def.hitLook = { number = hex(h.number), crit = hex(h.crit), sparkColor = sp and hex(sp.color or sp[1]),
            sparkCount = sp and math.floor(clamp(sp.count or sp[2], 0, 30, 3)) or nil }
        if h.sound ~= nil then
            local r = soundRef(def, "hit", h.sound, warns, "hitFx.sound")
            def.hitLook.sound = r and r.id
        end
    elseif raw.hitFx ~= nil then warns[#warns + 1] = "hitFx must be a table" end
    -- sound pack
    if type(raw.soundPack) == "table" then
        def.soundPack = {}
        for _, slot in ipairs(Extras.PACK_SLOTS) do
            if raw.soundPack[slot] ~= nil then def.soundPack[slot] = soundRef(def, slot, raw.soundPack[slot], warns, "soundPack." .. slot) end
        end
        if def.soundPack.hit then
            def.hitLook = def.hitLook or {}
            def.hitLook.sound = def.hitLook.sound or def.soundPack.hit.id
        end
        if not next(def.soundPack) then def.soundPack = nil end
    end
    -- own status effects
    if type(raw.statuses) == "table" then
        def.statuses = {}
        local n = 0
        for id, s in pairs(raw.statuses) do
            n = n + 1
            if n > 8 then warns[#warns + 1] = "statuses: 8 at most" break end
            if type(id) ~= "string" or not id:match("^[%a_][%w_]*$") or type(s) ~= "table" then
                warns[#warns + 1] = "statuses." .. tostring(id) .. " dropped (statuses = { burn = { dps = 4 } })"
            else
                def.statuses[id] = { id = id, name = text(s.name, 16) or id, color = hex(s.color, { 1, 0.5, 0.3 }),
                    time = clamp(s.time, 0.2, 30, 3), dps = clamp(s.dps, 0, 200, 0), slow = s.slow and clamp(s.slow, 0.05, 1, 0.6),
                    stun = s.stun == true or nil, confuse = s.confuse == true or nil, charm = s.charm == true or nil,
                    charmDamage = clamp(s.charmDamage, 0, 100, 5),
                    weaken = s.weaken and clamp(s.weaken, 0, 1, 0.5), spread = s.spread and clamp(s.spread, 4, 150, 30),
                    stacks = math.floor(clamp(s.stacks, 1, 10, 1)), vulnerable = s.vulnerable and clamp(s.vulnerable, 1, 3, 1.3) }
            end
        end
        if not next(def.statuses) then def.statuses = nil end
    end
    -- pets
    if type(raw.pets) == "table" then
        def.pets = {}
        for i, p in ipairs(raw.pets) do
            if i > 6 then warns[#warns + 1] = "pets: 6 kinds at most" break end
            if type(p) ~= "table" then warns[#warns + 1] = "pets[" .. i .. "] must be a table" else
                local pal = {}
                for k, v in pairs(type(p.palette) == "table" and p.palette or {}) do
                    if type(k) == "string" and #k == 1 and type(v) == "string" and v:match("^#%x%x%x%x%x%x") then pal[k] = v end
                end
                local rows = next(pal) and pixelRows(p.art, pal, 16, 16)
                if p.art ~= nil and not rows then warns[#warns + 1] = "pets[" .. i .. "].art must be rows of palette letters, 16 x 16 at most" end
                local ai = AI_SET[p.ai] and p.ai or "hunt"
                def.pets[#def.pets + 1] = { name = text(p.name, 20) or ("Pet " .. i), ai = ai,
                    count = math.floor(clamp(p.count, 1, 8, 1)), rows = rows or nil, palette = rows and pal or nil,
                    color = hex(p.color, { 0.6, 0.5, 0.35 }), size = math.floor(clamp(p.size, 1, 6, 2)),
                    damage = clamp(p.damage, 0, 300, 5), speed = clamp(p.speed, 20, 500, ai == "orbit" and 3 or 150),
                    range = clamp(p.range, 10, 400, ai == "orbit" and 36 or ai == "shooter" and 160 or 120),
                    rate = clamp(p.rate, 0.1, 10, ai == "shooter" and 1 or 0.6), status = type(p.status) == "string" and p.status or nil,
                    shotColor = hex(p.shotColor, nil), knockback = clamp(p.knockback, 0, 400, 30) }
            end
        end
        if #def.pets == 0 then def.pets = nil end
    end
    -- ultimate (replaces the frenzy move)
    local u = raw.ultimate
    if type(u) == "table" then
        local fire, tick = u.fire, u.tick
        if type(fire) ~= "function" and type(u.blocks) == "table" then
            local MB = require("src.game.moveblocks")
            local bl = MB.clean(u.blocks, warns, "ultimate.blocks")
            fire = bl and #bl > 0 and MB.compile(bl) or nil
        end
        if type(fire) ~= "function" then errs[#errs + 1] = "ultimate needs fire = function(me) ... end (or blocks = { ... })"
        else
            local SM = require("src.game.scriptmoves")
            local col = hex(u.color, { 1, 0.6, 0.2 })
            local name = text(u.name, 20) or "Ultimate"
            local params = { duration = clamp(u.duration, 0.1, 15, 1), name = name }
            local buff
            if type(u.buff) == "table" and type(u.buff.stats) == "table" then
                local Stats = require("src.game.stats")
                buff = { stats = {}, time = clamp(u.buff.time, 0.5, 60, 5) }
                for k, v in pairs(u.buff.stats) do
                    if Stats.byId[k] and type(v) == "number" then buff.stats[k] = { clamp(v, -200, 300, 0), 0 } end
                end
            end
            def.ownFrenzy = { id = def.id .. "_ult", name = name, custom = true,
                color = ("#%02x%02x%02x"):format(math.floor(col[1] * 255), math.floor(col[2] * 255), math.floor(col[3] * 255)),
                description = text(u.description, 200) or "", params = params, tags = {}, buff = buff,
                chargeRate = clamp(u.charge, 0.2, 5, 1), slowmo = u.slowmo ~= false,
                start = function(ctx)
                    ctx.player.ultUses = (ctx.player.ultUses or 0) + 1
                    SM.run(fire, ctx.player, params, ctx.player.aimX, ctx.player.aimY, { label = "ultimate" })
                end,
                update = function(ctx, dt)
                    if type(tick) == "function" then SM.run(tick, ctx.player, params, ctx.player.aimX, ctx.player.aimY, { label = "ultimate" }, dt, ctx.t) end
                    return ctx.t >= params.duration
                end }
        end
    end
    -- the title card on bug select
    if type(raw.card) == "table" then
        local c = raw.card
        def.card = { motto = text(c.motto, 60), color = hex(c.color), frame = FRAME_SET[c.frame] and c.frame or "plain",
            title = text(c.title, 24) }
    end
    -- challenges (and the default set every custom bug gets)
    local list = {}
    local src = type(raw.challenges) == "table" and raw.challenges or nil
    if raw.challenges ~= false then
        for _, ch in ipairs(Extras.DEFAULT_CHALLENGES) do list[#list + 1] = ch end
    end
    for i, ch in ipairs(src or {}) do
        if i > 10 then warns[#warns + 1] = "challenges: 10 own ones at most" break end
        if type(ch) == "table" and Extras.GOALS[ch.goal] then list[#list + 1] = ch
        else warns[#warns + 1] = "challenges[" .. i .. "]: goal is one of win, wave, kills, nodash, nohit, fast, ultimate" end
    end
    def.challenges = {}
    local seen = {}
    for _, ch in ipairs(list) do
        local G = Extras.GOALS[ch.goal]
        local n = math.floor(clamp(ch.n, 1, 100000, G.n or 1))
        local id = ch.goal .. ":" .. n
        if not seen[id] then
            seen[id] = true
            def.challenges[#def.challenges + 1] = { id = id, goal = ch.goal, n = n, name = text(ch.name, 40) or G.text(n) }
        end
    end
    -- poses: poses = { idle, death, victory } is the same as anims.idle / death / victory
    -- (CustomBugs.build merges them in before anims are built)

    -- forms and molt: whole other versions of the bug, built the same way
    if rebuild then
        local function variant(over, where, suffix)
            if type(over) ~= "table" then return nil end
            local merged = {}
            for k, v in pairs(raw) do merged[k] = v end
            for k, v in pairs(over) do merged[k] = v end
            merged.forms, merged.molt, merged.challenges, merged.card = nil, nil, false, nil
            merged.stats = raw.stats            -- a version's stats add to the bug's own
            merged._artSuffix = suffix
            merged.name = raw.name
            merged.id = raw.id
            local d, e2, w2 = rebuild(merged)
            if not d then
                errs[#errs + 1] = where .. ": " .. tostring(e2 and e2[1])
                return nil
            end
            for _, w in ipairs(w2 or {}) do warns[#warns + 1] = where .. ": " .. w end
            -- same body unless it has its own
            if over.art == nil and over.look == nil then
                d.sprite, d.model, d.art, d.anims = def.sprite, def.model, nil, def.anims
                d.sideways, d.segs, d.strike, d.alt = def.sideways, def.segs, def.strike, def.alt
            end
            d.statBonus = {}
            local Stats = require("src.game.stats")
            for k, v in pairs(type(over.stats) == "table" and over.stats or {}) do
                if Stats.byId[k] and type(v) == "number" then d.statBonus[k] = clamp(v, -300, 300, 0)
                else warns[#warns + 1] = where .. ".stats: '" .. tostring(k) .. "' dropped" end
            end
            d.formName = text(over.name, 24)
            d.say = text(over.say, 30)
            d.baseDef = def
            d.id = def.id
            return d
        end
        if type(raw.forms) == "table" then
            def.forms = { def }
            for i, f in ipairs(raw.forms) do
                if i > 3 then warns[#warns + 1] = "forms: 3 more forms at most" break end
                local d = variant(f, "forms[" .. i .. "]", "_f" .. i)
                if d then def.forms[#def.forms + 1] = d end
            end
            if #def.forms < 2 then def.forms = nil else
                def.formSwitch = raw.formSwitch == "tap" and "tap" or (raw.formSwitch == "code" and "code" or "hold")
                def.formName = text(raw.formName, 24)
            end
        end
        if type(raw.molt) == "table" then
            local d = variant(raw.molt, "molt", "_m")
            if d then
                def.molt = { wave = math.floor(clamp(raw.molt.wave, 2, 100, 10)), def = d, name = text(raw.molt.name, 24) or "Molted",
                    kills = raw.molt.kills and math.floor(clamp(raw.molt.kills, 10, 100000, 300)) or nil }
            end
        end
    end
end

-- The form switch on Shift: hold for form 2 (or tap to cycle). Built as the bug's dash when it
-- has forms and no dash of its own written in code.
function Extras.formDash(def)
    if def.formSwitch == "tap" then
        return { type = "scripted_hold", name = "Switch Form", hold = function(me, dt, held)
            local st = me.state
            if held and not st._formHeld then me.form((me.formNow() % #def.forms) + 1) end
            st._formHeld = held
        end }
    end
    return { type = "scripted_hold", name = def.formName or "Transform", hold = function(me, dt, held)
        local st = me.state
        if held ~= (st._formHeld or false) then me.form(held and 2 or 1) end
        st._formHeld = held
    end }
end

----------------------------------------------------------------------------------------------
-- Run time

-- Swap the moves (and body, stats) the player is using to another version of the bug.
function Extras.swapDef(player, d, statSource)
    local Content = require("src.content")
    local Sprites = require("src.gfx.sprites")
    player.def = d
    player.attack.type = Content.attacks:require(d.attack.type)
    if d.secondary then
        player.secondary = player.secondary or { timer = 0 }
        player.secondary.type = Content.attacks:require(d.secondary.type)
    else
        player.secondary = nil
    end
    if statSource ~= "form" and d.dash and not (d.baseDef or d).forms then
        local Stamina = require("src.game.stamina")
        if player.stamina then Stamina.stop(player) end
        player.dashDef = Content.dashes:require(d.dash.type)
    end
    player.skills:apply()
    -- the version's stat bonus, as modifiers so items stack on top
    player.stats:removeSource(statSource)
    for k, v in pairs(d.statBonus or {}) do player.stats:addModifier(statSource, k, v, 0) end
    player.stats:recompute()
    if d.sprite then player.sprite = Sprites.get(d.sprite) end
    player.model = d.model
    if d.model and d.model.kind == "chain" and not player.chain then
        player.chain = {}
        for i = 1, d.model.segments do player.chain[i] = { x = player.x - i * d.model.spacing, y = player.y } end
    end
end

function Extras.setForm(player, n)
    local base = player.def.baseDef or player.def
    local forms = base.forms
    if not forms then return false end
    n = math.max(1, math.min(#forms, math.floor(n or 1)))
    if (player.formIndex or 1) == n then return true end
    player.formIndex = n
    -- after a molt, form 1 is the molted bug, and every form keeps the molted body
    local molt = player.molted and base.molt and base.molt.def
    local d = (n == 1 and molt) or forms[n]
    local dash = player.dashParams
    Extras.swapDef(player, d, "form")
    player.dashParams = dash
    if molt and molt.sprite ~= base.sprite then
        local Sprites = require("src.gfx.sprites")
        player.sprite, player.model = Sprites.get(molt.sprite), molt.model
    end
    local w = player.world
    if w then
        local label = n == 1 and base.formName or d.say or d.formName
        if label then w:floatText(player.x, player.y - 12, label, { 1, 0.85, 0.5 }, false) end
        w:addFx({ kind = "ring", x = player.x, y = player.y, r = 22, life = 0.25, color = { 1, 0.85, 0.5 } })
        player.flash = 0.1
    end
    return true
end

-- The molt: at its wave (or kill count), the bug turns into its molted version for good.
function Extras.doMolt(player)
    local base = player.def.baseDef or player.def
    local m = base.molt
    if not m or player.molted then return end
    player.molted = true
    local d = m.def
    -- the molt changes body, moves and stats (a bug with forms: form 1 becomes the molted bug)
    local dash = player.dashParams
    Extras.swapDef(player, d, "molt")
    if base.forms then
        player.dashParams = dash
        player.formIndex = 1
    end
    local w = player.world
    if w then
        w.milestone = { text = (m.name or "MOLTED"):upper() .. "!", t = 0 }
        w:addFx({ kind = "ring", x = player.x, y = player.y, r = 60, life = 0.6, color = { 1, 0.95, 0.7 } })
        w.particles:burst(player.x, player.y, 30, { { 1, 0.95, 0.75 }, { 0.8, 0.7, 0.5 } }, 160, 30, {})
        if d.say then w:floatText(player.x, player.y - 14, d.say, { 1, 0.9, 0.6 }, true) end
        require("src.core.audio").play("chime", { pitch = 0.8 })
        if w.camera then w.camera:shake(0.25) end
    end
    player.hp = math.min(player.stats:get("maxHp"), player.hp + player.stats:get("maxHp") * 0.3)
end

-- Sounds from the bug's pack (falls back to the usual one).
function Extras.sfx(player, slot, default, opts)
    local Audio = require("src.core.audio")
    local base = player.def and (player.def.baseDef or player.def)
    local pack = base and base.soundPack
    local s = pack and pack[slot]
    if s then
        Audio.play(s.id, { pitch = s.pitch * (0.95 + love.math.random() * 0.1), volume = s.volume })
        return
    end
    if default then Audio.play(default, opts) end
end

-- Statuses ------------------------------------------------------------------------------------
function Extras.applyStatus(world, e, id)
    local p = world.player
    local base = p and p.def and (p.def.baseDef or p.def)
    local S = base and base.statuses and base.statuses[id]
    if not S or e.dead or e.hidden or e.isProp then return end
    e.cst = e.cst or {}
    local cur = e.cst[id]
    if cur then
        cur.t = S.time
        cur.stacks = math.min(S.stacks, cur.stacks + 1)
    else
        e.cst[id] = { t = S.time, stacks = 1, S = S, tick = 0.25 }
        p.statusTargets = p.statusTargets or {}
        if #p.statusTargets < 300 then p.statusTargets[#p.statusTargets + 1] = e end
    end
    if S.weaken then e.cWeak = S.weaken end
    if S.vulnerable then e.corrodeMul, e.corrodeT = math.max(e.corrodeT > 0 and e.corrodeMul or 1, S.vulnerable), math.max(e.corrodeT, S.time) end
end

local function updateStatuses(player, world, dt)
    local list = player.statusTargets
    if not list then return end
    for i = #list, 1, -1 do
        local e = list[i]
        local any = false
        if e.dead or not e.cst or e.uid == -1 then
            -- spreads when an afflicted ant dies
            if e.cst and e.dead and not e._cstSpread then
                e._cstSpread = true
                for id, st in pairs(e.cst) do
                    if st.S.spread then
                        for _, o in ipairs(Combat.collect(world, e.x, e.y, st.S.spread)) do
                            if o ~= e then Extras.applyStatus(world, o, id) end
                        end
                    end
                end
            end
            if e.dead then e.cst, e.cWeak, e.cCharm, e.cConfuse = nil, nil, nil, nil end
        else
            for id, st in pairs(e.cst) do
                local S = st.S
                st.t = st.t - dt
                st.tick = st.tick - dt
                if st.t <= 0 then
                    e.cst[id] = nil
                    if S.weaken then e.cWeak = nil end
                else
                    any = true
                    if S.slow then e.slowT, e.slowMul = math.max(e.slowT, 0.15), math.min(e.slowT > 0.15 and e.slowMul or 1, S.slow) end
                    if S.stun and not e.def.boss and not e.def.noStun then e.stunT = math.max(e.stunT, 0.1) end
                    if st.tick <= 0 then
                        st.tick = 0.25
                        if S.dps > 0 then Combat.damage(world, e, S.dps * 0.25 * st.stacks, { dot = true, noCrit = true, procDepth = 2,
                            look = { number = S.color, sparkCount = 0 } }) end
                        if S.confuse and not e.def.boss then
                            local a = love.math.random() * math.pi * 2
                            e.kvx, e.kvy = e.kvx + math.cos(a) * 90 / e.mass, e.kvy + math.sin(a) * 90 / e.mass
                            e.stunT = math.max(e.stunT, 0.2)
                        end
                    end
                    if S.charm and not e.def.boss and not e.def.queen then
                        -- fights for the bug: stops chasing it and bites the nearest other ant
                        e.stunT = math.max(e.stunT, 0.1)
                        st.bite = (st.bite or 0) - dt
                        if st.bite <= 0 then
                            st.bite = 0.6
                            local best, bd
                            for _, o in ipairs(Combat.collect(world, e.x, e.y, 60)) do
                                if o ~= e and not (o.cst and o.cst[id]) then
                                    local d = (o.x - e.x) ^ 2 + (o.y - e.y) ^ 2
                                    if not bd or d < bd then best, bd = o, d end
                                end
                            end
                            if best then
                                local nx, ny = util.normalize(best.x - e.x, best.y - e.y)
                                e.x, e.y = e.x + nx * 6, e.y + ny * 6
                                Combat.damage(world, best, S.charmDamage, { knockback = 40, kbx = nx, kby = ny, noCrit = true, procDepth = 2 })
                            end
                        end
                    end
                end
            end
            if e.cst and not next(e.cst) then e.cst = nil end
        end
        if not any then table.remove(list, i) end
    end
    if #list == 0 then player.statusTargets = nil end
end

-- Pets -------------------------------------------------------------------------------------------
function Extras.addPet(player, i)
    local base = player.def.baseDef or player.def
    local P = base.pets and base.pets[i]
    if not P then return false end
    player.pets = player.pets or {}
    if #player.pets >= 16 then return false end
    local a = love.math.random() * math.pi * 2
    player.pets[#player.pets + 1] = { P = P, x = player.x + math.cos(a) * 16, y = player.y + math.sin(a) * 16, vx = 0, vy = 0,
        t = love.math.random() * 3, cd = love.math.random() * P.rate, ang = a, hitT = {}, face = 1 }
    return true
end

local function spawnPets(player)
    local base = player.def.baseDef or player.def
    if not base.pets or player.petsOut then return end
    player.petsOut = true
    for i, P in ipairs(base.pets) do for _ = 1, P.count do Extras.addPet(player, i) end end
end

local function bite(player, world, pet, e, nx, ny)
    local P = pet.P
    Combat.damage(world, e, P.damage, { knockback = P.knockback, kbx = nx, kby = ny, noCrit = true, procDepth = 1,
        cstatus = P.status and (player.def.baseDef or player.def).statuses and (player.def.baseDef or player.def).statuses[P.status] and P.status or nil })
end

local function updatePets(player, world, dt)
    local list = player.pets
    if not list then return end
    local px, py = player.x, player.y
    for idx, pet in ipairs(list) do
        local P = pet.P
        pet.t = pet.t + dt
        pet.cd = pet.cd - dt
        local tx, ty
        if P.ai == "orbit" then
            pet.ang = pet.ang + dt * P.speed
            local r = P.range
            tx, ty = px + math.cos(pet.ang + idx * 1.3) * r, py + math.sin(pet.ang + idx * 1.3) * r
            pet.x, pet.y = pet.x + (tx - pet.x) * math.min(1, dt * 12), pet.y + (ty - pet.y) * math.min(1, dt * 12)
            for _, e in ipairs(Combat.collect(world, pet.x, pet.y, P.size + 3)) do
                local last = pet.hitT[e]
                if not last or pet.t - last >= P.rate then
                    pet.hitT[e] = pet.t
                    local nx, ny = util.normalize(e.x - px, e.y - py)
                    bite(player, world, pet, e, nx, ny)
                end
            end
            if pet.t % 4 < dt then pet.hitT = {} end
        else
            -- hunt / guard / shooter: pick a target near the bug (guard: close in)
            local reach = P.ai == "guard" and math.min(P.range, 70) or P.range
            if not pet.target or pet.target.dead or pet.retarget == nil or pet.retarget <= 0 then
                pet.target = world:nearestEnemy(P.ai == "hunt" and pet.x or px, P.ai == "hunt" and pet.y or py, reach)
                pet.retarget = 0.3
            end
            pet.retarget = pet.retarget - dt
            local e = pet.target
            local far = (pet.x - px) ^ 2 + (pet.y - py) ^ 2 > (P.ai == "hunt" and 220 or 60) ^ 2
            if P.ai == "shooter" then
                -- hangs back beside the bug and shoots
                local side = (idx % 2 == 0) and 1 or -1
                tx, ty = px - player.aimX * 14 - player.aimY * 14 * side, py - player.aimY * 14 + player.aimX * 14 * side
                if e and pet.cd <= 0 then
                    pet.cd = P.rate
                    local nx, ny = util.normalize(e.x - pet.x, e.y - pet.y)
                    local base = player.def.baseDef or player.def
                    world.hazards:friendlyShot({ x = pet.x, y = pet.y, z = 6, vx = nx * 280, vy = ny * 280, r = 2, damage = P.damage,
                        life = (P.range + 20) / 280, color = P.shotColor or P.color, pierce = 0, knockback = P.knockback, procDepth = 1,
                        cstatus = P.status and base.statuses and base.statuses[P.status] and P.status or nil })
                    pet.face = nx >= 0 and 1 or -1
                end
            elseif e and not far then
                tx, ty = e.x, e.y
                local d = math.sqrt((e.x - pet.x) ^ 2 + (e.y - pet.y) ^ 2)
                if d < e.radius + P.size + 2 and pet.cd <= 0 then
                    pet.cd = P.rate
                    local nx, ny = util.normalize(e.x - pet.x, e.y - pet.y)
                    bite(player, world, pet, e, nx, ny)
                    pet.vx, pet.vy = -nx * 60, -ny * 60
                end
            else
                local a = pet.t * 0.7 + idx * 2.1
                tx, ty = px + math.cos(a) * 18, py + math.sin(a) * 18
            end
            local dx, dy, d = util.normalize(tx - pet.x, ty - pet.y)
            local sp = P.speed * (far and 1.6 or 1) * math.min(1, d / 10)
            local k = math.min(1, dt * 8)
            pet.vx, pet.vy = pet.vx + (dx * sp - pet.vx) * k, pet.vy + (dy * sp - pet.vy) * k
            pet.x, pet.y = pet.x + pet.vx * dt, pet.y + pet.vy * dt
            if math.abs(pet.vx) > 5 then pet.face = pet.vx > 0 and 1 or -1 end
            -- left far behind (a teleport, a long dash): catch up
            if (pet.x - px) ^ 2 + (pet.y - py) ^ 2 > 400 ^ 2 then pet.x, pet.y = px, py end
        end
    end
end

-- A pet's picture, made once.
local petImages = setmetatable({}, { __mode = "k" })
local function petImage(P)
    if not P.rows then return nil end
    local img = petImages[P]
    if img then return img end
    local w = 0
    for _, r in ipairs(P.rows) do w = math.max(w, #r) end
    local data = love.image.newImageData(w, #P.rows)
    for y, r in ipairs(P.rows) do
        for x = 1, #r do
            local ch = r:sub(x, x)
            local c = P.palette[ch]
            if c then
                local h = util.hex(c)
                data:setPixel(x - 1, y - 1, h[1], h[2], h[3], h[4] or 1)
            end
        end
    end
    img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    petImages[P] = img
    return img
end

function Extras.draw(player, world)
    local Iso = require("src.core.iso")
    local lg = love.graphics
    -- status marks on afflicted ants
    if player.statusTargets then
        for _, e in ipairs(player.statusTargets) do
            if e.cst and not e.dead then
                local x, y = Iso.toScreen(e.x, e.y, 0)
                local k = 0
                for _, st in pairs(e.cst) do
                    local c = st.S.color
                    lg.setColor(c[1], c[2], c[3], 0.55)
                    lg.ellipse("line", x, y, e.radius + 2 + k, (e.radius + 2 + k) * 0.5)
                    lg.setColor(c[1], c[2], c[3], 0.9)
                    for s = 1, st.stacks do lg.rectangle("fill", math.floor(x - 4 + k * 3 + (s - 1) * 2), math.floor(y - e.radius * 2 - 8 - (s - 1) * 2), 2, 2) end
                    k = k + 2
                end
            end
        end
    end
    if player.pets then
        for _, pet in ipairs(player.pets) do
            local P = pet.P
            local hop = (P.ai ~= "orbit" and (math.abs(pet.vx) + math.abs(pet.vy)) > 10) and math.abs(math.sin(pet.t * 14)) * 1.5 or 0
            local x, y = Iso.toScreen(pet.x, pet.y, P.ai == "orbit" and 6 or 0)
            lg.setColor(0, 0, 0, 0.3)
            local sx, sy = Iso.toScreen(pet.x, pet.y, 0)
            lg.ellipse("fill", math.floor(sx), math.floor(sy), P.size + 1, (P.size + 1) * 0.5)
            local img = petImage(P)
            if img then
                lg.setColor(1, 1, 1, 1)
                lg.draw(img, math.floor(x), math.floor(y - hop), 0, pet.face, 1, img:getWidth() / 2, img:getHeight() - 1)
            else
                local c = P.color
                lg.setColor(c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 1)
                lg.rectangle("fill", math.floor(x - P.size - 1), math.floor(y - P.size - hop), P.size * 2 + 2, P.size + 1)
                lg.setColor(c[1], c[2], c[3], 1)
                lg.rectangle("fill", math.floor(x - P.size), math.floor(y - P.size * 1.5 - hop), P.size * 2, P.size + 1)
            end
        end
    end
    lg.setColor(1, 1, 1, 1)
end

-- Every frame (from SM.tick).
function Extras.tick(player, world, dt)
    local base = player.def.baseDef or player.def
    if base.pets and not player.petsOut and world.mode ~= "menu" then spawnPets(player) end
    updatePets(player, world, dt)
    updateStatuses(player, world, dt)
    -- idle pose: standing still a while plays anims.idle now and then
    local idle = player.def.anims and player.def.anims.idle
    if idle then
        if player.moving or (player.attack and player.attack.timer > 0.05) then player.idleClipT = 0
        else
            player.idleClipT = (player.idleClipT or 0) + dt
            if player.idleClipT > 2.5 then
                player.idleClipT = -1.5
                require("src.gfx.anim").play(player, idle, "pose_idle", {})
            end
        end
    end
    if base.molt and not player.molted and base.molt.kills and (player.killsRun or 0) >= base.molt.kills then Extras.doMolt(player) end
end

-- Game events (from SM.event).
function Extras.event(player, name, ctx)
    local base = player.def.baseDef or player.def
    if name == "onKill" then player.killsRun = (player.killsRun or 0) + 1 end
    if name == "onWaveStart" and base.molt and not player.molted and not base.molt.kills then
        local wave = ctx.wave or (player.world and player.world.spawner and player.world.spawner.wave) or 0
        if wave >= base.molt.wave then Extras.doMolt(player) end
    end
end

return Extras
