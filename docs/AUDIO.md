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


## Music, voices and sounds you can stop: `sound.play{...}` handles, buses, 2D sound, offline output
```lua
local m = sound.play{ file = "sounds/hall.wav", loop = true, bus = "music", volume = 0.6, fade_in = 2 }   -- no `at`: 2D, at the listener (no distance, no pan): music, the announcer's voice, a menu click
local d = sound.play{ file = "sounds/drip.wav", at = {12, 3, 40}, pitch = 0.9 }                          -- with `at`: a place in the world (distance, pan, occlusion as always)
sound.volume(m, 0.2, 1.5)     -- over 1.5 s;   sound.pitch(m, 1.1, 0.5);   sound.stop(m, 2)  (a stop fades out for 0.05 s unless told otherwise: no click)
local car = sound.play{ file = "sounds/rumble.wav", loop = true, at = { body = id } }   -- the voice follows the body's centre of mass every tick (E25): one looping voice per train car, no seams
sound.move(d, x, y, z)       -- a positional voice goes to a place (metres) now; a script that moves a source itself calls it every tick
sound.bus("music", 0.5)       -- the volume of a bus (sfx, music, voice), 0..2: a game's sliders
```
**Moving voices (E25)**: `at = { body = id }` starts the voice at the body's centre of mass and moves it there at the start of every tick; the follow ends with `sound.stop(h)`, with the end of a one-shot sample, or with the body (a looping voice whose body is gone fades out over 0.25 s; a body that does not exist when `sound.play` is called gives `nil`). `sound.move(h, x, y, z)` moves any positional voice once (a 2D voice has no place and ignores it); a voice that follows a body is put back by the body next tick. The pan and distance follow smoothly (the channel gains are interpolated within each audio block); there is no Doppler, and the speed-of-sound delay is fixed when the voice starts. Cosmetic like all handles: nothing in a hash or a recording, up to 256 followed voices at a time (the oldest stops being followed).
**Unloading (E28)**: `sound.unload("music/hall.wav")` (or the number `sound.load` gave) frees the sample's memory and returns true. It returns false and frees nothing while a voice plays the sample (a stopped loop is free once its fade has ended; a sound started in the last 3 ticks counts as playing) and when the sample was not loaded. A later `sound.play{ file = ... }` loads the file again. At most 256 samples are in memory at once (an unloaded one frees its place); the numbers of unloaded samples are never reused, so an old number plays nothing instead of another file. A game loads a floor's stems on entering it and unloads them on leaving.
**Stems (E27)**: the events of one frame (every `sound.play` and control a tick's scripts made) reach the engine under ONE hold of its lock (`AudioEngine::postAll`), and the sound card's thread renders a block under the same lock, so four loops started in one tick begin on the same output sample on the card as well as offline. Voices of identical length, rate and pitch 1.0 then stay locked. A loop is N-1 samples long (the last sample is not played: end a stem on its first sample's value to hide it), files are read at their own rate with linear interpolation (deliver music at 44.1 or 48 kHz), stereo files are mixed to mono on load, and a loaded sample stays in memory until `sound.unload` (32-bit float mono, 4 bytes per file sample; 256 at a time).
**Doors**: `events.door{ ..., sound = false }` leaves out the engine's own creak and thud for that door (default true: unchanged), for a game that plays its own sounds for a stone slab or a drawbridge (E26).
`sound.play{...}` returns a **handle** (a number). The old call `sound.play(file, x, y, z, volume, pitch)` is unchanged (positional, fire and forget). A loop plays until it is stopped; the 64 voices are shared with the rest of the engine, a script's sounds are not stolen by a pile of impacts. Everything here is cosmetic: the handle table lives in the script host, handles are not in any hash or recording, and a machine without sound simply ignores them.
**`voxelith --audio-out file.wav`** renders what a headless run, a replay or an MCP session would have played, tick by tick (800 frames at 48 kHz per tick, the same engine as the sound card), and writes the WAV when the program ends: `voxelith --replay log --audio-out run.wav` is how the sound of a recorded session is heard on a machine with no sound card (`--audio-demo` is the same engine on a tour of the built-in sounds).
