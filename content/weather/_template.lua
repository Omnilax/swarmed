-- TEMPLATE. Copy to content/weather/my_weather.lua. Weather is visual only (src/game/weather.lua).
return {
    name = "My Weather",
    weight = 10,                    -- how often it is picked; a stage's `weather = { id = w }` overrides
    duration = { 60, 120 },         -- seconds a spell lasts (it fades in and out over 4 s)
    -- stages = { "backyard" },     -- only on these stages (unless a stage lists it in `weather`)
    -- night = true,                -- only picked after dusk, and fades out by day
    dim = 0.85,                     -- multiplies daylight while it lasts (clouds); omit for none
    wind = { 20, 4 },               -- drift added to every particle and fog bank, px/s on screen
    -- lightning = true,            -- the odd thunder flash (off with Reduce Flashing)
    -- fog = { color = "#c8d0dc", alpha = 0.3, count = 8, size = { 90, 180 } },
    particles = {
        kind = "rain",              -- "rain" (streaks that splash), "mote" (dots), "leaf" (tumbling flecks)
        count = 200,                -- per 960x540 pixels of view (scaled by the Particles setting)
        colors = { "#a8c0e0" },
        alpha = 0.5,
        vx = { 30, 40 }, vy = { 240, 280 },     -- velocity, px/s (a number or a {min, max} range)
        life = { 0.3, 0.6 },        -- seconds before a particle is replaced
        length = 6,                 -- rain streak length
        size = 1,                   -- mote / leaf size in pixels
        -- sway = 2, spin = { -4, 4 }, flicker = 4, glow = 10 (soft light radius drawn after lighting)
    },
}
