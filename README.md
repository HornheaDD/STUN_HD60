# S.T.U.N. Runner HD60

Atari's **S.T.U.N. Runner** (1989 arcade) at a real **60 frames per second** and the correct game speed, with the 3D scene
**redrawn in high resolution** (1536x1200), running in a lightly patched MAME 0.285 plus a Lua script.

This is the continuation of [STUN60](https://github.com/HornheaDD/STUN60) (60 fps only, v1.0), which stays as the classic
release. Everything from STUN60 is included here; press **H** in-game to switch between the HD redraw and the original
512x240 picture.

**60 fps:** the original game draws a new image only every third refresh (about 20 fps), and its logic advances once per
drawn frame, so simply unlocking the frame cap makes the whole game run three times too fast. This project keeps the game
logic at its native 20 ticks per second and asks the game's **own 3D hardware** (the ADSP-2100 math board) to render two
extra in-between frames per tick, with the camera and moving objects interpolated. The in-between images are real renders
of the scene, not blended or AI-generated frames. Objects the original animates as a flipbook of fixed 3D models (the iris
gates at the tunnel mouths, the spark burst when a shot hits, the flapping bird, the star after a hit, the wobbling drop) are
morphed model to model so they move smoothly too: parts are matched between consecutive models and the blend is rendered by
the game itself (`STUN60_MORPH=0` turns this off).

**HD redraw:** the patched driver reads the game's own polygon list (already projected to the screen by the game) and
redraws every 3D polygon at 3x5 the resolution on a second screen, with the game's colours. Polygon edges are anti-aliased
(2x2 supersampling of the pixels an edge crosses, so neighbouring polygons stay seamless; `STUN60_HDAA=1` turns it off,
3 or 4 = finer). The game's scaled 2D sprites (the spark flash when a shot hits, the zooming story panel in the attract
mode) are redrawn from their source images at HD resolution too. The polygons are drawn by several threads (`STUN60_HDTHREADS`, default half the CPU threads, up to 4), and the whole HD
picture is drawn in the background while the next frame is emulated, so it appears one frame (17 ms) after the original
picture (`STUN60_HDSYNC=1` draws it without that delay, at the cost of emulation speed). The wireframe the vehicle turns into on a
boost, and scenes drawn entirely as wireframe, are redrawn as smooth thin lines (`STUN60_HDLINE` = line width in HD
pixels, default 2); the see-through dissolve at the start of a boost is redrawn as a smooth transparent fill. Everything that is not 3D
(HUD, text) is taken from the original picture and scaled up.

**HD backgrounds:** the skyline panoramas behind the track (canyon, hills, plains, farmland, city, galaxy) are the game's own
artwork, unpacked from your ROM and upscaled with the AI upscaler [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)
(`realesrgan-x4plus` model). No artwork is included in this repository or in the downloads: it is made on your PC from
your own `stunrun.zip`.

What happens on first launch:

* The game starts **immediately**, at 60 fps with the HD 3D scene; the skylines show the original pixels at first.
* In the background, at the lowest priority, the game unpacks the backgrounds from the ROM and upscales them (35 images, including the level-start city screens, the title screen, course map and HUD).
  Level 1's skyline comes first. Each skyline switches to HD on its own as soon as it is ready; no restart is needed.
* On a gaming graphics card this takes about 50 seconds in total; the title screen, HUD, course map and level 1's skyline
  are ready after about 20 seconds. A slower graphics card only means the original pictures stay a little longer.
* The finished pack is saved in the game's data folder (about 25 MB), so later launches are HD from the start.
* Real-ESRGAN needs a graphics card with Vulkan support. Without it, the game keeps the original skylines and notes this in
  its log; nothing else changes.

The colours follow the game's live palette, so fades still work, and anything drawn over a skyline (HUD, text) stays as in
the original. The level-start city screens are upscaled the same way (night scenes use the `realesr-animevideov3` model,
which keeps the small window lights). So are the full-screen pictures: the title screen, the course map shown between
levels, the HUD panel and the high-score frame (the pixels are doubled before upscaling, which keeps small lettering correct).

**Smooth 2D:** text, HUD numbers, the course map's track line and the speed bars are drawn live by the game; in HD they
are smoothed with the xBR pixel-art filter (`STUN60_HDXBR=0` turns it off).

Press **Y** in-game to turn the HD title screen, course map, HUD panel and the smoothed text off (the original pixels,
scaled up, as before) and on again; the choice is remembered. The 3D scene and the skylines stay HD.

Also included: an optional CRT look (MAME BGFX `crt-geom` shaders, toggled in-game with **C**), an on-screen
statistics overlay (**O**), and portable Linux (AppImage) and Windows packages.

**Planned:**

* Possibly a **widescreen (16:9) hack**: widening the game's 3D view so it fills modern screens, with the HUD kept
  centred. Not started yet; it depends on how far the game's own projection and clipping limits can be pushed without
  objects popping in at the edges.

**Download:** [S.T.U.N. Runner HD60 v1.5](https://github.com/HornheaDD/STUN_HD60/releases/latest) for Windows x64 and
Linux x86-64 (AppImage or tar.gz, about 50 MB each, Real-ESRGAN included).
The 60 fps-only builds are on the [STUN60 Releases page](https://github.com/HornheaDD/STUN60/releases/latest).

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

For the HD backgrounds, unzip the official `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` from the
[Real-ESRGAN v0.2.5.0 release](https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0) into `build/tools/realesrgan/`
(the launcher finds it there; `STUN60_ESRGAN` = path to the program, `STUN60_HDPACK` = pack folder, default `hdpack/pack`).
`hdpack/build_pack.py` builds the same pack offline (reference implementation), `hdpack/stunbg.py` extracts the raw images.

`./build.sh package` builds the portable variant used for the AppImage (see `package/`), and `./build.sh windows`
cross-compiles `stun60.exe` with MinGW-w64.

Controls: MAME defaults (5 = coin, 1 = start, Tab = menu, Esc = quit), **O** = overlay, **C** = screen effect
(CRT deluxe / CRT sharp / off), **H** = HD redraw / original picture. `STUN60_HD=` (empty) starts without the HD screen. See `package/README.txt` for the end-user notes.

## Repository layout

| Path | What |
|---|---|
| `stun60-mame0285.patch` | All source changes to MAME 0.285 (`src/mame/atari/harddriv*`, `src/frontend/mame/luaengine.cpp`, `src/osd/modules/render/bgfx/chainmanager*`) |
| `scripts/stunrun-interp60.lua` | The 60 fps interpolation script (older versions kept as `.v*`) |
| `scripts/run-stun60.sh` | Local launcher |
| `scripts/re-probes/` | Reverse-engineering probes and headless test drivers (`live_test.lua` = scripted game + verify) |
| `hdpack/` | Background extractor and offline pack builder (the game builds the pack itself on first launch) |
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
Real-ESRGAN (realesrgan-ncnn-vulkan) is by Xintao Wang et al., BSD-3-Clause; it is run as a separate program.
S.T.U.N. Runner is © 1989 Atari Games. This project is not affiliated with Atari or the MAME team.
