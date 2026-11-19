-- The Field Guide (src/states/fieldguide.lua): how everything in the game works, one short page
-- each. Pages are grouped under headers. A page with `system` (an id from src/config/onramp.lua)
-- stays a "not met yet" page until the player has met that system in a run, so the guide never
-- spoils what Gentle Start is saving for later. {action} in text draws that action's key.
return {
    { group = "Basics", pages = {
        { title = "Moving and attacking", text = "Walk with {key:W}{key:A}{key:S}{key:D} or {pad:leftstick}. With Auto Attack on (Settings > Gameplay) your bug strikes the nearest enemy by itself; otherwise attack with {attack}. Every bug has its own attack, shown on bug select." },
        { title = "Dash and stamina", text = "{dash} dashes. Dashes, blocks and hold moves all spend stamina, the thin bar under your health, which refills on its own. A kill during a dash refunds some of it, and dashing again right after one ends is faster." },
        { title = "Specials", text = "{secondary} uses your bug's special move. It has a cooldown; some specials are held, aimed or charged. Bug select shows each one." },
        { title = "Health and eating", text = "Every ant touching you bites, so crowds hurt fast: keep moving. Eat an item from the bag to heal; the bigger and rarer the item, the more it heals." },
    } },
    { group = "A run", pages = {
        { title = "Waves and queens", text = "A wave ends when every enemy is dead. A new species joins most waves, and a queen leads every fifth. Clear wave 15 to win, then keep going if you like." },
        { title = "Item choices", text = "After each wave, walk into the reward bloom and pick one of three items. Reroll, lock or ban cards from the choice screen. Slaying a queen adds a card." },
        { title = "Level-ups and skill points", text = "Nectar beads give XP. Each level offers cards; skipping a card gives a skill point instead, spent in the SKILLS tab of the bag on your bug's skill tree." },
        { title = "Frenzy", text = "Kills fill the frenzy meter on the right. When it is full, {frenzy} unleashes your bug's super move: you can't be hurt while it runs." },
        { title = "Kill streaks", text = "Every 50 kills in one combo gives a short random buff. Keep the combo going by never letting it lapse." },
        { title = "Nectar and the shop", system = "shop", text = "Fallen ants spill nectar. Spend it in the SHOP tab of the bag ({inventory}): three items and a stat boost, restocking every minute. Banked nectar earns interest at the end of each wave, and SCRAP turns an item back into nectar." },
    } },
    { group = "Items", pages = {
        { title = "The bag", text = "Every item in the bag works at once; there is nothing to equip. Copies stack. The only limit is fitting their shapes into the grid. Rotate an item while holding it." },
        { title = "Tags and sets", text = "Items carry tags such as Offense or Plant. Three items with one tag, all touching, give that tag's set bonus; five give it twice. The bag draws the group's seams in the tag's colour." },
        { title = "Molting", text = "Some items molt into a stronger one when they touch in the bag. The molt happens when the next queen wave is cleared. Glowing seams show pieces that will molt; Records > Recipes keeps every recipe you have found." },
        { title = "Cursed items", text = "Purple items give a big upside with a real cost. They can't be eaten, only scrapped." },
        { title = "Brood cells", text = "A slain queen drops a royal brood cell and a caught treasure ant a plain one. Open it for 1, 3 or 5 level-up cards." },
    } },
    { group = "The arena", pages = {
        { title = "Elite ants", system = "elites", text = "Glowing ants are elites: tougher, with a trick of their own (armored, venomous, volatile...). They spill more nectar and sometimes drop a pickup." },
        { title = "Treasure ant", system = "treasure", text = "Now and then a golden ant runs across the arena. Catch it before it burrows away for a pile of XP and a brood cell." },
        { title = "Mini-goals", system = "goals", text = "Some waves come with an optional task on the right: stop the courier, guard the aphid, reach a combo. Finish it for bonus XP and frenzy." },
        { title = "Wave twists", system = "wavemods", text = "Some waves have a twist, named on the wave banner and in the next-wave preview: ambushes, shield walls, armored columns and more." },
        { title = "Garden events", system = "events", text = "The garden joins the fight: honeydew rain, floods, a boot, a lawnmower, falling acorns. Each hurts ants too, so use it." },
        { title = "Map gambles", system = "gambles", text = "Dewdrop shrines give a permanent blessing if you stand in them long enough. Challenge bells call a tough pack for a prize. Gamble flowers take nectar for a spin." },
        { title = "Route tunnels", system = "routes", text = "Between waves two tunnels may open: a safe one and a hard one. Walk into one to start the next wave that way. Hard routes pay more." },
        { title = "Big visitors", system = "encounters", text = "Now and then, more often late in a run, something huge visits: an antlion pit, a sparrow, a giant anteater. You can't hurt them, and whatever they do hurts ants as much as you." },
        { title = "Props and nest holes", text = "Walk into pebbles and twigs to roll them, or hit them to launch them through the crowd. Hit a nest hole three times, or dash over it, to seal it." },
    } },
    { group = "Progress", pages = {
        { title = "Unlocks", text = "Eight bugs are open from the start. Each other bug opens through a goal, shown in Records > Unlocks." },
        { title = "Danger levels", text = "Win with a bug to open its next danger level (left and right on bug select). Each level adds one rule. The highest won shows as stars." },
        { title = "Modes and the daily run", text = "Play opens every mode. The Daily Run gives everyone the same bug, stage and waves for the day." },
    } },
}
