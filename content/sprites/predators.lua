-- Small antlion sprite for catalogues (the antlion is now a stage hazard, content/bosses/antlion.lua).
-- they are drawn by their own drawBody code at full size; these are for catalogues, the
-- sandbox and shadow sizing. Face right.
return {
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
}
