-- Custom Waves: you build the waves yourself in the wave builder (src/states/wavebuilder.lua):
-- which species come and how many, a queen, wave modifiers, events and hazards, and how tough
-- the enemies are. The set picked in the builder fills in `waves` and the strength fields at the
-- start of the run (src/game/customwaves.lua, CustomWaves.modeDef).
return {
    name = "Custom Waves",
    tagline = "Build your own waves, then fight them.",
    description = "Pick the species in every wave and how many come, add queens, wave modifiers, events and stage hazards, and set how tough the enemies are. Clear your last wave to win. Sets can be copied out as text and shared.",
    order = 20,
    custom = true,
    -- your counts are exact: no extra-big opening waves, no random wave modifiers
    spawn = { earlyBoost = false },
}
