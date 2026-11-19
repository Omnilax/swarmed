-- Defense tuning: keeps tanky builds killable (Player:hurt, Player:effectiveArmor).
--   crowd      every ant biting you right now cracks your armor a little; a big crowd can take
--              most of it, but never all (maxFrac of positive armor)
--   shred      ants with `shred = { armor, time, max }` in their def crack your armor on every
--              bite; it stacks up to `max`, holds for `time` s after the last bite, then wears off
--   retaliate  thorns-style payback (anything that fires when you are hurt or block a bite)
--              hits at most this many ants per proc, nearest first, so payback alone can't
--              hold a whole swarm off
return {
    crowd = { perAnt = 1.5, maxFrac = 0.8 },
    shred = { fade = 3 },          -- armor per second the shred wears off once its timer runs out
    retaliate = { maxTargets = 5 },
}
