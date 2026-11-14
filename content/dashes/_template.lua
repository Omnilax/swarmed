-- TEMPLATE. Copy to content/dashes/my_dash.lua; characters use it with dash = { type = "my_dash", ... }.
-- Everything else in the character's dash table is passed to you as `params`.
-- Charges: params.charges (default 1) uses; each refills after the Dash Cooldown stat.
return {
    name = "My Dash",
    description = "Shown in character select.",
    -- Pressed: (dx, dy) is the move direction (or the aim when standing still); px, py point
    -- where the player is pointing (mouse, else aim). Use player:lunge(...) for dash movement.
    start = function(player, world, dx, dy, params, px, py)
        player:lunge(dx, dy, params.distance or 67)
    end,
    -- Optional: hold = true calls update(player, world, dt, params, held) every frame instead,
    -- with held = whether the dash button is down (blocking). No charges are used.
    -- Optional: update(player, world, dt, params) every frame while player.dashT > 0, and
    -- draw(player, world, params) in the world (e.g. a grapple line).
}
