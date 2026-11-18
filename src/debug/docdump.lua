-- Documentation dump (not part of the game): writes every registry and config table as JSON and
-- renders a picture of every bug, enemy and item icon, for tools/wiki (the Design Bible PDFs).
-- Run: DOCDUMP_OUT=<dir> love . --docdump --selftest
local Content = require("src.content")
local Sprites = require("src.gfx.sprites")
local lg = love.graphics

local OUT = os.getenv("DOCDUMP_OUT") or "/tmp/docdump"

local function esc(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function ser(v, seen, depth)
    local t = type(v)
    if t == "string" then return esc(v)
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return esc(tostring(v)) end
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        return string.format("%.4g", v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "function" then return '"<fn>"'
    elseif t == "table" then
        if seen[v] or depth > 9 then return '"<ref>"' end
        seen[v] = true
        local n, isArr = 0, true
        for k in pairs(v) do
            n = n + 1
            if type(k) ~= "number" then isArr = false end
        end
        local parts = {}
        if isArr and n == #v then
            for i = 1, #v do parts[i] = ser(v[i], seen, depth + 1) end
            seen[v] = nil
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local kv = v[k]
            if type(kv) ~= "userdata" and type(kv) ~= "thread" then
                parts[#parts + 1] = esc(tostring(k)) .. ":" .. ser(kv, seen, depth + 1)
            end
        end
        seen[v] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function writeFile(path, s)
    local f = assert(io.open(path, "wb"))
    f:write(s)
    f:close()
end

local function strip(def)
    -- skip big generated data (sprite frames, baked cells)
    local o = {}
    for k, v in pairs(def) do
        if k ~= "frames" and k ~= "rig" then o[k] = v end
    end
    return o
end

return function()
    os.execute("mkdir -p " .. OUT .. "/img/enemy " .. OUT .. "/img/char " .. OUT .. "/img/item")
    -- which file each id came from
    local files = {}
    local data = {}
    for _, kind in ipairs(Content.order) do
        local reg = Content[kind]
        local dir = "content/" .. kind
        local map = {}
        for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local name = file:match("^(.-)%.lua$")
            if name and file:sub(1, 1) ~= "_" then
                local ok, chunk = pcall(love.filesystem.load, dir .. "/" .. file)
                if ok and chunk then
                    local ok2, r = pcall(chunk)
                    if ok2 and type(r) == "table" then
                        if r[1] and type(r[1]) == "table" then
                            for _, d in ipairs(r) do if d.id then map[d.id] = dir .. "/" .. file end end
                        else
                            map[r.id or name] = dir .. "/" .. file
                        end
                    end
                end
            end
        end
        files[kind] = map
        if kind ~= "sprites" then
            local list = {}
            for i, def in ipairs(reg.list) do
                list[i] = strip(def)
                for _, fk in ipairs({ "text", "scaledText", "effect", "description" }) do
                    if type(def[fk]) == "function" then
                        local ok, r = pcall(def[fk], 1)
                        if ok and type(r) == "string" then list[i][fk .. "_eval"] = r end
                    end
                end
            end
            data[kind] = list
        else
            local list = {}
            for i, def in ipairs(reg.list) do list[i] = { id = def.id, fps = def.fps } end
            data[kind] = list
        end
    end
    data._files = files
    -- every config module
    local cfg = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems("src/config")) do
        local name = file:match("^(.-)%.lua$")
        if name then
            local ok, m = pcall(require, "src.config." .. name)
            if ok then cfg[name] = m else print("[docdump] config " .. name .. ": " .. tostring(m)) end
        end
    end
    data._config = cfg
    local statInfo = {}
    for _, st in ipairs(cfg.stats or {}) do
        if type(st.info) == "function" then
            local ok, r = pcall(st.info, st.default or 0)
            if ok then statInfo[st.id] = r end
        end
    end
    data._statInfo = statInfo
    -- console commands
    local okC, Cmd = pcall(require, "src.debug.commands")
    if okC and type(Cmd) == "table" then data._commands = Cmd end
    writeFile(OUT .. "/data.json", ser(data, {}, 0))
    print("[docdump] data written")

    -- pictures
    local canvas = lg.newCanvas(160, 160)
    local function shoot(path, fn)
        lg.setCanvas(canvas)
        lg.clear(0, 0, 0, 0)
        lg.push()
        lg.origin()
        lg.setColor(1, 1, 1, 1)
        local ok, err = pcall(fn)
        lg.pop()
        lg.setCanvas()
        if not ok then print("[docdump] " .. path .. ": " .. tostring(err)) return end
        local fd = canvas:newImageData():encode("png")
        writeFile(path, fd:getString())
    end
    local function fit(spr, size) return size / math.max(spr.w, spr.h or spr.w) end
    for _, def in ipairs(Content.enemies.list) do
        local spr = Sprites.get(def.sprite)
        if spr then
            shoot(OUT .. "/img/enemy/" .. def.id .. ".png", function()
                Sprites.draw(spr, 1, 80, 80, -math.pi / 2, false, fit(spr, 140))
            end)
        end
    end
    for _, def in ipairs(Content.characters.list) do
        local spr = Sprites.get(def.sprite)
        if spr then
            shoot(OUT .. "/img/char/" .. def.id .. ".png", function()
                local s = fit(spr, 190)
                if def.model then
                    Sprites.drawModel(def.model, 1, 80, 84, -math.pi / 2, false, s, s, 1)
                else
                    Sprites.draw(spr, 1, 80, 80, -math.pi / 2, false, s)
                end
            end)
        end
    end
    for _, def in ipairs(Content.items.list) do
        local icon = Sprites.get(def.icon)
        if icon then
            shoot(OUT .. "/img/item/" .. def.id .. ".png", function()
                local k = math.min(150 / icon.w, 150 / icon.h)
                lg.draw(Sprites.atlas, icon.frames[1][1], 80, 80, 0, k, k, icon.ox, icon.oy)
            end)
        end
    end
    print("[docdump] pictures written")
end
