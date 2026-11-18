-- Lighting extras on top of World:drawLighting (src/game/world.lua). Every piece here has its own
-- setting in the "Lighting" tab, so players pick what they like:
--   Light Style: Soft (the old pass: lights only lift the shade back to plain daylight) or Bold
--     (lights can push past daylight, then a soft highlight curve rolls bright spots off instead
--     of clipping them to white).
--   Glare Guard: the additive glow layer (swooshes, sparks, explosions) is drawn on its own canvas
--     and soft-capped before it lands on the scene, so it can't bleach the bugs under it.
--   Warning Lights, Hazard Glow, Threat Lights, Kill Light Pops, Night Lantern: extra light sources.
local Settings = require("src.core.settings")
local Screen = require("src.core.screen")
local Iso = require("src.core.iso")

local Lighting = {}

-- Lights queued while the scene draws (attack warnings), consumed by the light pass.
Lighting.queued, Lighting.nq = {}, 0

-- Bold mode stores half the light in the 8-bit light map so it can reach 2x.
Lighting.BOLD_GAIN = 2

local COMPOSITE = [[
    uniform Image lightmap;
    uniform vec2 lscale;
    uniform float gain;
    uniform float knee;
    vec3 roll(vec3 c) {
        vec3 over = max(c - knee, 0.0);
        vec3 soft = knee + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
        return mix(c, soft, step(knee, c));
    }
    vec4 effect(vec4 col, Image tex, vec2 tc, vec2 sc) {
        vec3 s = Texel(tex, tc).rgb;
        vec3 L = Texel(lightmap, tc * lscale).rgb * gain;
        return vec4(roll(s * L), 1.0);
    }
]]

-- Soft cap for the additive layer: linear for faint glows, flattening towards `cap`.
local SOFTADD = [[
    uniform float cap;
    uniform float strength;
    vec4 effect(vec4 col, Image tex, vec2 tc, vec2 sc) {
        vec3 c = Texel(tex, tc).rgb * strength;
        return vec4(cap * (1.0 - exp(-c / cap)), 1.0);
    }
]]

local function canvasLike(name, w, h)
    local c = Screen[name]
    if not c or c:getWidth() ~= w or c:getHeight() ~= h then
        c = love.graphics.newCanvas(w, h)
        Screen[name] = c
    end
    return c
end

function Lighting.bold() return Settings.get("lightStyle") == "bold" end

-- How much stronger lights are drawn (Bold: Light Strength slider; Soft: as before). In Bold,
-- lights count for more the darker the ambient is (amb = its brightness 0..1), so night glows are
-- strong while noon isn't blown out.
function Lighting.lightMul(amb)
    if not Lighting.bold() then return 1 end
    local dark = math.max(0.22, math.min(1, 1.15 - (amb or 0)))
    return 1.6 * dark * Settings.get("lightStrength") / 100 / Lighting.BOLD_GAIN
end

-- Ambient scale for the light map clear colour.
function Lighting.ambientMul()
    return Lighting.bold() and 1 / Lighting.BOLD_GAIN or 1
end

-- Replaces the plain multiply of the light map over the scene (Bold only).
function Lighting.composite(div)
    local lg = love.graphics
    local cw, ch = Screen.canvas:getDimensions()
    local copy = canvasLike("sceneCopy", cw, ch)
    Lighting.shader = Lighting.shader or lg.newShader(COMPOSITE)
    Lighting.quad = Lighting.quad or lg.newQuad(0, 0, 1, 1, cw, ch)
    Lighting.quad:setViewport(0, 0, Screen.viewW, Screen.viewH, cw, ch)
    lg.setCanvas(copy)
    lg.setBlendMode("replace")
    lg.origin()
    lg.setColor(1, 1, 1, 1)
    lg.draw(Screen.canvas, Lighting.quad)
    lg.setCanvas(Screen.canvas)
    local sh = Lighting.shader
    local lw, lh = Screen.light:getDimensions()
    sh:send("lightmap", Screen.light)
    sh:send("lscale", { cw / div / lw, ch / div / lh })
    sh:send("gain", Lighting.BOLD_GAIN)
    sh:send("knee", 0.72)
    lg.setShader(sh)
    lg.draw(copy, Lighting.quad)
    lg.setShader()
    lg.setBlendMode("alpha")
end

-- Is the additive glow layer drawn on its own canvas (Glare Guard, or Own Effects Opacity < 100)?
function Lighting.fxLayer(world)
    if world and #world.fx == 0 and (world.particles.n or 0) == 0 then return false end
    return Settings.get("glareGuard") or Settings.get("ownEffects") < 100
end

function Lighting.beginFx()
    local lg = love.graphics
    local cw, ch = Screen.canvas:getDimensions()
    canvasLike("fxCanvas", cw, ch)
    -- endFx puts back whatever was drawn to before (the world canvas in a run; a test or a
    -- preview can draw a world straight to the screen)
    Lighting.fxPrev = lg.getCanvas()
    lg.setCanvas(Screen.fxCanvas)
    -- only the visible part needs clearing (the canvas is sized for the widest zoom)
    lg.setScissor(0, 0, Screen.viewW, Screen.viewH)
    lg.clear(0, 0, 0, 0)
    lg.setScissor()
