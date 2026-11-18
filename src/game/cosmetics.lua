-- Cosmetics: the player's chosen location (a stage), map decor and a skin per character.
-- Saved to cosmetics.lua in the save folder, separate from settings.
--
-- Content:
--   content/stages   locations. Each is a palette + layout for src/gfx/ground.lua.
--   content/decor    map cosmetics painted onto a location's floor (any number at once).
--   content/skins    character recolours (hue / saturation / brightness / tint, optional glow
--                    or a whole other model). `character = id` limits one to that bug; without
--                    it every bug can wear it.
-- Anything with `locked = true` stays hidden until Cosmetics.unlock(id) is called (for
-- achievements, shops or events later). Cosmetics.unlocked lists what has been earned.
local Content = require("src.content")
local util = require("src.core.util")

local Cosmetics = { data = { location = nil, decor = {}, skins = {}, unlocked = {} } }
local FILE = "cosmetics.lua"

function Cosmetics.load()
    local d = { decor = {}, skins = {}, unlocked = {} }
    if love.filesystem.getInfo(FILE) then
        local ok, chunk = pcall(love.filesystem.load, FILE)
        local ok2, saved = false, nil
        if ok and chunk then ok2, saved = pcall(chunk) end
        if ok2 and type(saved) == "table" then
            d.location = type(saved.location) == "string" and saved.location or nil
            for _, k in ipairs({ "decor", "skins", "unlocked" }) do
                if type(saved[k]) == "table" then d[k] = saved[k] end
            end
        end
    end
    Cosmetics.data = d
end

function Cosmetics.save()
    love.filesystem.write(FILE, "return " .. util.serialize(Cosmetics.data) .. "\n")
end

function Cosmetics.isUnlocked(def)
    return not def.locked or Cosmetics.data.unlocked[def.id] == true
end

function Cosmetics.unlock(id)
    if Cosmetics.data.unlocked[id] then return false end
    Cosmetics.data.unlocked[id] = true
    Cosmetics.save()
    return true
end

-- Locations ---------------------------------------------------------------------------------

function Cosmetics.locations()
    return Content.stages:filter(function(s) return Cosmetics.isUnlocked(s) end)
end

-- The stage id runs start on (falls back to the first location if the saved one is gone).
function Cosmetics.location()
    local id = Cosmetics.data.location
    local def = id and Content.stages:get(id)
    if def and Cosmetics.isUnlocked(def) then return id end
    return Content.stages:all()[1].id
end

function Cosmetics.setLocation(id)
    Cosmetics.data.location = id
    Cosmetics.save()
end

-- Decor -------------------------------------------------------------------------------------

function Cosmetics.decorOn(id) return Cosmetics.data.decor[id] == true end

function Cosmetics.setDecor(id, on)
    Cosmetics.data.decor[id] = on or nil
    Cosmetics.save()
end

-- Decor ids switched on that suit this stage (a decor may list `stages = {...}`).
function Cosmetics.activeDecor(stage)
    local out = {}
    for _, d in ipairs(Content.decor:all()) do
        local fits = not d.stages
        for _, s in ipairs(d.stages or {}) do if s == stage.id then fits = true end end
        if fits and Cosmetics.decorOn(d.id) and Cosmetics.isUnlocked(d) then out[#out + 1] = d end
    end
    return out
end

-- Paints the decor onto a freshly rendered Ground. Lights the decor gives off (fairy lights)
-- are kept in ground.decorLights as { x, y, radius, {r, g, b}, intensity } in projected coords.
function Cosmetics.paintDecor(ground, stage, list)
    ground.decorLights = {}
    list = list or Cosmetics.activeDecor(stage)
    if #list == 0 then return end
    love.graphics.push("all")
    love.graphics.setCanvas(ground.canvas)
    love.graphics.origin()
    for i, d in ipairs(list) do
        local rng = love.math.newRandomGenerator((stage.seed or 1) * 131 + i * 7)
        love.graphics.setColor(1, 1, 1, 1)
        d.paint(ground, stage, rng)
    end
    love.graphics.pop()
end

-- Skins -------------------------------------------------------------------------------------

-- Every skin this character may wear (unlocked ones), the bug's own first.
function Cosmetics.skinsFor(charId)
    local own, any = {}, {}
    for _, s in ipairs(Content.skins:all()) do
        if Cosmetics.isUnlocked(s) then
            if s.character == charId then own[#own + 1] = s
            elseif not s.character then any[#any + 1] = s end
        end
    end
    for _, s in ipairs(any) do own[#own + 1] = s end
    return own
end

-- The skin def this character wears, or nil for its natural colours.
function Cosmetics.skinFor(charId)
    local id = Cosmetics.data.skins[charId]
    local s = id and Content.skins:get(id)
    if s and Cosmetics.isUnlocked(s) and (not s.character or s.character == charId) then return s end
    -- custom bugs carry their own colours (same fields as a skin)
    local c = Content.characters:get(charId)
    return c and c.custom and c.colors or nil
end

function Cosmetics.setSkin(charId, skinId)
    Cosmetics.data.skins[charId] = skinId
    Cosmetics.save()
end

local SKIN_SHADER = [[
extern vec3 hsv;     // hue turn (0..1), saturation and brightness multipliers
extern vec3 tint;
extern number keepBright;   // 1 keeps near-white pixels (eyes, highlights, the hit flash) as they are
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    // (texture times colour, so legs drawn as tinted shapes recolour too)
    vec4 t = Texel(tex, tc) * color;
    vec3 h = rgb2hsv(t.rgb);
    vec3 o = hsv2rgb(vec3(fract(h.x + hsv.x), clamp(h.y * hsv.y, 0.0, 1.0), clamp(h.z * hsv.z, 0.0, 1.0))) * tint;
    float white = keepBright * step(0.92, min(t.r, min(t.g, t.b)));
    return vec4(mix(o, t.rgb, white), t.a);
}
]]

-- The shader that paints this skin, set up for it (nil for natural colours).
function Cosmetics.shader(skin)
    if not skin or not (skin.hue or skin.saturation or skin.brightness or skin.tint) then return nil end
    if not Cosmetics._shader then Cosmetics._shader = love.graphics.newShader(SKIN_SHADER) end
    local sh = Cosmetics._shader
    if not skin._tint then skin._tint = skin.tint and util.hex(skin.tint) or { 1, 1, 1 } end
    sh:send("hsv", { (skin.hue or 0) / 360, skin.saturation or 1, skin.brightness or 1 })
    sh:send("tint", { skin._tint[1], skin._tint[2], skin._tint[3] })
    sh:send("keepBright", skin.keepWhite == false and 0 or 1)
    return sh
end

return Cosmetics
