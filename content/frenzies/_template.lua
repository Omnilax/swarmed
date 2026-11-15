-- TEMPLATE. Copy to content/frenzies/my_frenzy.lua. A frenzy is the super move a full frenzy
-- meter unleashes (src/game/frenzy.lua). A character picks one with `frenzy = "id"`; otherwise
-- the first frenzy whose `tags` share a tag with the character, else src/config/rewards.lua's
-- frenzy.default. The player can't be hurt while it runs.
--
-- ctx (one per unleash): world, player, params, t (seconds since start), plus anything you
-- store on it. Deal damage through src/game/combat.lua so kills, numbers and procs count.
return {
    name = "My Frenzy",
    description = "What it does, for the HUD hint and catalogues.",
    color = "#ffb040",
    tags = {},                     -- e.g. { "flying" }: the default for bugs with that tag
    params = { duration = 1 },
    -- a buff for after the move: stat = { add, mult } and how long it lasts
    buff = { time = 5, stats = { attackSpeed = { 30, 0 } } },
    start = function(ctx) end,
    -- every frame; return true when the move is over (or leave it out: it ends at params.duration)
    update = function(ctx, dt) return ctx.t >= ctx.params.duration end,
    -- drawn in the world (projected pixels) while it runs
    draw = nil,
}
