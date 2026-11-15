-- Small sprites for the boss encounter predators (content/enemies/predators.lua). In the arena
-- they are drawn by their own drawBody code at full size; these are for catalogues, the
-- sandbox and shadow sizing. Face right.
return {
    {
        id = "anteater",
        fps = 4,
        palette = { o = "#1a1412", a = "#5e554c", b = "#857a6c", w = "#e8e2d4", k = "#141010", t = "#c45a68" },
        frames = {
            {
                "..oooo..............",
                ".oaaaaoo............",
                "oaaaaaaaooooo.......",
                "oaaaabbbbbbbboooo...",
                ".oaabbwwwkbbbbbbboo.",
                "..oabbbbkkkbbbbbbbbo",
                "...obbbbbbbbbbooooot",
                "....ok.ok..ok.ok....",
                "....ok.ok..ok.ok....",
            },
        },
    },
    {
        id = "antlion",
        fps = 4,
        palette = { o = "#1a120a", a = "#6a5034", b = "#8e6e48", j = "#3a2814", s = "#c8a86c" },
        frames = {
            {
                "..............j.",
                "....oooo.....j..",
                "..oobbbbo...j...",
                ".oabbbbbbojjj...",
                "oaaabbsbbbbo....",
                "oaaabbsbbbbo....",
                ".oabbbbbbojjj...",
                "..oobbbbo...j...",
                "....oooo.....j..",
                "..............j.",
            },
        },
    },
    {
        id = "sparrow",
        fps = 4,
        palette = { o = "#1a120c", a = "#6a4a2c", b = "#9a7248", c = "#c8a47a", w = "#efe6d6", k = "#0c0a08", y = "#e0a83a" },
        frames = {
            {
                "......oooo......",
                ".....obbbboo....",
                "oo..obbaabbbo...",
                "oaooobbbbbbkbo..",
                ".oaaaabbbbbbbyy.",
                "..oaaabbcwwwwo..",
                "...oooaacwwwo...",
                "......oooooo....",
                ".......o..o.....",
            },
        },
    },
}
