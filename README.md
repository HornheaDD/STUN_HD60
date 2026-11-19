# S.T.U.N. Runner 60fps

Atari's **S.T.U.N. Runner** (1989 arcade) at a real **60 frames per second** and the correct game speed, running in a
lightly patched MAME 0.285 plus a Lua script.

The original game draws a new image only every third refresh (about 20 fps), and its logic advances once per drawn frame,
so simply unlocking the frame cap makes the whole game run three times too fast. This project keeps the game logic at its
native 20 ticks per second and asks the game's **own 3D hardware** (the ADSP-2100 math board) to render two extra
in-between frames per tick, with the camera and moving objects interpolated. The in-between images are real renders of
the scene, not blended or AI-generated frames.

Also included: an optional CRT look (MAME BGFX `crt-geom` shaders, toggled in-game with **C**), an on-screen
statistics overlay (**O**), and portable Linux (AppImage) and Windows packages.

`hd-experiment/stun60-sidebyside-realtime.mp4` shows 20 fps vs 60 fps from an early offline test
(its HD redraw is a separate experiment, not part of the live build yet).

**Download:** ready-to-run Linux (AppImage / tar.gz) and Windows builds are on the
[Releases page](https://github.com/HornheaDD/STUN60/releases/latest).

**No ROMs are included.** You need your own MAME 0.285 `stunrun.zip` (parent set).

## How it works (short version)

* `stunrun-interp60.lua` watches the 68010 main CPU hand each per-tick camera/object job to the ADSP. After the real job,
  it snapshots the ADSP state and replays the job twice with the camera and objects interpolated at t = 1/3 and 2/3,
  then publishes those display lists to the TMS34010 video CPU one refresh apart, and releases exactly one game tick
  per three refreshes.
* This needs far more emulated CPU time than the real hardware had, so the patched driver overclocks the 68010 (x3),
  GSP (x4) and ADSP (x8), set through the `STUN60_CLOCK` environment variable.
* The patch (`stun60-mame0285.patch`) also adds a few helper commands for the script (fast ADSP state snapshot/restore,
  output capture, list building), fixes a sound-latch status bit that loses music commands at higher clocks,
  adds a small Lua binding used for the CRT toggle, and fixes a BGFX bug when a view switch changes the screen's pixel format.

`CLAUDE.md` is the full research and development log (memory maps, protocols, measurements, dead ends).

## Build and run (Linux)

```sh
./build.sh                 # downloads MAME 0.285 source, applies the patch, builds build/mame-mame0285/stun60 (~5-20 min)
cp /path/to/stunrun.zip roms/
scripts/run-stun60.sh      # uses ~/mame/... paths: clone the repo to ~/mame, or edit the script
```

`./build.sh package` builds the portable variant used for the AppImage (see `package/`), and `./build.sh windows`
cross-compiles `stun60.exe` with MinGW-w64.

Controls: MAME defaults (5 = coin, 1 = start, Tab = menu, Esc = quit), **O** = overlay, **C** = screen effect
(CRT deluxe / CRT sharp / off). See `package/README.txt` for the end-user notes.

## Repository layout

| Path | What |
|---|---|
| `stun60-mame0285.patch` | All source changes to MAME 0.285 (`src/mame/atari/harddriv*`, `src/frontend/mame/luaengine.cpp`, `src/osd/modules/render/bgfx/chainmanager*`) |
| `scripts/stunrun-interp60.lua` | The 60 fps interpolation script (older versions kept as `.v*`) |
| `scripts/run-stun60.sh` | Local launcher |
| `scripts/re-probes/` | Reverse-engineering probes and headless test drivers (`live_test.lua` = scripted game + verify) |
| `hd-experiment/` | Offline HD redraw and interpolation experiments (tools, images, videos) |
| `package/` | AppImage and Windows launcher sources, glibc compatibility shim, end-user README |
| `stun60-live-*.log` | Logs from live play sessions (per-second fps / tick / timing stats) |

Disassemblies and memory dumps of the game are not included (they are derived from the copyrighted ROMs);
the probes in `scripts/re-probes/` regenerate them from your own ROM set.

## Credits and license

Built on [MAME](https://www.mamedev.org/) 0.285. The MAME source files changed by `stun60-mame0285.patch`
(`harddriv*.cpp`, `harddriv.h`, `luaengine.cpp`, `chainmanager.*`) are BSD-3-Clause, and the patch keeps their license.
Binaries built from it are MAME builds and fall under MAME's overall license (GPL-2.0-or-later).
Everything else in this repository (scripts, tools, packaging) is under the MIT License, see `LICENSE`.
S.T.U.N. Runner is © 1989 Atari Games. This project is not affiliated with Atari or the MAME team.
