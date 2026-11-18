-- A squirrel would kill for this: a little hoard of seeds that grows every wave.
return {
    name = "Seed Cache",
    description = "+3 nectar at every wave clear (+3 per stack), and savings interest can pay 5 more (+5 per stack).",
    effect = "+3 nectar at every wave clear (+3 per stack), and savings interest can pay 5 more (+5 per stack).",
    rarity = "common",
    category = "fortune",
    size = { 2, 1 },
    waveNectar = 3,      -- src/game/economy.lua Economy.payInterest
    interestCap = 5,     -- src/game/economy.lua Economy.interestCap
    tags = { "utility", "plant" },
}
