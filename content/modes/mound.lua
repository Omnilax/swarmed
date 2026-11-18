-- Termites only: few species, so the mound throws more of them and its queen comes early.
return {
    name = "Mound",
    tagline = "Termites, and a lot of them.",
    description = "A termite mound empties onto the patio. Workers tunnel under you, soldiers drum for help, and the queen arrives on boss waves.",
    order = 6,
    group = "classic",
    finalWave = 15,
    families = { "termite" },
    queensAnyWave = true,
    spawn = { groups = 4, group = { 16, 24 } },
}
