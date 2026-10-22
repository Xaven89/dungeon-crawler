# Accessibility

Settings (in `settings.ini`, `--setting key=value`, or the Settings panel's "accessibility" section; the panel changes them live):

| setting | values | what it does |
|---|---|---|
| `subtitles` | on / off | a caption for every sound that matters: what, which way, how far. Works with the sound card off. |
| `ui_scale` | 0.75 .. 2 | the size of the script's HUD (docs/HUD.md) and of the captions (the virtual space of `ui.*` is 1080 / ui_scale units high, so a script that lays out by `ui.size()` follows). |
| `colorblind` | off, protanopia, deuteranopia, tritanopia | a colour assist in the final pass: the picture is simulated for that kind of colour vision (Vienot 1999) and what is lost is moved into the channels that remain, so reds and greens that look alike differ in brightness / blue. |
| `reduce_motion` | on / off | no wind in the grass (the sway). |
| `hud_scale` | -1 .. 3 | the size of the built-in debug HUD text (older setting). |
| `toggle_sprint`, `toggle_jetpack` | on / off in `input.cfg` | press to start, press again to stop (hold-to-toggle; docs/INPUT.md). |
| `language` | a code | the language of the game's text (docs/LOCALIZATION.md). |

## Subtitles
Every event the audio engine would play (an explosion, an impact, a splash, digging, rubble, a door, a click, a tone, a sample from `sound.*`) can make a line: `explosion - left, 20 m`. Rules: things too small to matter (an impact slower than 3 m/s or small, or within 3 m of the listener (their own feet, their own vehicle), a splash that is only a drop) and the player's own steps and landings are left out, nothing over 80 m, the same kind from the same direction refreshes its line instead of adding one, at most five lines, three seconds each with a fade. The direction is relative to where the player looks (left, right, ahead, behind, above, below, here within 1.5 m).

The words are the localizer's keys, English built in: `caption.explosion`, `caption.impact`, `caption.splash`, `caption.dig`, `caption.crumble`, `caption.door`, `caption.click`, `caption.tone`, `caption.sample`, the directions `caption.left` .. `caption.below`, `caption.here`, and the layout `caption.line` (`{1} - {2}, {3} m`: what, direction, metres). A project's `strings/<lang>.csv` overrides any of them (a German `caption.line,{1} nach {2}: {3} m`). Sounds a script plays with `sound.play` appear as `caption.sample` ("sound"); a script that wants better words for its own sounds draws them itself from `on_hud` (docs/HUD.md).

## Not built
Colour presets for individual materials (the assist is a post effect, not a palette), high-contrast outlines, a screen reader for the panels, text-to-speech, remapping of the mouse look to a stick beyond what docs/INPUT.md has, reduced camera motion on gravity flips (the camera follows the up vector with a lag; a slider for it is the next step), and a flash / flicker limiter (lamps do not flicker; explosions flash once).
