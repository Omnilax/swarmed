-- Custom bugs: playable characters made in the Bug Creator (src/states/creator.lua) or written as
-- Lua scripts (blueprint: content/characters/_custom_blueprint.lua, guide: docs/CUSTOM_BUGS.md).
--
-- Every custom bug is one script in the save folder (custom_bugs/<id>.lua). A script returns a
-- table shaped like a content/characters file, plus a few mix-and-match shortcuts:
--   look = "scorpion"                 the body, model, animations and size of a built-in bug
--   attack = "mantis"                 a move copied whole from a built-in bug, or
--   attack = { from = "mantis", damage = 20 }    copied, then some params changed, or
--   attack = { type = "arc", damage = 8, ... }   written from scratch (content/attacks ids)
--   rules = "dung_beetle", skillTree = "mantis"  borrow a bug's item rule / skill tree
--   colors = { hue = 120 }            recolour (same fields as a skin, content/skins)
--
-- Scripts run in a sandbox: no files, no `love`, no `require`, no loading other code, an
-- instruction budget so a stuck loop cannot hang the game, and only plain data comes out
-- (functions in the returned table are dropped). Then CustomBugs.build checks every field and
-- clamps numbers to sane ranges, so a script can make a weird bug but not a broken game.
-- Works on PUC Lua 5.1 (the web and phone builds) and LuaJIT (desktop).
local Content = require("src.content")

local CustomBugs = {
    dir = "custom_bugs",     -- save-folder directory (selftests point it elsewhere)
    noSave = false,
    list = {},               -- id -> { id, def, source, file }
    broken = {},             -- files that did not load: { file, source, error }
    PREFIX = "custom_",
    MAX_SOURCE = 256 * 1024,
    BUDGET = 1000000,        -- VM instructions a script may run while loading
    MAX_BUGS = 200,
}

local BLUEPRINT = "content/characters/_custom_blueprint.lua"
local ser     -- Lua value -> source text (defined under "Writing scripts")

----------------------------------------------------------------------------------------------
-- Sandbox

local function copyTable(t, skip)
    local o = {}
    for k, v in pairs(t) do if not (skip and skip[k]) then o[k] = v end end
    return o
end

-- Plain data only: no functions, userdata or threads, no cycles, bounded depth and size.
local function plain(v, depth, seen, budget, env)
    local tv = type(v)
    if tv == "string" or tv == "number" or tv == "boolean" then return v end
    -- functions survive only when they were written in the script itself (move code)
    if tv == "function" then
        if env and getfenv and getfenv(v) == env then return v end
        return nil
    end
    if tv ~= "table" or depth > 12 or seen[v] then return nil end
    seen[v] = true
    local o = {}
    for k, x in pairs(v) do
        budget.n = budget.n - 1
        if budget.n < 0 then break end
        local tk = type(k)
        if tk == "string" or tk == "number" then
            local px = plain(x, depth + 1, seen, budget, env)
            if px ~= nil then o[k] = px end
        end
    end
    seen[v] = nil
    return o
end
function CustomBugs.plain(v, env) return plain(v, 0, {}, { n = 60000 }, env) end

-- A deep copy of trusted engine data (keeps functions: built-in params may hold them).
local function deepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local o = {}
    seen[v] = o
    for k, x in pairs(v) do o[k] = deepCopy(x, seen) end
    return o
end

-- Fields of a built-in bug a script may read through bug(id): data only, no look internals.
local READABLE = { "name", "description", "lore", "tip", "playstyle", "radius", "scale", "stats",
    "attack", "secondary", "dash", "startingItems", "tags", "immune" }

