-- A lawn overdue for mowing: the long grass closes in on you through each wave
-- (content/mechanics/shrinking_lawn.lua), and the mower is never far away.
return {
    name = "Overgrown Lawn",
    description = "A lawn nobody has mown. The long grass closes in during each wave and is cut back after it.",
    order = 5,
    size = 760,
    seed = 57,
    patioInset = 0.3,
    jointSpacing = 150,
    cracks = 18,
    leaves = 40,
    edgeGrass = 30,
    cliffDepth = 22,
    palette = {
        concrete = "#a8a290", concreteDark = "#6a6658", concreteLight = "#c4beac", joint = "#4e6a34", crack = "#44503a",
        grass1 = "#1e3c18", grass2 = "#2e5822", grass3 = "#40742e", grass4 = "#5a9640", flower = "#f0e070",
        blade1 = "#44862e", blade2 = "#62a63e", blade3 = "#326224", bladeTip = "#b4dc74",
        soil1 = "#3b2a1e", soil2 = "#4a3424", soil3 = "#2e2018", pebble = "#77706a",
        leafA = "#6a4426", leafB = "#8a5a2a", leafVein = "#3e2816",
    },
    ambient = "#7c8688",
    weather = { clear = 40, windy = 12, pollen = 10, petals = 6, heatwave = 8, drizzle = 6 },
    mechanic = { type = "shrinking_lawn", most = 0.26, time = 50 },
    props = { pebble = 4, twig = 5 },
    events = { lawnmower = 16, acorns = 4 },
    spawn = { groups = 3, groupsPerWave = 1, group = { 14, 22 }, groupGap = 3, breakTime = 4, firstBreak = 2,
        maxAlive = 900, growth = 0.15, introEvery = 1, entries = { 2, 6 }, trickle = 6 },
}
