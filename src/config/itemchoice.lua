-- Item choice helpers you get per run (src/game/choices.lua). A game mode can change any of
-- these with `itemChoice = { rerolls = 5, ... }` in its file under content/modes.
return {
    rerolls = 3,       -- REROLL: new cards for every card that isn't locked
    banishes = 2,      -- BAN: that item never shows up again this run; its card is replaced
    -- Locks are free: a locked card stays in the next item choice (it is used up when taken).
    rerollPerQueen = 1, -- each queen slain gives back this many rerolls
}
