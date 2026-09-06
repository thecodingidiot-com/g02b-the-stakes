# g02b-the-stakes

Companion repository for **g02b — The Stakes** at
[thecodingidiot.com](https://thecodingidiot.com).

---

## Follow my journey

Working through g02b alongside the implementation pages? Build
`platformer` step by step, then run the tester.

Clone this repository — it carries everything needed, including the
`libtci/` subdirectory with all library source, the same pattern
[g02a](https://github.com/thecodingidiot-com/g02a-the-platformer) used:

```bash
git clone https://github.com/thecodingidiot-com/g02b-the-stakes.git g02b-practice
cd g02b-practice/solution
make -C libtci re
bash gen_assets.sh
bash gen_audio.sh
make re
bash ../test.sh
```

All tests must pass before the chapter is complete.

---

## Follow your journey

Building `platformer` independently? Here is the full project brief.

g02b starts from g02a's finished platformer and adds sound:

- Two new tile types — a coin (`*`) that plays a chime and adds to a
  score when collected, and a hazard (`^`) that plays a death sound
  and resets the player to the start of the level.
- Reaching the goal tile plays a fanfare and resets the level, same
  shape as a hazard death.
- Jumping and landing each get their own short sound effect.
- A looping background track via `SDL2_mixer`, halted and restarted
  whenever the level resets.
- Every event above is decided by the SDL2-free logic layer (an
  `EVENT_*` enum returned from `player_handle_input`,
  `player_resolve_collision`, `map_try_collect`, `map_check_hazard`,
  and `map_check_goal`) — only `audio.c` turns an event into an actual
  `Mix_PlayChannel`/`Mix_PlayMusic` call, the same separation
  `render.c` already keeps for drawing.

Source is split by concern, one file per module (unchanged from g02a
unless noted):

| File | Contents |
| --- | --- |
| `main.c` | SDL2 + SDL2_mixer init, the game loop, cleanup |
| `map.c` / `map.h` | tile map, tile queries, **new**: coin/hazard/goal event checks |
| `player.c` / `player.h` | physics, collision, animation — **changed**: input/collision now return an event |
| `camera.c` / `camera.h` | follow + clamp + the world-to-screen transform |
| `render.c` / `render.h` | the only file that calls actual SDL2 drawing functions |
| `audio.c` / `audio.h` | **new** — the only file that calls actual SDL2_mixer functions |
| `event.h` | **new** — the shared `t_event` enum |

`map.c`, `player.c`, and `camera.c` still never call an SDL2 (or
SDL2_mixer) function — only compile-time constants/types where needed
— so they link into a test binary with neither library at all.

Build and test your own version first. Use `solution/` to compare
once you are done, not before.

---

## Building the solution

```bash
cd solution
make -C libtci re
bash gen_assets.sh
bash gen_audio.sh
make re
./platformer ../fixtures/level1.txt
```

Controls: Left/Right arrows (or `h`/`l`) to move, Space to jump,
Escape or `Q` to quit.

`gen_assets.sh` and `gen_audio.sh` need Python3 + Pillow (stdlib
`wave` covers the audio synthesis — no extra package):

```bash
sudo apt install python3-pil libsdl2-mixer-dev
```

Every sound effect and the background track are synthesized locally
by `gen_audio.sh` — own-work square/sine waves, not sourced from
anywhere — so there is nothing to attribute and no license file for
`assets/*.wav` beyond this repository's own MIT license.

---

## What the tester checks

**Build** — the real game compiles and links with zero warnings.

**A standalone logic tester** — `map.o`, `player.o`, and `camera.o`
compiled and linked with `libtci.a` alone, no SDL2 or SDL2_mixer at
all, asserting real outcomes against `fixtures/test-map.txt`:

- Every check g02a's own tester made (falling, walking into a wall,
  camera clamping) — the fixture map keeps the same geometry.
- A jump input while grounded returns `EVENT_JUMPED`; airborne with no
  input returns `EVENT_NONE`.
- Landing after a fall returns `EVENT_LANDED` exactly once, not every
  frame at rest.
- Standing on the coin tile returns `EVENT_COLLECTED` and removes it;
  collecting it again returns `EVENT_NONE`.
- Standing on the hazard tile returns `EVENT_DIED`; standing away from
  it returns `EVENT_NONE`.
- Standing on the goal tile (`map.goal_x`/`goal_y`, loaded from the
  fixture's `G` marker) returns `EVENT_WON`.

**`platformer`** — runs its event loop for two seconds under a
headless (`SDL_VIDEODRIVER=dummy`, `SDL_AUDIODRIVER=dummy`) driver
without crashing. A smoke test, not a visual or audible check —
actually playing the level is done by running it yourself.

---

## License

MIT License. See [LICENSE](LICENSE).