end

function Lighting.endFx()
    local lg = love.graphics
    lg.setCanvas(Lighting.fxPrev)
    Lighting.fxPrev = nil
    lg.push()
    lg.origin()
    Lighting.soft = Lighting.soft or lg.newShader(SOFTADD)
    local cw, ch = Screen.canvas:getDimensions()
    Lighting.fxQuad = Lighting.fxQuad or lg.newQuad(0, 0, 1, 1, cw, ch)
    Lighting.fxQuad:setViewport(0, 0, Screen.viewW, Screen.viewH, cw, ch)
    Lighting.soft:send("cap", Settings.get("glareGuard") and 0.5 or 4.0)
    Lighting.soft:send("strength", Settings.get("ownEffects") / 100)
    lg.setShader(Lighting.soft)
    lg.setBlendMode("add")
    lg.setColor(1, 1, 1, 1)
    lg.draw(Screen.fxCanvas, Lighting.fxQuad)
    lg.setShader()
    lg.setBlendMode("alpha")
    lg.pop()
end

-- Glows drawn straight over the scene (fireflies, pollen, lightning): softer with Glare Guard.
function Lighting.glareMul()
    return Settings.get("glareGuard") and 0.5 or 1
end

-- An attack warning about to land (Env.warnCircle / warnLane): world x, y, radius, 0..1 charge.
function Lighting.queueWarn(x, y, r, k, c)
    if not Settings.get("warningLights") or not Settings.get("lighting") then return end
    local n = Lighting.nq + 1
    if n > 64 then return end
    Lighting.nq = n
    local q = Lighting.queued[n] or {}
    Lighting.queued[n] = q
    q.x, q.y, q.r, q.k, q.c = x, y, r, k, c
end

-- A short light burst where something big died (Kill Light Pops).
function Lighting.pop(world, x, y, big)
    if not Settings.get("killLights") then return end
    world.lightPops = world.lightPops or {}
    local pops = world.lightPops
    if #pops >= 12 then return end
    pops[#pops + 1] = { x = x, y = y, t = 0, life = big and 0.7 or 0.4, r = big and 160 or 80 }
end

function Lighting.update(world, dt)
    local pops = world.lightPops
    if not pops then return end
    for i = #pops, 1, -1 do
        local p = pops[i]
        p.t = p.t + dt
        if p.t >= p.life then table.remove(pops, i) end
    end
end

-- The extra light sources, added to the light map through light(x, y, r, cr, cg, cb, a).
function Lighting.extras(world, light, list, n)
    local p = world.player
    -- Night Lantern: a soft pool of light where you're aiming, stronger the darker it gets
    if Settings.get("nightLantern") and not p.dead then
        local dark = 1 - world:daylight()
        if dark > 0.15 then
            local lx, ly = Iso.toScreen(p.x + (p.aimX or 1) * 44, p.y + (p.aimY or 0) * 44)
            light(lx, ly, 150, 1, 0.88, 0.66, 0.42 * dark)
        end
    end
    -- Threat Lights: queens, bosses and big beasts carry a light so they're the brightest thing at night
    if Settings.get("threatLights") then
        for i = 1, n do
            local e = list[i]
            local def = e ~= p and e.def
            if def and not e.hidden then
                if def.boss or def.encounter then
                    local pulse = 0.85 + 0.15 * math.sin(world.time * 3 + (e.uid or 0))
                    if def.encounter then light(e._sx, e._sy, 170, 1, 0.35, 0.25, 0.5 * pulse)
                    else light(e._sx, e._sy, 130, 1, 0.8, 0.3, 0.55 * pulse) end
                elseif e.elite then
                    light(e._sx, e._sy, 60, 1, 0.8, 0.45, 0.3)
                end
            end
        end
    end
    -- Hazard Glow: puddles and pools give off their own colour, with a slow pulse
    if Settings.get("hazardGlow") then
        for _, z in ipairs(world.hazards.zones) do
            local c = z.color
            if c and not z.web then
                local fade = math.min(1, (z.maxLife - z.t) / 1.5, z.t / 0.3)
                local sx, sy = Iso.toScreen(z.x, z.y)
                light(sx, sy, z.r * 3, c[1], c[2], c[3], 0.4 * fade * (0.8 + 0.2 * math.sin(world.time * 2.5 + z.x)))
            end
        end
    end
    -- Warning Lights: telegraphs light the ground red as they charge
    for i = 1, Lighting.nq do
        local q = Lighting.queued[i]
        local sx, sy = Iso.toScreen(q.x, q.y)
        local c = q.c or { 1, 0.25, 0.15 }
        light(sx, sy, q.r * 2.6, c[1], c[2], c[3], 0.25 + 0.45 * q.k)
    end
    Lighting.nq = 0
    -- Kill Light Pops
    if world.lightPops then
        local soft = Settings.get("reduceFlashing") and 0.4 or 1
        for _, pp in ipairs(world.lightPops) do
            local f = 1 - pp.t / pp.life
            local sx, sy = Iso.toScreen(pp.x, pp.y)
            light(sx, sy, pp.r * (0.6 + 0.4 * (1 - f)), 1, 0.9, 0.7, 0.6 * f * f * soft)
        end
    end
end

return Lighting
