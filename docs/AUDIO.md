# Audio

Everything you hear is synthesised from what the simulation does: there are no sound files to ship, and every sound follows the world. The pieces:

- `core/audio_event.hpp`: `AudioEvent` (kind, position in metres, two numbers, a material) and `AudioQueue`. Systems get an `AudioSink*` and `emit`; a null sink costs nothing (headless runs, recordings and replays collect nothing: sound is cosmetic and never read back).
- `audio/audio_engine.*`: the synth and mixer (64 voices, 48 kHz stereo, a soft ceiling). Renders into a buffer, so the tests and `--audio-demo` need no sound card.
- `audio/audio_device.*`: the card, through miniaudio, which loads PulseAudio / ALSA at run time (nothing is linked: a machine without a card stays silent and says so in the log). On the dev box the Pulse server reaches Moonlight.
- `sim/audio_probe.*`: rays for the sound (occlusion, the room), and `FootstepTracker`.

## What makes a sound

| source | event | what it sounds like |
|---|---|---|
| a body hits something (`PhysicsWorld`, contacts that are new and close faster than 1.5 m/s, at most 12 per tick, a 6 tick cooldown per body) | `Impact`: speed, size, the material that was hit | a few damped modes by material class: metal rings (0.9 s), glass rings bright, wood knocks, stone thuds with grit, soil is a dull thump; smaller things sound higher; harder is louder |
| explosions, digging, crumbling rubble, splashes, hard landings (`ParticleEmitter`) | `Explosion`, `Dig`, `Crumble`, `Splash`, `Land` | an explosion is a falling thump plus a rumble and a crack, longer and louder with its radius; a splash is band-passed noise and a falling bubble |
| the walking player and every agent (`FootstepTracker`) | `Step`: speed, the material underfoot, the creature (`sample`) | two strikes a stride (heel and toe, or front and hind feet), by surface, foot and creature: see "Footsteps" |
| doors, buttons, levers, lamps (`EventSystem`) | `Door` (starts: a creak, stops: a thud), `Click` | |
| scripts | `sound.*` (below) | tones, clicks, WAV files |
| fire | a bed: level from the burning voxels within 40 m, placed at the nearest | a roar and random crackles |
| water | a bed: moving liquid bricks within 35 m (`LiquidSystem::flowNear`) | band-passed noise that swells |
| wind | a bed: the player's speed | low-passed noise with gusts |

Positional: the gain falls with distance, the sound pans (equal power) and darkens behind you, air takes the highs off far sounds, and **the speed of sound** is real: an explosion 170 m away arrives half a second late. **Occlusion**: a ray from the source to the listener counts the walls (up to three solid runs); a wall makes the sound quieter and duller (about ten times a second for the living sounds). **Room**: 24 rays from the listener measure how enclosed the place is and how big: a closed room gets a reverb tail that grows with its size, the open air none.

## Footsteps

A step is two strikes (heel, then the toe rolling off; a quadruped's front and hind feet). Each strike is a few layers: the **weight** (a damped low tone that starts high and settles, over a low thump of noise), the **surface** (a band of noise with a real attack, its centre falling as the foot settles: the swish of grass, the dull burst of soil), **grains** on loose ground (each a short resonant pop at its own pitch, densest at the strike: sand hisses with thousands of tiny ones, gravel crunches with a few hundred chunky ones, leaves crinkle, snow crunches and squeaks on about half the steps), a short coloured **click** for the contact of a hard sole, and a **ring** on metal and glass. The toe of a shoe is a scuff (no click, little weight, a slower swish); a hoof's second beat is another clop. The **surface** sets the base sound; the **foot** reshapes it (a hoof clicks and is sharper, a paw is soft, a claw scratches, `heavy` is low and loud, `bare` is quiet, `metal` rings). No two steps are alike: level, timing of the second strike, pitch and the band vary a little from the step's seed. Nothing sounds like a drum: the weight is only a layer under the surface.

Who steps how is data, `footsteps.csv` (project key `footsteps = footsteps.csv`; without it the built-in table, with examples as comments, is used):

```
# creature, surface, foot, pitch, volume, stride, gait
*,      *,     shoe,  1.0,  1.0, 1.6, biped      # every creature, every surface
player, *,     shoe,  1.0,  1.0, 1.6, biped
horse,  *,     hoof,  0.85, 1.2, 2.3, quad
horse,  stone, hoof,  0.9,  1.3, -,   -          # a column left as - comes from a less specific row
*,      snow,  -,     -,    0.8                 # a little quieter on snow, whoever walks
```
`creature` is `player`, `agent` (every `agent.spawn` that names no creature) or the name given in `agent.spawn{creature = "horse"}` (default: the model file's name). `surface` is a class (grass leaves soil sand gravel snow stone wood metal glass soft water), a material name (`brick`) or `*`; the most specific row wins per column (creature over material over class). `pitch` 0.5..2, `volume` 0..3, `stride` metres per stride (the player steps every `stride * (0.9 + 0.075 * speed)` m; agents use the same), `gait` biped or quad. A landing turns a shoe into a boot. Errors are logged by line and the line is skipped; the table's hash goes nowhere (sound is cosmetic). `sound.step(creature, material [, speed, x, y, z])` plays one from a script, `voxelith --audio-demo out.wav` has a tour (nine surfaces, six creatures).

## Ambience
`AudioEngine::setAmbience(kind, level)` (kinds `Meadow Forest Desert Tundra Shore Cave`): one continuous bed of the place, fed by the app from the biome under the camera (docs/WORLD_GEN.md "Mood"); changing the kind fades the old one out first. Synthesised like the wind: filtered noise with slow gusts, and chirps / drips from a random schedule.

## Settings and keys

`audio = on|off` and `volume = 0..1` in the settings file (`--setting volume=0.4`), a volume slider in the View panel, **End** mutes, `--no-audio` leaves the card alone. `voxelith --audio-demo out.wav` renders a 67 s tour offline (every material's impact soft and hard, steps, a splash, a door, clicks, explosions near and far, fire, water, wind, a wall, a closed room) without a card.

## Lua

```
sound.tone(hz, seconds [, x, y, z])        -- positions are metres; omitted: at the player's head
sound.click([pitch [, x, y, z]])
sound.boom(radius [, strength [, x, y, z]])
sound.hit("metal", speed [, size [, x, y, z]])   -- what an impact of that material sounds like
sound.load("sounds/door.wav")  --> index    -- 16 bit PCM or 32 bit float WAV (any rate and channels, mixed down); relative to the project
sound.play("sounds/door.wav" | index, x, y, z [, volume [, pitch]])  --> true / false
```
Scripts' sounds are cosmetic like all of it: nothing about them is logged; a replay runs the same script and simply is not listened to.

## Not built

Doppler, HRTF, sound files for music (a WAV plays through `sound.play` but there is no streaming or mixer UI), per-bed occlusion (a fire behind a wall is not muffled except by the room), a sound for bodies sliding / rolling, rain on materials (`DropSystem` could emit), liquid sounds at the player's feet.
