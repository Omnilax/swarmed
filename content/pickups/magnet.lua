-- Rare drop from any kill: every nectar bead on the ground flies to you.
return {
    name = "Nectar Magnet",
    description = "A rare drop from any ant. Pick it up and every nectar bead and pickup on the ground flies straight to you.",
    color = "#ff6a5a",
    icon = "magnet",
    source = "kill",
    weight = 10, minWave = 2,
    collect = function(world, player, pickup)
        world:magnetNectar()
        world:floatText(player.x, player.y - 12, "MAGNET!", { 1, 0.55, 0.45 }, true)
    end,
}