local function ids(reg)
    local out = {}
    for _, d in ipairs(reg:all()) do if not d.custom then out[#out + 1] = d.id end end
    return out
end

-- string.rep with a size limit. While a script runs it also replaces the real string.rep,
-- because ("x"):rep(n) reaches the real string table through the string metatable.
local realRep = string.rep
local function safeRep(s, n, sep)
    n = tonumber(n) or 0
    if #tostring(s) * n > 100000 then error("string.rep: result too long", 2) end
    return realRep(s, n, sep)
end

local function makeEnv(log)
    local safeString = copyTable(string, { dump = true })
    safeString.rep = safeRep
    local env = {
        math = copyTable(math, { randomseed = true }), string = safeString, table = copyTable(table),
        pairs = pairs, ipairs = ipairs, next = next, select = select, type = type, unpack = unpack or table.unpack,
        tostring = tostring, tonumber = tonumber, error = error, assert = assert,
        rawequal = rawequal, rawget = rawget,
        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
            if #log < 50 then log[#log + 1] = table.concat(parts, "  ") end
        end,
        -- a copy of a built-in bug's data (moves, stats, text), plus look = its id
        bug = function(id)
            local d = Content.characters:get(tostring(id))
            if not d or d.custom then error("no built-in bug '" .. tostring(id) .. "'", 2) end
            local o = { look = d.id }
            for _, k in ipairs(READABLE) do o[k] = CustomBugs.plain(d[k]) end
            return o
        end,
        -- lists of ids, to look things up or pick at random
        bugs = ids(Content.characters), attacks = ids(Content.attacks), dashes = ids(Content.dashes),
        items = ids(Content.items), statIds = (function()
            local o = {}
            for _, s in ipairs(require("src.config.stats")) do o[#o + 1] = s.id end
            return o
        end)(),
    }
    env._G = env
    return env
end

-- Runs fn(...) with a budget of VM instructions and memory. Checked every few instructions: a
-- loop doubling a string must be caught within a doubling. Used to load scripts and, during a
-- run, to call the move code they define (src/game/scriptmoves.lua).
local EVERY = 4
local activeHook
function CustomBugs.protect(fn, budget, memMB, ...)
    if activeHook then return pcall(fn, ...) end       -- already guarded (nested call)
    local steps, limit = 0, math.floor(budget / EVERY)
    local memStart, gccount = collectgarbage("count"), collectgarbage
    local hook
    hook = function()
        steps = steps + 1
        -- (the hook removes itself first: the error must not fire again once back outside)
        if steps > limit then debug.sethook() activeHook = nil error("the script took too long (a loop that never ends?)", 2) end
        if gccount("count") - memStart > memMB * 1024 then debug.sethook() activeHook = nil error("the script used too much memory", 2) end
    end
    activeHook = hook
    string.rep = safeRep
    debug.sethook(hook, "", EVERY)
    local res = { pcall(fn, ...) }
    debug.sethook()
    string.rep = realRep
    activeHook = nil
    return unpack(res, 1, table.maxn(res))
end

-- Engine code called from script code (the move toolkit) runs without the budget hook: it is
-- trusted, and hooking it would be slow. Errors still reach the script's call.
function CustomBugs.unguarded(fn, ...)
    local h = activeHook
    if not h then return fn(...) end
    debug.sethook()
    string.rep = realRep
    activeHook = nil
    local res = { pcall(fn, ...) }
    activeHook = h
    string.rep = safeRep
    debug.sethook(h, "", EVERY)
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

-- "[string "my_bug"]:12: oops" -> "line 12: oops", plus the line number.
local function cleanError(err)
    err = tostring(err)
    local line, msg = err:match(":(%d+): (.*)$")
    if line then return "line " .. line .. ": " .. msg, tonumber(line) end
    return err
end

-- Runs a script in the sandbox. Returns the value it returned (plain data), or nil, error, line.
function CustomBugs.run(source, name)
    local log = {}
    if type(source) ~= "string" then return nil, "the script is empty", nil, log end
    if #source > CustomBugs.MAX_SOURCE then return nil, "the script is too long (256 KB at most)", nil, log end
    if source:byte(1) == 27 then return nil, "compiled Lua bytecode can't be imported, only Lua text", nil, log end
    source = source:gsub("^#![^\n]*", "")      -- a #! first line is fine
    local load51 = loadstring or load
    local fn, err = load51(source, "=" .. (name or "script"))
    if not fn then
        local e, line = cleanError(err)
        return nil, e, line, log
    end
    local env = makeEnv(log)
    if setfenv then setfenv(fn, env) else
        fn = load(source, "=" .. (name or "script"), "t", env)   -- Lua 5.2+ (not used by LÖVE 11)
    end
    -- hooks don't fire inside JIT-compiled code, so the script runs interpreted
    if jit and jit.off then jit.off(fn, true) end
    local ok, res = CustomBugs.protect(fn, CustomBugs.BUDGET, 32)
    if not ok then
        local e, line = cleanError(res)
        return nil, e, line, log
    end
    if type(res) ~= "table" then
        return nil, "the script must end with `return { ... }` (a table describing the bug)", nil, log
    end
    return CustomBugs.plain(res, env), nil, nil, log
end

----------------------------------------------------------------------------------------------
-- Checking and building a character definition

-- What a stat may be set to on a custom bug (a bit wider than the built-in roster).
CustomBugs.STAT_RANGE = {
    maxHp = { 5, 500 }, hpRegen = { 0, 10 }, armor = { -10, 30 }, dodge = { 0, 60 }, moveSpeed = { 30, 300 },
    damage = { -80, 150 }, attackSpeed = { -60, 150 }, area = { -60, 150 }, knockback = { -80, 200 },
    critChance = { 0, 80 }, critDamage = { 100, 400 }, luck = { -80, 150 }, lifesteal = { 0, 25 },
    pickupRange = { 5, 250 }, dashCooldown = { 0.2, 8 },
}
-- Move params: every number is kept in a sane range; counts are kept small so a script can't
-- fire a thousand projectiles a frame.
local PARAM_RANGE = {
    damage = { 0, 500 }, cooldown = { 0.03, 60 }, charges = { 1, 10 },
}
local COUNTISH = { count = true, shots = true, turns = true, bounces = true, chains = true, chain = true,
    pierce = true, spiderlings = true, segments = true, darts = true, hits = true, n = true, number = true }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function clampParams(t, depth)
    for k, v in pairs(t) do
        if type(v) == "number" then
            if v ~= v then v = 0 end     -- NaN
            local r = PARAM_RANGE[k]
            if r then v = clamp(v, r[1], r[2])
            elseif COUNTISH[k] then v = clamp(v, 0, 40)
            else v = clamp(v, -2000, 2000) end
            t[k] = v
        elseif type(v) == "table" and depth < 4 then
            clampParams(v, depth + 1)
        end
    end
end

local function builtIn(id)
    local d = type(id) == "string" and Content.characters:get(id)
    if d and not d.custom then return d end
end

local function text(v, max)
    if type(v) ~= "string" then return nil end
    v = v:gsub("[%c]", " ")
    if #v > max then v = v:sub(1, max) end
    return v
end

local SCRIPT_KEYS = { "fire", "start", "tick", "hold", "release", "enter", "exit" }

-- One move slot (attack / secondary / dash). Returns params, mix info, or nil + error.
local function buildMove(slot, v, reg, errs, warns)
    if v == nil then return nil end
    if v == false then return false end
    local from, params
    if type(v) == "string" then v = { from = v } end
    if type(v) ~= "table" then
        errs[#errs + 1] = slot .. " must be a bug id like \"scorpion\" or a table"
        return nil
    end
    if v.from ~= nil then
        local src = builtIn(v.from)
        if not src then
            errs[#errs + 1] = slot .. ": no built-in bug '" .. tostring(v.from) .. "' to copy from"
            return nil
        end
        if not src[slot] then
            errs[#errs + 1] = slot .. ": the " .. src.name .. " has no " .. slot
            return nil
        end
        from = src.id
        params = deepCopy(src[slot])
        local own = CustomBugs.plain(v)
        own.from = nil
        if next(own) then clampParams(own, 0) end
        for k, x in pairs(own) do
            local was = params[k]
            if was ~= nil and type(was) ~= type(x) and type(was) ~= "function" then
                errs[#errs + 1] = ("%s.%s must be a %s, like the %s's (%s)"):format(slot, tostring(k), type(was), src.name,
                    type(was) == "table" and "a table" or tostring(was))
                return nil
            end
            params[k] = x
        end
    else
        params = CustomBugs.plain(v)
        clampParams(params, 0)
        -- functions and no type: a move written in code
        if params.type == nil then
            for _, k in ipairs(SCRIPT_KEYS) do if type(v[k]) == "function" then params.type = "scripted" break end end
        end
    end
    -- a move written in code picks its kind from what it has: release (hold to charge),
    -- mode = true (a stamina mode), hold (a dash held down), else a pressed move
    local scripted = type(params.type) == "string" and params.type:match("^scripted") ~= nil and v.from == nil
    if scripted then
        if slot == "dash" then
            params.type = v.mode == true and "scripted_mode" or type(v.hold) == "function" and "scripted_hold" or "scripted"
        else
            params.type = (type(v.release) == "function" or type(v.hold) == "function") and "scripted_charge" or "scripted"
        end
    end
    if type(params.type) ~= "string" or not reg:get(params.type) then
        errs[#errs + 1] = ("%s: unknown %s type '%s' (see the lists in docs/CUSTOM_BUGS.md)"):format(slot, reg.kind, tostring(params.type))
        return nil
    end
    -- a move written in code: its functions (made in the script) come along
    if scripted then
        for _, k in ipairs(SCRIPT_KEYS) do
            if type(v[k]) == "function" then params[k] = v[k] end
        end
        local need = ({ scripted = slot == "dash" and { "start" } or { "fire" }, scripted_charge = { "release", "fire" },
            scripted_hold = { "hold" }, scripted_mode = { "enter", "tick" } })[params.type]
        local has = false
        for _, k in ipairs(need) do if type(params[k]) == "function" then has = true end end
        if not has then
            errs[#errs + 1] = ("%s: a %s written in code needs %s = function(me) ... end"):format(slot, slot, table.concat(need, " or "))
            return nil
        end
        params.name = text(v.name, 24)
        if slot ~= "dash" then params.cooldown = params.cooldown or (slot == "secondary" and 2 or 0.6) end
    else
        local had = false
        for _, k in ipairs(SCRIPT_KEYS) do
            if type(v[k]) == "function" then
                had = true
                if params[k] == v[k] then params[k] = nil end
            end
        end
        if had then warns[#warns + 1] = slot .. ": code only runs in moves written in code, not copied ones (ignored)" end
    end
    return params, from
end

local function slug(s)
    s = tostring(s or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if #s > 32 then s = s:sub(1, 32) end
    return s
end
CustomBugs.slug = slug

function CustomBugs.idFor(name) return CustomBugs.PREFIX .. slug(name) end


-- Own art: a script's `art` table -> sprite definitions for Sprites.buildSet (made when the bug
-- is registered, see CustomBugs.prepareArt), or nil + errors.
--   art = { palette = { a = "#rrggbb", ... }, body = { rows } or frames = { { rows }, ... },
--           legs = { { hipU, hipV, kneeU, kneeV, footU, footV }, ... }, legColor = "#rrggbb",
--           height = 3, lift = 2, kneeUp = 1, stride = 1.6, fps = 8 }
local ART_MAX_W, ART_MAX_H, ART_MAX_FRAMES = 96, 64, 8
local function buildArt(id, art, errs, warns)
    if type(art) ~= "table" then errs[#errs + 1] = "art must be a table" return nil end
    local pal = {}
    for k, v in pairs(type(art.palette) == "table" and art.palette or {}) do
        if type(k) ~= "string" or #k ~= 1 or k == "." or k == " " then
            errs[#errs + 1] = "art.palette: keys are single letters or digits (got '" .. tostring(k) .. "')"
        elseif type(v) ~= "string" or not (v:match("^#%x%x%x%x%x%x$") or v:match("^#%x%x%x%x%x%x%x%x$")) then
            errs[#errs + 1] = "art.palette." .. k .. " must be a colour like \"#5a7a30\""
        else
            pal[k] = v
        end
    end
    if not next(pal) then errs[#errs + 1] = "art.palette is empty" return nil end
    local chain = type(art.chain) == "table" and art.chain or nil
    local frames = art.frames or { art.body or (chain and chain.head) }
    if type(frames) ~= "table" or type(frames[1]) ~= "table" then
        errs[#errs + 1] = "art needs body = { \"rows of pixels\", ... } (or frames = { {...}, {...} })"
        return nil
    end
    local w, h = 0, 0
    local clean = {}
    for fi = 1, math.min(#frames, ART_MAX_FRAMES) do
        local rows = frames[fi]
        if type(rows) ~= "table" or #rows == 0 then errs[#errs + 1] = "art frame " .. fi .. " has no rows" return nil end
        if #rows > ART_MAX_H then errs[#errs + 1] = ("art: %d rows at most"):format(ART_MAX_H) return nil end
        clean[fi] = {}
        for ri, row in ipairs(rows) do
            if type(row) ~= "string" then errs[#errs + 1] = ("art frame %d row %d must be a string"):format(fi, ri) return nil end
            if #row > ART_MAX_W then errs[#errs + 1] = ("art: rows are %d pixels wide at most"):format(ART_MAX_W) return nil end
            for ci = 1, #row do
                local ch = row:sub(ci, ci)
                if ch ~= "." and ch ~= " " and not pal[ch] then
                    errs[#errs + 1] = ("art frame %d row %d: '%s' is not in the palette"):format(fi, ri, ch)
                    return nil
                end
            end
            clean[fi][ri] = row
            w = math.max(w, #row)
        end
        h = math.max(h, #rows)
    end
    if #frames > ART_MAX_FRAMES then warns[#warns + 1] = ("art: %d frames at most"):format(ART_MAX_FRAMES) end
    -- how big the drawing really is (for the hitbox)
    local minX, maxX, minY, maxY = math.huge, -1, math.huge, -1
    for y, row in ipairs(clean[1]) do
        for x = 1, #row do
            local ch = row:sub(x, x)
            if ch ~= "." and ch ~= " " then
                minX, maxX, minY, maxY = math.min(minX, x), math.max(maxX, x), math.min(minY, y), math.max(maxY, y)
            end
        end
    end
    if maxX < 0 then errs[#errs + 1] = "art: the body has no pixels" return nil end
    local rig
    if art.legs ~= nil then
        if type(art.legs) ~= "table" then errs[#errs + 1] = "art.legs must be a list of legs" return nil end
        rig = {}
        for li, leg in ipairs(art.legs) do
            if li > 10 then warns[#warns + 1] = "art.legs: 10 legs a side at most" break end
            if type(leg) ~= "table" or #leg < 4 or #leg > 8 or #leg % 2 == 1 then
                errs[#errs + 1] = ("art.legs[%d] must be 2 to 4 joints: { hipU, hipV, kneeU, kneeV, footU, footV }"):format(li)
                return nil
            end
            local l = {}
            for j, n in ipairs(leg) do
                if type(n) ~= "number" then errs[#errs + 1] = ("art.legs[%d] must hold numbers"):format(li) return nil end
                l[j] = clamp(n, -60, 60)
            end
            rig[li] = l
        end
    end
    local legColor = type(art.legColor) == "string" and art.legColor:match("^#%x%x%x%x%x%x$") or "#302820"
    local ids = { icon = id .. "_icon", body = id .. "_body", legs = id .. "_legs" }
    local fps = clamp(tonumber(art.fps) or 8, 1, 24)
    local sprites = {
        { id = ids.icon, fps = fps, palette = pal, frames = clean },
        { id = ids.body, fps = fps, iso = true, palette = pal, frames = clean },
        { id = ids.legs, fps = 16, iso = true, rig = rig or {}, palette = { l = legColor }, frames = { { "l" } } },
    }
    local model = { legs = ids.legs, body = ids.body,
        height = clamp(tonumber(art.height) or 3, 1, 10), lift = clamp(tonumber(art.lift) or 2, 0, 10),
        kneeUp = clamp(tonumber(art.kneeUp) or 1, 0, 6), stride = clamp(tonumber(art.stride) or 1.6, 0.5, 4) }
    -- extra limbs that are always there: claws, tails, fangs, antennae, horns (src/gfx/anim.lua)
    if art.limbs ~= nil then
        model.restLimbs = {}
        for i, l in ipairs(type(art.limbs) == "table" and art.limbs or {}) do
            if i > 12 then warns[#warns + 1] = "art.limbs: 12 at most" break end
            local limb, e = CustomBugs.limb(l, pal)
            if not limb then errs[#errs + 1] = ("art.limbs[%d]: %s"):format(i, e) return nil end
            model.restLimbs[#model.restLimbs + 1] = limb
        end
        if #model.restLimbs == 0 then model.restLimbs = nil end
    end
    -- a long segmented body (centipede, millipede): head + segments that trail behind
    if chain then
        local function rowsOf(rows, what)
            if type(rows) ~= "table" or #rows == 0 or #rows > ART_MAX_H then
                errs[#errs + 1] = "art.chain." .. what .. " must be rows of pixels (" .. ART_MAX_H .. " at most)"
                return nil
            end
            local out = {}
            for ri, row in ipairs(rows) do
                if type(row) ~= "string" or #row > ART_MAX_W then errs[#errs + 1] = ("art.chain.%s row %d is not a row of pixels"):format(what, ri) return nil end
                for ci = 1, #row do
                    local ch = row:sub(ci, ci)
                    if ch ~= "." and ch ~= " " and not pal[ch] then
                        errs[#errs + 1] = ("art.chain.%s row %d: '%s' is not in the palette"):format(what, ri, ch)
                        return nil
                    end
                end
                out[ri] = row
            end
            return out
        end
        local head = rowsOf(chain.head or clean[1], "head")
        local seg = rowsOf(chain.segment, "segment")
        if not (head and seg) then return nil end
        local seg2 = chain.segment2 and rowsOf(chain.segment2, "segment2") or seg
        if not seg2 then return nil end
        ids.head, ids.seg, ids.seg2 = id .. "_head", id .. "_seg", id .. "_seg2"
        sprites[#sprites + 1] = { id = ids.head, fps = 1, iso = true, palette = pal, frames = { head } }
        sprites[#sprites + 1] = { id = ids.seg, fps = 1, iso = true, palette = pal, frames = { seg } }
        sprites[#sprites + 1] = { id = ids.seg2, fps = 1, iso = true, palette = pal, frames = { seg2 } }
        local leg = type(chain.leg) == "table" and chain.leg or { 0, -1, -0.4, -4, -1.6, -6 }
        local cleanLeg = {}
        for j = 1, math.min(8, #leg) do cleanLeg[j] = clamp(tonumber(leg[j]) or 0, -30, 30) end
        if #cleanLeg < 4 or #cleanLeg % 2 == 1 then errs[#errs + 1] = "art.chain.leg must be { hipU, hipV, kneeU, kneeV, footU, footV }" return nil end
        model = { kind = "chain", legs = ids.legs, head = ids.head, segment = ids.seg, segment2 = ids.seg2,
            segments = math.floor(clamp(tonumber(chain.segments) or 10, 2, 40)), spacing = clamp(tonumber(chain.spacing) or 3, 1, 12),
            height = model.height, lift = model.lift, legColor = legColor, wave = clamp(tonumber(chain.wave) or 0.1, 0, 0.5),
            leg = chain.leg == false and nil or { cleanLeg }, restLimbs = model.restLimbs }
    end
    local size = math.max(maxX - minX + 1, maxY - minY + 1)
    return { sprites = sprites, model = model, sprite = ids.icon, radius = clamp(size * 0.22, 3, 22) }
end

-- One jointed limb (src/gfx/anim.lua "Limbs"), plain data only.
local TIPS = { pincer = true, blade = true, sting = true, fang = true, club = true, crusher = true }
local function chan(v) return type(v) == "string" and v:match("^[%a_][%w_]*$") and #v <= 16 and v or nil end
local function segList(l, max)
    if type(l) ~= "table" then return nil end
    local out = {}
    for i, sg in ipairs(l) do
        if i > max then break end
        if type(sg) ~= "table" then return nil end
        out[i] = { clamp(tonumber(sg[1]) or 2, 0, 30), clamp(tonumber(sg[2]) or 0, -7, 7), clamp(tonumber(sg[3]) or 0, -7, 7) }
    end
    return #out > 0 and out or nil
end
function CustomBugs.limb(l, pal)
    if type(l) ~= "table" then return nil, "must be a table" end
    local segs = segList(l.segs, 8)
    if not segs then return nil, "needs segs = { { length, yaw, pitch }, ... }" end
    local c = l.color
    if type(c) == "string" and not (c:match("^#%x%x%x%x%x%x$") or (#c == 1 and (not pal or pal[c]))) then c = nil end
    return {
        u = clamp(tonumber(l.u) or 0, -60, 60), v = clamp(tonumber(l.v) or 0, -40, 40),
        z = tonumber(l.z) and clamp(tonumber(l.z), -10, 30) or nil,
        side = (l.side == 1 or l.side == -1) and l.side or nil,
        segs = segs, strike = segList(l.strike, 8), alt = segList(l.alt, 8),
        ch = chan(l.ch), ch2 = chan(l.ch2), chR = chan(l.chR), open = chan(l.open), alpha = chan(l.alpha),
        width = clamp(tonumber(l.width) or 2, 1, 4), color = type(c) == "string" and c or nil,
        tip = TIPS[l.tip] and l.tip or nil, tipLen = tonumber(l.tipLen) and clamp(tonumber(l.tipLen), 1, 12) or nil,
        tipW = tonumber(l.tipW) and clamp(tonumber(l.tipW), 0.2, 2) or nil,
        restOpen = tonumber(l.restOpen) and clamp(tonumber(l.restOpen), 0, 1) or nil,
        depth = (l.depth == "far" or l.depth == "near") and l.depth or nil, group = chan(l.group),
    }
end

-- An animation clip (src/gfx/anim.lua), plain data only. hold = "charge" | "block" | "mode" |
-- "hold" keeps the pose while that is going on.
local HOLDS = {
    charge = function(p) return p.scriptCharge ~= nil and next(p.scriptCharge) ~= nil end,
    block = function(p) return p.scriptBlock == true end,
    mode = function(p) return p.holdMode ~= nil end,
    hold = function(p) return p.wasHolding == true end,
}
local function buildClip(c, pal, where, errs)
    if type(c) == "string" then
        if require("src.config.anims")[c] then return c end
        errs[#errs + 1] = where .. ": no built-in animation '" .. c .. "'"
        return nil
    end
    if type(c) ~= "table" then errs[#errs + 1] = where .. " must be a table or an animation name" return nil end
    local clip = { time = clamp(tonumber(c.time) or 0.3, 0.03, 5), keys = {}, mirror = c.mirror == true or nil,
        holdAt = tonumber(c.holdAt) and clamp(tonumber(c.holdAt), 0, 1) or nil, hold = HOLDS[c.hold] }
    for i, k in ipairs(type(c.keys) == "table" and c.keys or {}) do
        if i > 32 then break end
        if type(k) == "table" then
            local key = { clamp(tonumber(k[1] or k.t) or 0, 0, 1) }
            for name, v in pairs(k) do
                if chan(name) and name ~= "t" and type(v) == "number" then key[name] = clamp(v, -40, 40) end
            end
            clip.keys[#clip.keys + 1] = key
        end
    end
    table.sort(clip.keys, function(a, b) return a[1] < b[1] end)
    if #clip.keys == 0 then clip.keys = { { 0 }, { 1 } } end
    if type(c.limbs) == "table" then
        clip.limbs = {}
        for i, l in ipairs(c.limbs) do
            if i > 12 then break end
            local limb, e = CustomBugs.limb(l, pal)
            if not limb then errs[#errs + 1] = ("%s.limbs[%d]: %s"):format(where, i, e) return nil end
            clip.limbs[#clip.limbs + 1] = limb
        end
    end
    return clip
end

-- Own sounds: { name = { wave, freq, to, duration, volume, noise, decay, vibrato = {rate, depth}, notes } }
local WAVES = { sine = true, square = true, saw = true, triangle = true, noise = true }
local function buildSound(t)
    if type(t) ~= "table" then return nil end
    local notes
    if type(t.notes) == "table" then
        notes = {}
        for i, f in ipairs(t.notes) do
            if i > 16 then break end
            notes[i] = clamp(tonumber(f) or 440, 30, 5000)
        end
    end
    return { wave = WAVES[t.wave] and t.wave or "sine", freq = clamp(tonumber(t.freq) or 440, 30, 5000),
        to = tonumber(t.to) and clamp(tonumber(t.to), 30, 5000) or nil, duration = clamp(tonumber(t.duration) or 0.2, 0.02, 1.5),
        volume = clamp(tonumber(t.volume) or 0.5, 0, 1), noise = clamp(tonumber(t.noise) or 0, 0, 1),
        decay = clamp(tonumber(t.decay) or 2, 0.2, 8), attack = clamp(tonumber(t.attack) or 0.005, 0.001, 0.5),
        vibrato = type(t.vibrato) == "table" and { clamp(tonumber(t.vibrato[1]) or 0, 0, 40), clamp(tonumber(t.vibrato[2]) or 0, 0, 0.5) } or nil,
        notes = notes }
end

-- Script code inside an own skill tree runs through the move toolkit like hooks do.
local function wrapProc(fn, label)
    return function(ctx, rank)
        local SM = require("src.game.scriptmoves")
        local p = ctx.player or (ctx.world and ctx.world.player)
        if not p then return end
        return SM.run(fn, p, ctx.params, ctx.ax, ctx.ay, { depth = (ctx.procDepth or 0) + 1, label = label }, SM.evOf(ctx), rank)
    end
end
local function buildTree(def, t, errs, warns)
    local Skills = require("src.game.skills")
    local Stats = require("src.game.stats")
    local tree = { id = def.id .. "_tree", character = def.id, custom = true, branches = {} }
    local nodeCount = 0
    for bi, br in ipairs(type(t.branches) == "table" and t.branches or {}) do
        if bi > 4 then warns[#warns + 1] = "skillTree: 4 branches at most" break end
        if type(br) ~= "table" then errs[#errs + 1] = "skillTree.branches[" .. bi .. "] must be a table" return nil end
        local b = { name = text(br.name, 20) or ("Branch " .. bi), blurb = text(br.blurb, 80),
            color = type(br.color) == "table" and { clamp(tonumber(br.color[1]) or 1, 0, 1), clamp(tonumber(br.color[2]) or 1, 0, 1), clamp(tonumber(br.color[3]) or 1, 0, 1) } or nil,
            nodes = {} }
        for ni, n in ipairs(type(br.nodes) == "table" and br.nodes or {}) do
            nodeCount = nodeCount + 1
            if nodeCount > 40 then warns[#warns + 1] = "skillTree: 40 nodes at most" break end
            if type(n) ~= "table" then errs[#errs + 1] = ("skillTree branch %d node %d must be a table"):format(bi, ni) return nil end
            local node = CustomBugs.plain(n)     -- data only; proc code is added back below
            node.id = def.id .. "_" .. slug(tostring(n.id or (bi .. "_" .. ni)))
            node.name = text(n.name, 24) or "?"
            node.desc = text(n.desc, 160) or ""
            node.tier = math.floor(clamp(tonumber(n.tier) or 1, 1, 6))
            node.ranks = math.floor(clamp(tonumber(n.ranks) or 1, 1, 5))
            node.cost = tonumber(n.cost) and math.floor(clamp(tonumber(n.cost), 1, 6)) or nil
            node.col = tonumber(n.col) and clamp(tonumber(n.col), -1, 1) or nil
            -- requires / excludes name other nodes of this tree by their own ids
            for _, f in ipairs({ "requires", "excludes" }) do
                if type(n[f]) == "table" then
                    node[f] = {}
                    for _, r in ipairs(n[f]) do node[f][#node[f] + 1] = def.id .. "_" .. slug(tostring(r)) end
                end
            end
            for _, f in ipairs({ "stats", "statsMult" }) do
                if type(n[f]) == "table" then
                    node[f] = {}
                    for sid, v in pairs(n[f]) do
                        if Stats.byId[sid] and type(v) == "number" then node[f][sid] = clamp(v, -300, 300)
                        else warns[#warns + 1] = ("skillTree node '%s': stat '%s' dropped"):format(node.name, tostring(sid)) end
                    end
                end
            end
            node.throw = nil
            -- procs: code runs with the toolkit, effect(me, ev, rank) / condition(me, ev, rank)
            if n.procs ~= nil then
                node.procs = {}
                for pi, pr in ipairs(type(n.procs) == "table" and n.procs or {}) do
                    if type(pr) ~= "table" or type(pr.trigger) ~= "string" or type(pr.effect) ~= "function" then
                        errs[#errs + 1] = ("skillTree node '%s' proc %d needs trigger = \"onKill\" and effect = function(me, ev, rank) ... end"):format(node.name, pi)
                        return nil
                    end
                    node.procs[pi] = { trigger = pr.trigger, move = pr.move, cooldown = tonumber(pr.cooldown) and clamp(tonumber(pr.cooldown), 0, 60) or nil,
                        chance = tonumber(pr.chance) and clamp(tonumber(pr.chance), 0, 1) or nil,
                        effect = wrapProc(pr.effect, node.name),
                        condition = type(pr.condition) == "function" and wrapProc(pr.condition, node.name) or nil }
                end
            end
            -- every other function is dropped (the engine calls those directly)
            for k, v in pairs(node) do if type(v) == "function" then node[k] = nil end end
            b.nodes[#b.nodes + 1] = node
        end
        tree.branches[#tree.branches + 1] = b
    end
    if #tree.branches == 0 then errs[#errs + 1] = "skillTree needs branches = { { name = ..., nodes = { ... } } }" return nil end
    clampParams(tree, 0)
    -- the bug's kin branch (insect, beetle, spider...) joins as a 4th, unless kin = false
    if t.kin ~= false and #tree.branches < 4 then
        if type(t.kin) == "string" then tree.kin = t.kin end
        Skills.attachKin(tree, def)
    end
    local ok, e = Skills.validateTree(tree)
    if not ok then errs[#errs + 1] = "skillTree: " .. tostring(e) return nil end
    return tree
end

local HOOKS = { "onStart", "onTick", "onHit", "onKill", "onHurt", "onDodge", "onBlock", "onDash", "onDashEnd", "onWaveStart", "onEat", "onAttack", "onSpecial" }

-- raw (a script's result) -> def ready for Content.characters, or nil + errors. Warnings are
-- things that were fixed up on the way (clamped numbers, unknown items dropped...).
function CustomBugs.build(raw)
    local errs, warns = {}, {}
    if type(raw) ~= "table" then return nil, { "the script must return a table" }, warns end
    local name = text(raw.name, 28)
    if not name or not name:find("%w") then errs[#errs + 1] = "name is missing (name = \"My Bug\")" end
    name = name or "?"
    local lookId = raw.look or "rhino_beetle"
    local look = builtIn(lookId)
    if not look then
        errs[#errs + 1] = "look: no built-in bug '" .. tostring(lookId) .. "' (try look = \"scorpion\")"
        look = builtIn("rhino_beetle") or Content.characters:all()[1]
    end
    local def = {
        name = name,
        custom = true,
        description = text(raw.description, 400) or "",
        lore = text(raw.lore, 300),
        tip = text(raw.tip, 300) or "",
        order = 1000 + (tonumber(raw.order) and clamp(tonumber(raw.order), 0, 999) or 500),
        -- the look: sprite, model and animations come from the built-in bug
        sprite = look.sprite, model = look.model, anims = look.anims, sideways = look.sideways,
        segs = look.segs, strike = look.strike, alt = look.alt,
        stats = {},
        startingItems = {},
        tags = { "custom" },
        mix = { look = look.id },
    }
    def.id = raw.id and (CustomBugs.PREFIX .. slug(raw.id)) or CustomBugs.idFor(name)
    if def.id == CustomBugs.PREFIX then def.id = CustomBugs.PREFIX .. "bug" end
    -- own art instead of a built-in bug's look
    local art
    if raw.art ~= nil then
        art = buildArt(def.id, raw.art, errs, warns)
        if art then
            def.sprite, def.model, def.anims, def.sideways, def.segs, def.strike, def.alt = art.sprite, art.model, nil, nil, nil, nil, nil
            def.art = art.sprites
            def.mix.look = nil
            def.mix.art = true
        end
    end
    -- size: scale draws it bigger, the hitbox follows unless radius is given
    local scale = tonumber(raw.scale) or (art and 1) or look.scale or 1
    if scale ~= clamp(scale, 0.5, 2) then warns[#warns + 1] = "scale kept between 0.5 and 2" end
    def.scale = clamp(scale, 0.5, 2)
    local baseR = art and art.radius * def.scale or (look.radius or 6) * def.scale / (look.scale or 1)
    def.radius = clamp(tonumber(raw.radius) or baseR, 3, 22)
    -- playstyle
    local Playstyles = require("src.config.playstyles")
    def.playstyle = Playstyles.byId[raw.playstyle or ""] and raw.playstyle or look.playstyle or "brawler"
    -- stats
    local Stats = require("src.game.stats")
    for id, v in pairs(type(raw.stats) == "table" and raw.stats or {}) do
        if not Stats.byId[id] then
            errs[#errs + 1] = "stats: unknown stat '" .. tostring(id) .. "'"
        elseif type(v) ~= "number" or v ~= v then
            errs[#errs + 1] = "stats." .. id .. " must be a number"
        else
            local r = CustomBugs.STAT_RANGE[id] or { -100, 300 }
            local c = clamp(v, r[1], r[2])
            if c ~= v then warns[#warns + 1] = ("stats.%s kept between %s and %s"):format(id, r[1], r[2]) end
            def.stats[id] = c
        end
    end
    -- moves
    local atk, atkFrom = buildMove("attack", raw.attack == nil and look.id or raw.attack, Content.attacks, errs, warns)
    if atk == false then errs[#errs + 1] = "attack can't be turned off" atk = nil end
    def.attack, def.mix.attack = atk, atkFrom
    local sec, secFrom = buildMove("secondary", raw.secondary == nil and look.id or raw.secondary, Content.attacks, errs, warns)
    def.secondary, def.mix.secondary = sec or nil, secFrom
    if sec == false then def.mix.secondary = false end
    local dash, dashFrom = buildMove("dash", raw.dash == nil and look.id or raw.dash, Content.dashes, errs, warns)
    if dash == false then dash = { type = "dash", distance = 60 } end
    def.dash, def.mix.dash = dash, dashFrom
    -- borrowed rule and skill tree
    local Rules = require("src.config.bugrules")
    if raw.rules ~= nil then
        if Rules[raw.rules] then def.rules, def.mix.rules = raw.rules, raw.rules
        else warns[#warns + 1] = "rules: the bug '" .. tostring(raw.rules) .. "' has no rule (dropped)" end
    end
    -- skill tree: its own (built at the end, once its tags are known), a preset ("preset:tank"),
    -- or a built-in bug's. With none named it gets the preset that fits its playstyle.
    local Presets = require("src.config.presettrees")
    if type(raw.skillTree) == "table" then
        def.mix.ownTree = true
    elseif type(raw.skillTree) == "string" and raw.skillTree:match("^preset:") then
        local pid = raw.skillTree:sub(8)
        if Presets.list[pid] then def.presetTree, def.mix.skillTree = pid, raw.skillTree
        else warns[#warns + 1] = "skillTree: no preset '" .. pid .. "' (" .. table.concat(Presets.order, ", ") .. ")" end
    elseif raw.skillTree ~= nil and raw.skillTree ~= false then
        if require("src.game.skills").treeFor(raw.skillTree) then def.skillTree, def.mix.skillTree = raw.skillTree, raw.skillTree
        else warns[#warns + 1] = "skillTree: the bug '" .. tostring(raw.skillTree) .. "' has no skill tree (a preset is used)" end
    end
    def.immune = raw.immune == true or nil
    -- code that runs on game events (src/game/scriptmoves.lua)
    if raw.hooks ~= nil then
        if type(raw.hooks) ~= "table" then errs[#errs + 1] = "hooks must be a table of functions"
        else
            local known = {}
            for _, k in ipairs(HOOKS) do known[k] = true end
            for k, fn in pairs(raw.hooks) do
                if not known[k] then warns[#warns + 1] = "hooks: no event '" .. tostring(k) .. "' (" .. table.concat(HOOKS, ", ") .. ")"
                elseif type(fn) ~= "function" then errs[#errs + 1] = "hooks." .. k .. " must be a function(me, ...)"
                else def.hooks = def.hooks or {} def.hooks[k] = fn end
            end
        end
    end
    -- own animations: { attack = clip, secondary = clip, dash = clip, <any name> = clip (me.anim) }
    if raw.anims ~= nil then
        if type(raw.anims) ~= "table" then errs[#errs + 1] = "anims must be a table"
        else
            local base = def.anims
            def.anims = {}
            if type(base) == "table" then for k, v in pairs(base) do def.anims[k] = v end end
            local pal = art and art.sprites[1].palette
            local n = 0
            for slot, c in pairs(raw.anims) do
                n = n + 1
                if n > 16 then warns[#warns + 1] = "anims: 16 at most" break end
                if chan(slot) then def.anims[slot] = buildClip(c, pal, "anims." .. slot, errs) end
            end
            def.mix.anims = true
        end
    end
    -- own sounds: me.sound("<name>") plays them
    if type(raw.sounds) == "table" then
        def.sounds = {}
        local n = 0
        for name, t in pairs(raw.sounds) do
            n = n + 1
            if n > 16 then warns[#warns + 1] = "sounds: 16 at most" break end
            local snd = chan(name) and buildSound(t)
            if snd then def.sounds[name] = snd else warns[#warns + 1] = "sounds." .. tostring(name) .. " dropped (a table like { wave = \"square\", freq = 300 })" end
        end
    end
    -- moves written in code (src/game/scriptmoves.lua runs them)
    for _, slot in ipairs({ "attack", "secondary", "dash" }) do
        if type(def[slot]) == "table" and tostring(def[slot].type):match("^scripted") then def.scripted = true end
    end
    if def.hooks or def.ownTree then def.scripted = true end
    -- colours: a built-in skin's fields
    if type(raw.colors) == "table" then
        local c = raw.colors
        def.colors = {
            hue = tonumber(c.hue) and clamp(tonumber(c.hue), -360, 360) or nil,
            saturation = tonumber(c.saturation) and clamp(tonumber(c.saturation), 0, 3) or nil,
            brightness = tonumber(c.brightness) and clamp(tonumber(c.brightness), 0.2, 2) or nil,
            tint = type(c.tint) == "string" and c.tint:match("^#%x%x%x%x%x%x$") or nil,
            keepWhite = c.keepWhite == false and false or nil,
        }
        def.mix.hue = def.colors.hue
    end
    -- starting items: known, dealable items, four at most
    for _, id in ipairs(type(raw.startingItems) == "table" and raw.startingItems or {}) do
        local it = Content.items:get(tostring(id))
        if not it then warns[#warns + 1] = "startingItems: unknown item '" .. tostring(id) .. "' (dropped)"
        elseif #def.startingItems >= 4 then warns[#warns + 1] = "startingItems: four at most" break
        else def.startingItems[#def.startingItems + 1] = it.id end
    end
    for _, t in ipairs(type(raw.tags) == "table" and raw.tags or {}) do
        if type(t) == "string" and #def.tags < 8 and t ~= "custom" then def.tags[#def.tags + 1] = t:sub(1, 20) end
    end
    if type(raw.skillTree) == "table" then def.ownTree = buildTree(def, raw.skillTree, errs, warns) end
    if not (def.ownTree or def.skillTree or def.presetTree) then def.presetTree = Presets.forPlaystyle(def.playstyle) end
    if def.hooks or def.ownTree then def.scripted = true end
    if #errs > 0 then return nil, errs, warns end
    return def, errs, warns
end

-- source text -> def or nil; info = { errors = {...}, warnings = {...}, line = n, log = {...} }
function CustomBugs.compile(source, name)
    local raw, err, line, log = CustomBugs.run(source, name)
    if not raw then return nil, { errors = { err }, warnings = {}, line = line, log = log } end
    local def, errs, warns = CustomBugs.build(raw)
    return def, { errors = errs or {}, warnings = warns or {}, log = log }
end

----------------------------------------------------------------------------------------------
-- Registering, saving and loading

-- Make the bug's own sprites (once per version of its art).
local artKeys = {}
function CustomBugs.prepareArt(def)
    -- own sounds (me.sound("name") plays "<id>:name")
    if def.sounds then
        local Audio = require("src.core.audio")
        for name, spec in pairs(def.sounds) do Audio.addSynth(def.id .. ":" .. name, spec) end
    end
    if not def.art then return end
    local key = ser(def.art, "")
    if artKeys[def.sprite] == key then return end
    require("src.gfx.sprites").buildSet(def.art)
    artKeys[def.sprite] = key
end

function CustomBugs.register(def, source)
    local old = Content.characters:get(def.id)
    if old then
        if not old.custom then return false, "that id belongs to a built-in bug" end
        Content.characters:unregister(def.id)
    end
    CustomBugs.prepareArt(def)
    Content.characters:register(def)
    Content.characters:sort()
    CustomBugs.list[def.id] = { id = def.id, def = def, source = source, file = CustomBugs.dir .. "/" .. def.id .. ".lua" }
    return true
end

function CustomBugs.unregister(id)
    local d = Content.characters:get(id)
    if d and d.custom then Content.characters:unregister(id) end
    CustomBugs.list[id] = nil
end

function CustomBugs.get(id) return CustomBugs.list[id] end

-- Has things only a script can hold (own art, code, sounds, animations)? Those bugs open the
-- mixer in tweak mode, which keeps the script and only changes name, size, colour and stats.
function CustomBugs.coded(def)
    return (def.art or def.scripted or def.sounds or def.mix.anims or def.ownTree) and true or false
end

-- Custom bugs, in list order.
function CustomBugs.all()
    local out = {}
    for _, d in ipairs(Content.characters:all()) do
        if d.custom and CustomBugs.list[d.id] then out[#out + 1] = CustomBugs.list[d.id] end
    end
    return out
end

function CustomBugs.count()
    local n = 0
    for _ in pairs(CustomBugs.list) do n = n + 1 end
    return n
end

-- A short test fight with the bug (each move used a few times against some ants), so a script
-- whose numbers break a move is caught when it is saved, not in the middle of a run.
function CustomBugs.trial(def)
    local TRIAL = "custom__trial"
    local copy = {}
    for k, v in pairs(def) do copy[k] = v end
    copy.id = TRIAL
    if Content.characters:get(TRIAL) then Content.characters:unregister(TRIAL) end
    CustomBugs.prepareArt(copy)
    Content.characters:register(copy)
    local SM = require("src.game.scriptmoves")
    SM.errors[TRIAL] = nil
    local Audio = require("src.core.audio")
    local muted = Audio.muted
    Audio.muted = true
    local ok, err = pcall(function()
        local World = require("src.game.world")
        local w = World.new({ mode = "sandbox", character = TRIAL })
        w.flags.god, w.flags.demo = true, true
        w.pilot = { pressed = {}, down = {} }
        local p = w.player
        if Content.enemies:get("worker_ant") then w:spawnRing("worker_ant", 6, p.x, p.y, 50) end
        for f = 1, 150 do
            local ph = f % 50
            w.pilot.pressed = { attack = ph == 1, secondary = ph == 18, dash = ph == 34 }
            w.pilot.down = { attack = ph < 14, secondary = ph >= 18 and ph < 30, dash = ph >= 34 and ph < 44 }
            w.pilot.mx, w.pilot.my = math.cos(f * 0.07), math.sin(f * 0.07)
            w:update(1 / 60)
        end
        local g = w.ground
        if g and g.canvas then g.canvas:release() end
        if g and g.decals then g.decals:release() end
    end)
    Audio.muted = muted
    Content.characters:unregister(TRIAL)
    if not ok then
        local msg = tostring(err):gsub("^[^:]*:%d+: ", "")
        return false, "it crashed in a test fight (" .. msg .. "). A move param probably has the wrong kind of value."
    end
    if SM.errors[TRIAL] then
        local e = SM.errors[TRIAL]
        SM.errors[TRIAL] = nil
        return false, "a move's code failed in a test fight: " .. e
    end
    return true
end

-- Compile, register and write a script to the save folder. replaces = the id it was opened as
-- (renaming a bug moves its file). Returns def, info.
function CustomBugs.save(source, replaces)
    local def, info = CustomBugs.compile(source, "script")
    if not def then return nil, info end
    local fine, why = CustomBugs.trial(def)
    if not fine then info.errors[#info.errors + 1] = why return nil, info end
    if not CustomBugs.list[def.id] and def.id ~= replaces and CustomBugs.count() >= CustomBugs.MAX_BUGS then
        info.errors[#info.errors + 1] = ("you already have %d custom bugs; delete one first"):format(CustomBugs.MAX_BUGS)
        return nil, info
    end
    local ok, err = CustomBugs.register(def, source)
    if not ok then info.errors[#info.errors + 1] = err return nil, info end
    if replaces and replaces ~= def.id then CustomBugs.delete(replaces) end
    if not CustomBugs.noSave then
        love.filesystem.createDirectory(CustomBugs.dir)
        local wrote, werr = love.filesystem.write(CustomBugs.dir .. "/" .. def.id .. ".lua", source)
        if not wrote then info.warnings[#info.warnings + 1] = "could not save the file: " .. tostring(werr) end
    end
    -- a fixed broken file is not broken any more
    for i = #CustomBugs.broken, 1, -1 do
        local b = CustomBugs.broken[i]
        if b.file == CustomBugs.dir .. "/" .. def.id .. ".lua" or b.id == replaces then table.remove(CustomBugs.broken, i) end
    end
    return def, info
end

function CustomBugs.delete(id)
    CustomBugs.unregister(id)
    if not CustomBugs.noSave then love.filesystem.remove(CustomBugs.dir .. "/" .. id .. ".lua") end
    for i = #CustomBugs.broken, 1, -1 do
        if CustomBugs.broken[i].id == id then table.remove(CustomBugs.broken, i) end
    end
end

-- Load every script in the save folder (at start-up, after Content.load).
function CustomBugs.loadAll()
    for id in pairs(CustomBugs.list) do CustomBugs.unregister(id) end
    CustomBugs.broken = {}
    local dir = CustomBugs.dir
    if not love.filesystem.getInfo(dir, "directory") then return 0 end
    local files = love.filesystem.getDirectoryItems(dir)
    table.sort(files)
    local n = 0
    for _, file in ipairs(files) do
        local base = file:match("^(.-)%.lua$")
        if base and n < CustomBugs.MAX_BUGS then
            local path = dir .. "/" .. file
            local src = love.filesystem.read(path)
            local def, info = CustomBugs.compile(src, base)
            local ok, err = def ~= nil, nil
            if def then ok, err = CustomBugs.register(def, src) end
            if ok then
                n = n + 1
                CustomBugs.list[def.id].file = path
            else
                CustomBugs.broken[#CustomBugs.broken + 1] = { id = base, file = path, source = src,
                    error = err or (info.errors[1] or "?") }
                print("[custombugs] " .. path .. ": " .. tostring(err or info.errors[1]))
            end
        end
    end
    return n
end

----------------------------------------------------------------------------------------------
-- Writing scripts

local KEY_ORDER = { "name", "description", "lore", "tip", "look", "scale", "radius", "colors", "playstyle",
    "stats", "attack", "secondary", "dash", "rules", "skillTree", "immune", "startingItems", "tags" }

local function isIdent(k) return type(k) == "string" and k:match("^[%a_][%w_]*$") ~= nil end

local function num(v)
    if v == math.floor(v) and math.abs(v) < 1e15 then return ("%d"):format(v) end
    return (("%.3f"):format(v):gsub("0+$", ""):gsub("%.$", ""))
end

-- A Lua value as readable source: short tables on one line, longer ones one field per line.
function ser(v, indent)
    local tv = type(v)
    if tv == "string" then return (("%q"):format(v):gsub("\\\n", "\\n")) end
    if tv == "number" then return num(v) end
    if tv == "boolean" then return tostring(v) end
    if tv ~= "table" then return "nil" end
    local parts, n = {}, #v
    for i = 1, n do parts[#parts + 1] = ser(v[i], indent .. "    ") end
    local keys = {}
    for k in pairs(v) do
        if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b)
        if a == "type" or a == "from" then return b ~= "type" and b ~= "from" or a == "from" end
        if b == "type" or b == "from" then return false end
        return tostring(a) < tostring(b)
    end)
    for _, k in ipairs(keys) do
        local ks = isIdent(k) and k or ("[" .. ser(k, indent) .. "]")
        parts[#parts + 1] = ks .. " = " .. ser(v[k], indent .. "    ")
    end
    local one = "{ " .. table.concat(parts, ", ") .. " }"
    if #parts == 0 then return "{}" end
    if #one + #indent <= 96 then return one end
    return "{\n" .. indent .. "    " .. table.concat(parts, ",\n" .. indent .. "    ") .. ",\n" .. indent .. "}"
end
CustomBugs.serialize = function(v) return ser(v, "") end

-- A table of script fields -> the text of a script (used by the mixer).
function CustomBugs.toSource(t, header)
    local lines = { header or "-- Made with the Bug Creator. Edit it freely: the blueprint and docs/CUSTOM_BUGS.md list every field.",
        "return {" }
    local done = {}
    local function put(k)
        if t[k] == nil or done[k] then return end
        done[k] = true
        lines[#lines + 1] = "    " .. k .. " = " .. ser(t[k], "    ") .. ","
    end
    for _, k in ipairs(KEY_ORDER) do put(k) end
    local rest = {}
    for k in pairs(t) do if not done[k] and isIdent(k) then rest[#rest + 1] = k end end
    table.sort(rest)
    for _, k in ipairs(rest) do put(k) end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

-- Tweaks from the mixer on top of a script it can't rebuild (own art, code...): the script
-- stays word for word inside a function, and a short block after it changes the bug.
-- t = { name, scale, colors = { hue = .. } | false, stats = { id = value } }
local TWEAK_HEAD = "-- [Bug Creator tweak] the original script, untouched:\nlocal function original()\n"
local TWEAK_FOOT = "\nend -- [end of the original script]\n"
function CustomBugs.untweaked(source)
    if source:sub(1, #TWEAK_HEAD) ~= TWEAK_HEAD then return source end
    local e = source:find(TWEAK_FOOT, 1, true)
    if not e then return source end
    return source:sub(#TWEAK_HEAD + 1, e - 1)
end
function CustomBugs.tweakSource(source, t)
    local inner = CustomBugs.untweaked(source)
    local out = { TWEAK_HEAD, inner, TWEAK_FOOT, "local bug = original()\n",
        "-- Changed in the Bug Creator's mixer (edit these lines, or tweak it again there):\n" }
    local function line(s) out[#out + 1] = s .. "\n" end
    if t.name then line("bug.name = " .. ser(t.name, "")) end
    if t.scale then line("bug.scale = " .. ser(t.scale, "")) end
    if t.colors == false then line("bug.colors = nil")
    elseif t.colors then line("bug.colors = " .. ser(t.colors, "")) end
    local keys = {}
    for k in pairs(t.stats or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    if #keys > 0 then line("bug.stats = bug.stats or {}") end
    for _, k in ipairs(keys) do line(("bug.stats.%s = %s"):format(k, ser(t.stats[k], ""))) end
    line("return bug")
    return table.concat(out)
end

function CustomBugs.blueprint()
    return love.filesystem.read(BLUEPRINT) or CustomBugs.toSource({ name = "My Bug", look = "rhino_beetle" })
end

return CustomBugs
