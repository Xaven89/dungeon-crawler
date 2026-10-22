Create a dungeon crawler game in a similar style like the Dungeon Crawler Carl books. Use all the given tools to create an immersive game.

Start by reading CLAUDE.md (what this folder is, the rules of the machine, how to see the game), then docs/GUIDE.md, docs/LUA_API.md and docs/MCP.md, and look at the example projects before you design anything.
Your game is the first real test of the engine from the outside: write every problem, gap and confusing doc into ENGINE_FEEDBACK.md as you meet it, and keep GAME.md up to date.

What "in the style of Dungeon Crawler Carl" means here (an inspiration for tone and structure, not for text: invent your own names, jokes and characters): a deadly dungeon run as a cruel, cheerful game show; a sardonic announcer AI that comments on everything
(deaths, achievements, bad decisions, loot) through the HUD and the audio; a descent floor by floor with a safe stairwell room between floors; levels, stats and classes; loot boxes and achievements with absurd names; monsters and bosses with personality and dark humour;
a companion; traps, hazards and shortcuts that use the engine's physics, fire, liquids, destruction and gravity; a sense that the dungeon is alive and watching.

Aim for a playable vertical slice that is a pleasure to look at and to walk through: a start, a first floor with several differently built areas (hand-built rooms from voxels and prefabs, and a generated cave or biome part if it helps),
real enemies (agents with animation, behaviour, sounds and hit reactions), a boss, an inventory, a HUD, an announcer, sounds and music, lighting and atmosphere (torches, fire, fog, particles), a save, and the way to the next floor.
Plan first (you are in plan mode: write the plan, then build it in small steps, looking at a screenshot after every visible step and committing after every working step).
