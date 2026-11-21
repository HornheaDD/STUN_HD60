# S.T.U.N. Runner 60fps: project notes for Claude

These notes live in the public git repo https://github.com/HornheaDD/STUN_HD60 (remote `hd`, local clone ~/mame, main tracks hd/main;
the older https://github.com/HornheaDD/STUN60 = 60 fps-only v1.0, frozen). Machine-specific and private details (NAS, network, delivery locations,
backups) are in ~/CLAUDE.md on the user's PC and must NOT be copied here. Paths below assume the repo is ~/mame.
Build tree (not in git): ~/mame/build/mame-mame0285 = MAME 0.285 source + stun60-mame0285.patch. ROMs (not in git): ~/mame/roms.

## CURRENT STATE (2026-11-21). Start with this section.
**STUN_HD60 hd-v1.5 RELEASED (2026-11-21), paused for the day.** HD title screen / course map / HUD panel / high-score frame
(Real-ESRGAN, pixels doubled first), xBR-smoothed live 2D text, **Y key** toggles those 2D extras off/on (remembered in
stun60-hd2d.txt in the data dir; passed to C++ as MAME output value `stun60_hd2d_off`, read on the emulation thread before
each HD compose -> m_hd_2d), and the **HD pack compressed** (S60BG04 = zlib planes R,G,B,pen; S60BG03 still read, the builder
thread rewrites 03 files as 04 in the background: 35 files in 3.8 s, 135 MB -> 24 MB, lossless). User feedback before the
toggle: "looks ok, but I can see some people not liking that option", didn't like the pack nearly doubling.
- Release: new binaries (./build.sh package + windows), stripped into package/STUNRunnerHD60.AppDir and
  package/out-hd/STUNRunnerHD60-windows/bin; archives in package/out-hd/ (v1.4 copies in out-hd-v1.4/; notes source
  package/out-hd/notes-v15.md, ignored). Tests: verify 1815/1815, drawn 51.9 / ticks 19.00 (= v1.4), 160% unthrottled with HD
  always on; Y toggle snapshot check; AppImage fresh HOME: 35 images in 68.5 s, 24 MB, 60 fps / 20 ticks; Windows zip under
  Wine 11 (fresh prefix, launcher): 35 images, byte-identical to the Linux pack, 60 / 20.
- The user's own ~/mame/hdpack/pack is still S60BG03 (135 MB) until their next launch converts it (automatic).
- Empty-pack first launch: title/HUD/map + level 1 skyline at ~19 s (skyline alone used to be 3.5 s), all 35 at ~52 s.
Details: "HD whole screens + xBR text" at the end. Possible follow-ups (ask): story-panel sprite 02 via Real-ESRGAN (its
text is still resampled source pixels), xBR look of the HUD "0" digits (pointy tips), python build_pack.py parity (it still
writes S60BG03; fine, converted by the builder), widescreen 16:9 probe.
Released before: STUN_HD60 **hd-v1.4** (2026-11-20): HD anti-aliasing, HD sprites, HD compose pipeline (1 frame HD delay), pilot
walk glide; new binaries (Linux package build + Windows). Before that hd-v1.3 (model morph, script-only).
- v1.4 packages now in package/out-hd-v1.4/ (v1.3 in out-hd-v1.3/; notes source package/out-hd/notes-v14.md, ignored).
  Smoke tests: tar.gz scripted verify 700/700 (fake HOME), AppImage boots, fresh-HOME AppImage at normal speed built all 27
  HD backgrounds (level 1 at 9.7 s, all 39.9 s with the user's browser loading the PC), Wine run 60 s with HD always on:
  AA 2x2 4 threads, morph on, 198%, clean exit.
- Verify baseline with the new script: normal course 1774/1774, Advanced 1814/1814 and (fresh nvram, to frame 11000) 1891/1891.
- Untracked local-only files (keep out of git): hd-experiment/live-hd/Screenshot_*.png, gate-morph-compare.gif,
  wireframe-*-compare.png, wireframe-full-zoom.png.
- **Headless test runs: always add `-cfg_directory D -nvram_directory D` (D = a scratch folder).** `-inipath ~/.mame` alone
  makes them write the user's real ~/.mame/nvram/stunrun + cfg/stunrun.cfg (happened 2026-11-20; cfg showed chain="default"
  afterwards, unclear whether that was the user's choice). Fresh nvram also makes runs deterministic (the Advanced run then
  reaches the bird at ~frame 8490).
- Shell gotcha: `pgrep -f X` / `ps | grep X` wait loops match their own bash command line if it contains X. Use a pattern
  that only the MAME process line has, or wait on a PID.
- Details: "HD anti-aliasing", "HD sprites", "HD compose pipelined", "Pilot walk glide" at the end. v1.3 dev binary kept as
  build/stun60.v13-binary.
- Other candidate work (ask the user): widescreen 16:9 probe.
- Release recipe for HD60: see "HD packages built and RELEASED" and the hd-v1.1/hd-v1.2 notes at the end.

## Earlier pause (2026-11-18, evening), history
Done today on CachyOS: setup from the migration bundle + first live run (59.5 fps in 3D play); CRT scanlines via BGFX with the
C key (custom Lua binding stun60_slider); attract-screen "dip" explained (static story panel, GSP-bound) + false "overclock too
low" warning fixed; portable packages rebuilt (Linux glibc >= 2.36, Windows 10/11); project put on git/GitHub.
- Repo: https://github.com/HornheaDD/STUN60 (public, MIT; patch BSD-3-Clause). Local clone = ~/mame, branch main, in sync.
  Commits use the repo-local noreply identity (already configured). `gh` is installed and logged in.
  **Before every commit:** scan tracked files for IPs, NAS paths, /home/<user> paths and emails; never commit ROMs or
  ROM-derived data (see .gitignore). Private/machine notes belong in ~/CLAUDE.md only.
- Release v1.0 (2026-11-18): AppImage, linux tar.gz, windows zip from package/out/ (built from tag v1.0; SHA-256s in the notes).
  New release: rebuild (./build.sh package, ./build.sh windows, then assemble as in "Packages rebuilt" below), run the verify test,
  commit, `gh release create vX.Y --target main --notes-file ... files`, and re-download the assets to check checksums.
- Local launcher: "S.T.U.N. Runner 60fps (custom MAME)" (scripts/run-stun60.sh), CRT deluxe saved as the user's choice.
- **Next (agreed plan): HD redraw at 4:3** (live renderer in the custom build, from the decoded display list + colours; see
  "HD redraw experiment" and "Colour decode DONE" below), then a widescreen probe. Estimate given: first live HD frames ~3-4 h,
  finished + packaged ~2 days.
- Backburner: choppy sound on the user's real Windows PC (later check seemed OK); "extra 1 missed (rendered true)" ~0.25/s.

## HD redraw, stage 1 DONE (2026-11-18, late): working prototype, local commits only (user: push after review)
- Custom build: STUN60_HD="SXxSY" (default in run-stun60.sh: 3x5 = 1536x1200; empty = off, identical to before) adds a second
  screen ":mainpcb:hdscreen" (rgb32). Code in harddriv_v.cpp (hd_config/hd_start/hd_parse_list/hd_capture_line/hd_compose),
  members in harddriv.h; patch now covers harddriv_v.cpp too (stun60-mame0285.patch; .orig kept).
  - Which list is on screen: GSP write tap FFF71680 (nonzero = draw done: list address at FFF77F30 lo / FFF77F40 hi, i.e.
    mailbox+0x10; parse it -> pending), FFF71680 <- 0 at the vblank flip -> shown. Each low-res frame is captured in
    scanline_multisync (row 0 latches the shown list; bottom row completes the frame and composes HD right then).
  - 3D block = first 0x7000 word in the list whose offset table validates (FFFF-terminated, offsets < count). Polys parsed
    like dec.py (32.32 accumulators, frac .5); flags bit15 skip, bit12 alt handler skipped (left to the low-res image).
  - Compose: rasterize polys at low res exactly like the GSP -> expected pen per pixel; classify each playfield pixel
    3D (frame pen == expected), "over" (something drawn on top: keep low-res), bg. Scale the low-res frame up SXxSY
    (3D pixels get the nearest non-3D row neighbour as background), then draw polys at HD in list order: edges interpolated
    between line samples (lines sampled at row centres), half-line ends may only narrow (no needles), half-open fill rule
    [xl, xr+1), shadow mode 2 = 30% darken instead of 1-in-4 dither. Skipped where a low-res pixel is "over". Rows 0-207 only.
  - Colours: palette()->entry_list_adjusted() (NOT pens(): those are indices -> blue garbage). Force alpha 0xff.
  - Cost on the Ryzen: ~1 ms classify+scale + 0.6-1.5 ms polygons per frame; headless speed 310% -> ~210%. Composed only
    while the HD screen is in view (render().is_live) unless STUN60_HDALWAYS/STUN60_HDDEBUG (tests; debug prints class
    counts + timing every 300/600 frames). Classification: 99.5% of polygon pixels match (the rest = genuine overlays).
  - Main screen gets VIDEO_ALWAYS_UPDATE when HD is on (it isn't "live" in the HD view but we need its scanlines).
- Script (prev .v4g): H toggles HD/original by switching render.ui_target view ("Screen 1 Standard (4:3)" / "Screen 0 ...");
  remembered in stun60-hd.txt (default on); overlay/messages drawn on the screen in view (dbox/dtext scale by SX,SY).
  The C key (CRT chain) works in the HD view too ("Window 0, Screen 0 Effect" = first screen of the current view).
- Tests: verify 3553/3553 exact to level 4 with HD in view (58.5 fps, 19.96 ticks); HD off = unchanged (677 exact, 60.0 fps).
  Display alignment: HD view frame N == original view frame N (no lag). Measure with MAME snapshots of single-screen views
  (-snapview "Screen N Standard (4:3)", two deterministic runs); screen:pixels() reads a swapped buffer (looks 1 frame off),
  and headless snapshots of the 2-screen views show the HD screen black (not a real problem).
- Comparison images for the user: ~/mame/hd-experiment/live-hd/ (compare-frameNNNNN.png side by side, zoom-*, hd-*).
- Next: user reviews the images + plays live (H toggles, C = CRT on top of HD). Ideas: anti-aliasing (2x2 supersampling of
  edges), 16:9 widescreen probe, packaging (HD in AppImage/Windows), cheaper compose for slower CPUs (threads).

## Current state (CachyOS, 2026-11-18)
- **Setup DONE 2026-11-18:** ~/mame/build/mame-mame0285/stun60 built in ~5 min (-j16). Verify test: 60.0 fps, 20.00 ticks/s,
  677/677 exact. Launcher stunrun-60fps-custom.desktop in ~/.local/share/applications + ~/Desktop (-> run-stun60.sh).
  **First live run on CachyOS (2026-11-18, log ~/mame/stun60-live-2026-11-18.log, ~8 min):** 3D gameplay 392 s at 59.5 fps
  (only 6 s < 55), ticks 19.95, wall avg 0.997 / max 1.007, late 0.03/s, 0 stale/bad output/ERR. hostmon (~/mame/hostmon-cachyos.log):
  3.65 GHz avg, max 61 C, MAME ~51% CPU. 88 s were transition screens (no 3D block, ~26 fps, legit). Only real dip: 39-44 s,
  gd jumped 0.30 -> 0.80 with jd 0.04, extras rendered but "extra missed (rendered true)" then all dropped until the level end;
  suspect the gd estimate sticks high once extras are dropped (cf. jd probe fix). Minor; not investigated.
  **SOLVED (2026-11-18): not gameplay.** It is the attract-mode story panel ("Sometime in the future... S.T.U.N. Running, the
  Ultimate Challenge", frames ~2400-2700 after boot; the user's live dip was before inserting a coin). Measured GSP draw time
  (FFF77F30 list taken -> FFF71680 done) = a constant 2.13 refreshes per list at gsp x4 (1.42 at x6, 1.06 at x8; normal frames
  0.03-0.15), so no clock fixes it and the panel is static once zoomed in -> left as is. Real bug found there: the red
  "Overclock too low" warning fired after it (live run at 42 s). Fix: warning now needs >=10 ADSP-time skips/s (adsp_skips),
  text now "Emulated ADSP too slow for 60 fps / Raise adsp in STUN60_CLOCK". Tests: attract adsp=8 no warning; adsp=1 warns;
  verify 60.0 fps / 20.00 ticks / 677 exact. Script prev: stunrun-interp60.lua.v4f. Probe: scratchpad drawprobe.lua (gone).
  **CRT scanlines (2026-11-18):** MAME BGFX shaders work with the custom build (60 fps kept). User likes crt-geom-deluxe.
  run-stun60.sh now ALWAYS uses -video bgfx -bgfx_path $B/bgfx -artpath "~/.mame/artwork;$B/artwork" (the crt chains load
  textures from artwork/bgfx/...; without our artpath they only worked via the distro MAME's /usr/lib/mame/artwork).
  One launcher (stunrun-60fps-custom.desktop); the CRT/SYNC test launchers were removed. In-game toggle:
  Tab > Slider Controls > "Window 0, Screen 0 Effect"; saved in ~/.mame/cfg/stunrun.cfg (<window><screen chain=...>).
  Tested precedence: cfg is honoured only when no chain is given in a system ini or on the command line (those override it).
  So the script passes crt-geom-deluxe only if the cfg has no chain yet (first-run default = CRT on).
  STUN60_CRT=deluxe|geom|off forces one for a launch. Old script: run-stun60.sh.bak-20261118.
  **C key (2026-11-18):** cycles crt-geom-deluxe -> crt-geom -> default (on-screen message 2.5 s; saved in cfg like the menu).
  Needs a new Lua binding in the custom build: luaengine.cpp `manager.ui:stun60_slider(name [, newval])` -> value, text, min, max
  (OSD sliders first, then UI sliders; .orig kept). The script finds the chain slider values on first use (deluxe=4, geom=3 here;
  none=0, default=1 always). Each switch costs 0-3 ms. Script prev version: stunrun-interp60.lua.v4e. Test driver pattern:
  dofile the script, call global STUN60_CRT_CYCLE() from a frame notifier (needs a window, -video bgfx).
  Full source patch now ~/mame/stun60-mame0285.patch (257 lines: harddriv.cpp/.h/_m.cpp + luaengine.cpp); the bundle's 207-line
  patch lacks luaengine. Regression after rebuild: 60.0 fps, 20.00 ticks, 677/677 exact.
  Not yet in the AppImage/Windows packages (need rebuilt binaries, bgfx/ + artwork/bgfx/ bundled, -video bgfx, the same artpath).
  Don't take screenshots with spectacle -a: the active window may be the user's browser, not MAME.
  Sync test: STUN60_SYNC=1 adds -syncrefresh -waitvsync (speed 99.62%, 60 fps, 20 ticks). User felt the NON-sync version
  ran smoother -> not used (option kept in the script). Monitors: 60.00 Hz HDMI / 59.95 Hz DP, game ~60.2 Hz.
  hostmon.sh now auto-picks k10temp/coretemp (Ubuntu copy kept as hostmon.sh.ubuntu). portaudio prints JACK/ALSA probe noise to stderr (harmless). Launching from Claude's shell on KDE: DISPLAY=:0 WAYLAND_DISPLAY=wayland-1
  XAUTHORITY=$(ls /run/user/1000/xauth_*|head -1) (untested). Rebuilds: use -j16.

- **Packages rebuilt on CachyOS (2026-11-18)** and delivered to the user (where: private ~/CLAUDE.md). Deliverables in
  ~/mame/package/out/. Both now: -video bgfx, bgfx/ + artwork/bgfx/ bundled, C key, first-run CRT deluxe, STUN60_CRT. README updated.
  - Linux: binary needs glibc >= 2.36 (was 2.43): link shim ~/mame/package/linux/glibc_compat.c/.o maps 2.38+ symbols
    (math, __isoc23_*) to old versions via -Wl,--wrap (list in wrapflags.txt); static libstdc++/libgcc; NO_USE_PIPEWIRE=1.
    Remaining 2.35/2.36 refs (_dl_find_object, arc4random) come from static libgcc/libstdc++. Bundled libs: libSDL3 built from
    source 3.4.20 (sha512 = Arch's) with the shim and -DLIBC_HAS_{STRLCPY,STRLCAT,WCSLCPY,WCSLCAT}:INTERNAL=0 (glibc 2.34);
    sdl2-compat + sdl2_ttf = Arch *generic* packages (CachyOS repos are x86-64-v3, never bundle those). No old-distro run test
    (docker daemon not running); verified by symbol versions only. Old AppRun kept as package/linux/AppRun.v1.
  - **The dev binary ~/mame/build/mame-mame0285/stun60 is now this package build.** Rebuild command (add REGENIE=1 when flags change;
    make doesn't recompile on define changes, delete the affected .o files):
    make SUBTARGET=stun60 SOURCES=src/mame/atari/harddriv.cpp NOWERROR=1 USE_QTDEBUG=0 TOOLS=0 TESTS=0 OPTIMIZE=2 NO_USE_PIPEWIRE=1
    LDOPTS="-static-libstdc++ -static-libgcc $(cat ~/mame/package/linux/wrapflags.txt) $HOME/mame/package/linux/glibc_compat.o" -j16
  - Windows: same tree, PATH=~/mame/build/mingw64/bin:$PATH make TARGETOS=windows CROSS_BUILD=1 MINGW64=$HOME/mame/build/mingw64
    PTR64=1 ... -j16 (~4 min). Arch MinGW = UCRT -> Windows 10/11 only; system DLLs only. Launcher win/launcher.c updated (bgfx,
    artpath data\artwork;bin\artwork, chain logic; old = launcher.c.v1), built with -municode -mwindows -static.
    Wine 11 tests: 60.0 fps / 20.00 ticks / 677 exact; launcher + bgfx OK, saved chain crt-geom-deluxe.
  - Use `ps -eo args | grep [s]tun60`, not `pgrep -f stun60.exe` (matches its own shell command).

## MAME tips (written on the old Ubuntu laptop; the apt/desktop-shortcut parts are obsolete)
- MAME 0.285 from apt. ROMs: `~/mame/roms/` (first in rompath). Per-game ini: `~/.mame/<game>.ini`.
- Launching on the desktop from Claude's shell needs:
  `DISPLAY=:0 XAUTHORITY=$(ls /run/user/1000/.mutter-Xwaylandauth.*|head -1) WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000 setsid nohup mame ... &`
- MAME ignores SIGTERM from this shell; use `kill -9 <pid>`. Never `pkill -f "mame ..."`,
  because it matches and kills Claude's own shell command.
- Headless runs: `-video none -sound none -nothrottle -seconds_to_run N -autoboot_script x.lua`.
  `scr:pixels()` still works headless. Debugger from Lua: `-debug -debugger none`, then
  `manager.machine.debugger:command("trace file,:tag,noloop")`.
- Lua API notes (0.285): no CPU clock control (`device.clock` is nil) and no `ui:get_slider_list`.
  Overclocking is only possible through the in-game Tab > Slider Controls (needs `-cheat`),
  and the values are not saved on exit.
  `screen:draw_box(x1,y1,x2,y2, fill, line)`: fill comes first.
- Scripts (`~/mame/scripts/`):
  - `fps-counter.lua`: generic on-screen "Drawn FPS" (counts real image changes per 60 refreshes).
  - `stunrun-60fps.lua`: S.T.U.N. Runner cap unlock + counter.
- Desktop shortcuts (also in `~/.local/share/applications/`): `stunrun.desktop` (normal),
  `stunrun-test.desktop` (cheat + counter), `stunrun-60fps.desktop` (unlock + counter).
- `~/.mame/stunrun.ini` = `cheat 1`; `~/.mame/cfg/stunrun.cfg.bak` = original cfg backup.

## S.T.U.N. Runner 60fps project (stunrun, atari/harddriv.cpp)
Goal: 60 drawn fps at the correct game speed.

Hardware: 68010 main @8MHz (program in region mainpcb:maincpu, 0x00000-0xBFFFF),
TMS34010 GSP @48MHz (video), ADSP-2100 @8MHz (math), 6502 sound. Screen 512x228 @60.2Hz.
Benchmark: ~750% speed unpatched on this PC.

Learned:
- The game draws ~20 fps during tunnel gameplay (one new image per 3 refreshes); other screens draw 8-9 fps.
- Overclocking gsp/adsp to 400% changed nothing: it is a software cap, not hardware.
- The cap lives in the GSP code (addresses are TMS34010 *bit* addresses; Lua `spaces["program"]`
  takes them directly, e.g. `read_u16(0xFFF77E80)`):
  - Vblank/display IRQ handler at FFF41C00 increments the byte counter FFF716A0.
  - Frame loop at FFF40ED0: `A1 = [FFF77E80]` (min refreshes/frame = **3**), copies counter
    to FFF716B0 (refreshes elapsed, usually 1, so drawing finishes within 1 refresh),
    waits at FFF40F50..FFF40F90 until counter >= A1, then clears the counter at FFF40FA0.
  - The GSP is ~77% idle at stock clock; the main 68010 also busy-waits at 02FC82
    (`tst.w (A2)` loop, calls 022766, clears watchdog $608000).
- Writing FFF77E80 = 1 every frame (RAM patch, ROMs untouched) gives a full 60 fps in the tunnel.
  **But game logic advances once per drawn frame, so the whole game runs 3x fast**: the demo's
  tunnel segment took ~6 s instead of ~17 s. FFF716B0 (elapsed refreshes) does not seem to be
  used to scale game speed. `2` = 30 fps at 1.5x speed.
- The ADSP trace came out empty in the 6-frame capture (not investigated).
- **User's live results (2026-11-15) differ from the headless demo test:**
  - `MIN_REFRESHES = 2`: tunnel sections still max ~20 fps (expected 30).
  - `MIN_REFRESHES = 1`: only ~40 fps for a second or two, otherwise lower (headless demo showed a steady 60).
  - Unconfirmed theory: real gameplay is heavier than the attract demo, so drawing takes
    >2 refreshes and the cap isn't the only limit there. To check: read FFF716B0 (elapsed
    refreshes) during real play. Also try the unlock combined with gsp/adsp overclock sliders,
    and confirm the cap write actually holds during gameplay.
  - MAME speed stayed at ~100% (F11) during those runs, fluctuating 98-102% (normal throttling
    jitter), so the host PC is not the bottleneck.
    The limit is inside the emulated game: GSP/ADSP/68010 work per frame, or something else
    in the frame pacing.

- **Live-vs-headless gap explained (2026-11-15):** real gameplay is render-bound at stock clocks.
  - Scripted real play headless: coin = `:mainpcb:jsa:JSAII` + `:mainpcb:IN0` "Coin 1" held 20 frames
    at frame 600/640, "1 Player Start" (`:mainpcb:a80000`) at 700/900, Button 1 pulsed. Reaches level 2.
  - Frame timeline per GSP frame (taps on FFF716B0 = frame start, FFF77F30 = display list taken,
    FFF71670 = drawing done/flip; time = `manager.machine.time:as_double()/scr.frame_period`):
    wait for the 68010 display list 0.5-0.9 refreshes, then GSP drawing **1.5-2.1 refreshes avg (max ~3.2)**,
    then wait for the vblank flip. Cap=1 gives only 18-28 fps in gameplay; the attract tunnel is unusually
    light (1 refresh), which is why headless showed 60.
  - Frame flow: after vblank the GSP polls mailboxes FFF9FC00/FFFCFC00 (FFFF = list ready, double-buffered),
    draws into buffer 2000000 or 203C000, writes it to FFF71670, spins at FFF41650/FFF414C0 until the vblank
    IRQ FFF41C00 flips and clears it. ADSP ran ~90% of its cycles; 68010 also busy.
  - The old pixel-change counter overcounts in gameplay (HUD changes). `stunrun-60fps.lua` now counts real
    frames via a write tap on FFF716B0 (`fps-counter.lua` and the test shortcut still use pixel changes).
  - So 60 fps needs gsp (~300-400%) and maincpu overclock as well as the unlock, plus a game-speed fix.
  - Lua gotchas (0.285): screen has no vpos (use machine.time); `frame_period` is a number;
    `d:command("bpset ...")` targets the visible CPU (maincpu), and `device:debug():bpset` printf output
    didn't show in consolelog. Memory taps work; keep the tap handle in a global.

- **User's live overclock test (2026-11-15):** unlock + gsp/maincpu/adsp all at 400% = steady 60 fps,
  0 frameskip, ~100% speed, but the game runs far too fast. 60 fps is feasible; game speed is the problem.
- **Option 2 findings (2026-11-15): no single time-step knob found.**
  - One logic tick per GSP frame: right after the GSP frame start, a 68010 IRQ handler at 021444 writes
    FFFF to $FFDB48, which releases the main loop's wait at 02FC82; 02F240 clears it.
  - 68010 RAM is at FF8000-FFFFFF. Per-tick constant steppers: FF9566 (+1 tick counter), timer long
    $FF9568 (-14/tick; HUD seconds = value/256, poke-verified), FF8016/FFDB38 (+~12.5), FF9582 (5-bit counter).
  - The timer code at 026884-02688E is `moveq #$e,D1; sub.l D1,D0`, a hard-coded step. The code is compiled C
    with per-tick constants, so a correct-speed 60 fps needs 20 Hz logic + interpolated rendering (big RE job).
  - Tools: the 68010 disassembly is made with debugger `dasm m68.asm,0,C0000` (no unidasm installed).
    68010 RAM write taps get dropped by a remap around frame 182, so install them late (e.g. at frame 1790).

- User's goal reference: https://www.skytopia.com/stuff/stun60.mp4 is an AI-interpolated 60 fps mock-up (blended
  ghost frames, normal game speed), not a real mod. The user wants live play to look like that.
- Alternative to option 2: real-time frame generation. lsfg-vk (a Vulkan layer that needs the paid Lossless Scaling
  app's files) + MAME `-video bgfx -bgfx_backend vulkan` (the UHD 620 has Intel Vulkan).
  Catch: MAME presents 60 Hz with each game frame repeated about 3 times, so the generator needs only the new frames.
  Not tried yet.
- lsfg-vk status (checked 2026-11-16): v2.0.0 released 2026-09-05 (Vulkan 1.2+, FP16 speedup, Qt6 UI, lsfg-vk-cli
  benchmark/validate/healthcheck, matches processes by Linux binary name). Moved off GitHub to lsfg-vk.dev (+ Codeberg mirror);
  license now CC BY-NC-ND 4.0 (fine for personal use). Still needs Lossless Scaling owned on Steam (reportedly its "lsfg-vk" branch).
  v1 configs incompatible. Not confirmed: Intel UHD 620 performance, Ubuntu packaging (lsfg-vk.dev failed DNS from here).

- **HD redraw experiment (2026-11-16): success.** Results + tools in `~/mame/hd-experiment/` (tools/: cap.lua capture,
  dec.py decoder, hr.py 1440x1080 renderer).
  - Display list (GSP RAM, pointer = mailbox+0x10): 16-bit commands, top nibble -> jump table FFF470E0, walker FFF46E30.
    0/F end, 3 fill rect, 2 line, 5 clip window, 4/9/D HUD+bitmaps, 7 = whole 3D scene (handler FFF44BF0).
  - Opcode 7 block: base=after opcode word; word[0]=count; offset table at base+count words (FFFF ends);
    poly at base+off: flags(bit15 skip, bit12 alt handler FFF48FC0 (unused so far), bits10-11 mode (2=dithered shadow),
    low10 = colour index into FFF71D20 table -> F4000000), xl, xr, y, then repeat {right slope long, left slope long
    (16.16, low word first), word n (n-1 more scanlines)} until FFFFFFFF. Fractions start at 0.5. Screen y = list y - 0x28.
    Playfield rows 0-207, HUD 208-239. ~140-250 polys per frame. Polys are screen-space 2D (already projected).
  - Colours were sampled from the matching MAME frame (colour table not decoded yet). Skyline background is a bitmap.
  - Gotchas: debugger `dasm file,addr,len,1,:mainpcb:gsp` (5th arg selects CPU; `focus` doesn't work headless).
    Read taps can get the GSP PC via `device.state["PC"].value` (PC = next instruction). tracelog in trace actions
    printed nothing. Pillow 12 here: NEAREST resize is broken (use the pure-Python nn() in hr.py); no numpy.
  - Next for 60 fps: the list is 2D with no polygon IDs, so interpolating needs matching polys between lists
    (offset-table order may be stable) or going up to the 3D data (ADSP/68010). Live use needs a custom MAME build.
- **2D interpolation test (2026-11-16): works on open track, fails in tunnels.** Tools: seq.lua (dump every scene block,
  TF/TAG/N env), interp.py (align polys by order+colour+centroid DP, resample outlines, lerp), valid.py (interpolate
  list i..i+2 at t=0.5, score vs real list i+1). A new list every 3 refreshes, alternating buffers FFFD0130/FFFA0130.
  - Open track (frame 3600): interpolated 95-98% vs 90-97% for repeating the previous frame. Good.
  - Tunnel (frame 2400): erratic, sometimes far worse (0.29-0.44). The camera moves about a ring per tick and the
    same wall changes colour index, so 2D polys can't be paired (wagon-wheel effect). See tunnel-interp-fail.png.
  - Conclusion: smooth 60 fps needs the 3D side: camera position/orientation + 3D vertex data before projection
    (68010 RAM / ADSP), then re-project at in-between camera positions. 2D list stays useful for HD drawing.
- **3D pipeline found (2026-11-16): the ADSP does all 3D work; we can steer its camera.**
  - The 68010 copies finished polygon records from the ADSP buffer window $810000-$811FFF into GSP RAM via the host
    port (memcpy at 02247A, writes $C0000C). So the ADSP projects, clips and computes edge slopes itself.
  - Per tick the 68010 (code 02E0FA-02E1DA) writes just two input blocks into ADSP data memory (68010 window
    $808000 + 2*word): camera block at word 0x1FE6 ($80BFCC..): position = 3 longs from 68010 RAM $FFDAF8/$FFDAFC/$FFDB00
    -> $80BFD2..$80BFDC; camera matrix 9 words (1.14 fixed, 0x4000=1.0) from $FFDB04 -> $80BFEA..$80BFFA (seen yaw-only);
    extra words $80BFDE-E8 (locals and $4A82A consts, maybe roll/pitch). Object block at word 0xA00 ($809400..):
    per object ids, matrix, position (craft record in 68010 RAM around $FF9C7C: 3 longs + 9-word matrix).
    ADSP control regs are around $818000-$818060. Track geometry is already inside the ADSP's memory.
  - Proof: write tap on $80BFCC-$80BFFB returning the previous tick's camera words makes the next list 95% identical
    to the previous list (vs 39-66% normally); the rest is moving objects. (cam.lua MODE=prev, cmpl.py.)
  - Lua: write taps can return a value to replace the written data.
  - Plan for 60 fps: run the ADSP render 2 extra times per tick with interpolated camera (+objects) and show those
    lists. Needs: the ADSP render trigger/completion protocol, extra ADSP time (overclock adsp ~300%+),
    GSP cap=1, and one tick (50 ms) of delay to interpolate (or extrapolate). Check that the render pass does not feed game logic.
- **In-between renders WORK (2026-11-16).** `~/mame/hd-experiment/stun60-sidebyside-*.mp4` = 20 fps vs 60 fps (3 s of
  tunnel, renders by the game's own ADSP at t=0, 1/3, 2/3; HD redraw with sampled colours). Tools: inj2.lua -> movie.py.
  - MAME facts (harddriv_m.cpp): 68k $818000+2*n: val=bit3 of n, func=n&7: 3=buffer bank (deferred), 5=/BR (0=halt ADSP),
    6=/HALT, 7=reset, 0/1 LEDs. $818060 = clear ADSP IRQ (68k IRQ level 2). Writing ADSP data word 0x1FFF ($80BFFE)
    triggers the ADSP job interrupt. ADSP writes output ("SOM") into bank (m68k_bank^1); 68k reads bank m68k_bank at $810000.
    Track geometry is streamed from ROM ("SIM", user1 region) so jobs are repeatable.
  - Job protocol: main loop waits $FF9BB4 (02C3D6), clears it, toggles bank ($818006/$818016), upload routine 02E0FA or 02DE56
    (camera + objects, 82 or 677 writes), clr $80BFFE (trigger), release $81801A. ADSP IRQ handler 021402 -> 02E418:
    if $80BFC6 != 0 continue (more data), else set $FF9BB4=1 (done). Pipeline latency: upload -> shown 2 ticks later.
  - Object slots in ADSP data (stride 0x30 bytes): +0/+2 ids, +4 matrix 9 words, +0x16/+0x1A/+0x1E position longs.
    Writer PCs (tap PC = next instr): positions 02E342/34C/356 (02E30C update), 02E24A/250/256 (02E1EC new slot);
    camera pos 02E16C/176/180 or 02DED6/EE0/EEA; matrices via memcpy 022DE0-022DE8.
  - Injection (inj2.lua): on the real "done" write to $FF9BB4 return 0 (tap) to hold the 68010; snapshot ADSP data
    0-0x1FFE (ADSP space, avoids trigger); per t: restore snapshot, halt, set 68k bank to b^1 (ADSP writes the copied bank b),
    replay the last-but-one job's upload with camera+objects lerped toward the last job, release; on done (hold again),
    set bank back to b next frame, read $810000 (count, then words) the frame after. Finally restore and write $FF9BB4=1.
    Replay at t=0 reproduces the real list 100%.
  - Next: live version. Needs gsp+adsp+maincpu overclock (sliders), GSP cap=1, and scheduling: per tick run 2 extra jobs
    after the real job finishes, write each into a spare GSP list buffer (reuse the published list, swap the 7000 block,
    re-append the HUD tail) and raise its mailbox one refresh apart. Colours come from GSP table FFF71D20 -> real palette in MAME.
- **Live prototype (2026-11-16): `~/mame/scripts/stunrun-interp60.lua`**, desktop launcher `stunrun-interp60.desktop`
  (-cheat; user sets gsp/adsp/maincpu ~400% in Tab > Slider Controls each launch). Overlay: drawn fps, ticks, interp, dropped.
  Env for testing: STUN60_RELAX=1 (no deadlines, slow motion), STUN60_VERIFY=1 (render t=0 and compare with the real list),
  STUN60_LOG=file, STUN60_DEBUG=1, STUN60_PCLOG=1. Headless driver: scratchpad re/live_test.lua (dofile's the script).
  - Per real list (68010 publishes mailbox FFFF): cap=1; hold the 68010 at the real job's done ($FF9BB4 tap returns 0, only
    once a new job was uploaded after the publish); wait until this tick's copy ($FFDB4E write) has finished; for t=1/3,2/3:
    halt ADSP + set bank, wait 0.01 refresh (bank switch is deferred!), restore ADSP RAM to the pre-job snapshot of job A
    (taken at the 68010's bank toggle), upload lerped job, release; on done set bank back, wait 0.01, read $810000.
    Pair = jobs[n-2], jobs[n-1] (verified exact). Objects matched by 68010 object pointer (A2 at write time).
    Extras go in the same GSP buffer as the real list (block at 7000 found via $FFDB4E length; HUD tail re-appended),
    published one per GSP frame. Game tick ($FFDB48=FFFF from the GSP-frame IRQ) is suppressed until the last extra is
    consumed. Deadlines: drop extras that can't be shown in time, then cap = 3 - shown (normal 20 fps pacing at stock).
  - Gotchas found: emu.wait coroutines crash MAME on exit (use tap-pumped state machine instead); autoboot script re-runs
    after a machine reset (global guard); 68010 wait loops time out by iteration count (refresh D5 while holding:
    02C3AC-02C3DA -> 0, 02FC7C-02FCB6 -> 0x80000); the 68010 restarts the game (021286) if a copied block lacks FFFF.
  - Headless results: relaxed 70 s run, 268/268 exact verifies, no resets; stock clocks: extras dropped, 20 fps normal.
    Not yet tested live with overclock (can't overclock from Lua).
  - Live test 1 (2026-11-16): all three at 400% -> 60 fps ~1 s then lockup; adsp ~130% -> 22-33 fps, locks after ~1 min.
    Fix attempt: wait_copy had no timeout (a stuck cycle holds tick + done and refreshes the 68010 give-up counter = permanent
    freeze); added timeout, 45-refresh watchdog (abort_cycle restores bank/ADSP), pcall around step (ERR n on overlay),
    "ticks" now counts released ticks (20 = normal speed). Always logs to ~/mame/stun60.log; launcher sends stderr to
    ~/mame/stun60-stderr.log. Previous version kept as stunrun-interp60.lua.v1. No UI inputs are exposed to Lua, so the sliders can't be driven headless.
  - Live test 2 (all 400%): extras ~1 refresh late (each ADSP job ~0.85 refresh at 400%, v2 ran extras after the next real
    job), "GSP handshake error" + game self-reset. v2 kept as stunrun-interp60.lua.v2.
  - **v3 rewrite (2026-11-16)**, from a probe of the GSP handshake: GSP polls a mailbox, draws as soon as it is FFFF,
    flips at vblank, then clears the mailbox (= list on screen, buffer free), reads the cap (FFF77E80, refreshes between draw
    starts), raises the game tick, and clears counter FFF716A0 (+1 per vblank) when the cap is satisfied. Vblank at x.020.
    The 68010 clears the tick at 02F240 and publishes right then. FFF71680 nonzero = draw done.
    v3: extras use jobs[n-1],jobs[n] right after the publish (both are already uploaded; hold jobs[n]'s done), raise extra j after
    vblank B+j (B = vblank when R(k) starts drawing), hold all GSP ticks and give exactly one at vblank B+3. Stock: 20/20.
    Relaxed: verifies exact. Bugs fixed: write taps returning a value overwrite writes made inside them (lost done/tick).
    Never write an address from inside its own tap, and don't let reads inside taps run the state machine (in_tap guard).

Status (2026-11-16): the user chose the in-engine route (option B). The HD redraw and the in-between ADSP renders are proven
offline (videos in ~/mame/hd-experiment/). **v3 WORKS LIVE (2026-11-16)**: gsp/adsp/maincpu 400% -> steady 60 drawn fps, 20 ticks (correct game speed), 40 interp/s, no lockups. Small dips in open areas (heavier ADSP jobs, jd ~0.85 refresh, 3 jobs per 3 refreshes is tight). Lua cost ~0.2 s CPU per s.
  Overlay (2026-11-16): O key cycles full/small/off (saved in ~/.mame/stun60-overlay.txt, default small = fps only);
  red warning "Overclock too low" after 3 s of gameplay with <10 extras/s. Estimates: jd only learns from jobs run, so
  after 100 all-skipped cycles one probe job runs (decaying jd instead broke stock pacing); gd capped at 0.9.
  Next: custom MAME 0.285 build (SUBTARGET=stunrun SOURCES=src/mame/atari/harddriv.cpp) with set_clock_scale() in
  stunrun_board_device_state::device_start (harddriv.cpp ~line 1846), read from env, so no sliders and adsp can go >400%.
  **Custom build DONE (2026-11-16):** ~/mame/build/mame-mame0285/stun60 (MAME 0.285, SUBTARGET=stun60 SOURCES=harddriv.cpp,
  ~20 min build, log ~/mame/build/build.log). Patch: stunrun_board_device_state::device_reset() reads env
  STUN60_CLOCK="maincpu=4,gsp=4,adsp=6" -> set_clock_scale (prints "stun60: X clock" to stderr); originals kept as *.orig.
  Run with -inipath /etc/mame (picks up apt paths). Launcher: stunrun-60fps-custom.desktop (also on ~/Desktop), no -cheat.
  Headless: adsp x4/x6/x8 all ~60 fps / 20 ticks, x8 jobs ~0.35 refresh; remaining dips are rare scene changes.
  Host cost same for x4 and x6 (~157% unthrottled).
  - **Sound garbled live (2026-11-16)**: host too slow (gameplay 104-119% headless). Overclock alone = 378%; the Lua
    script was the cost: 68010 read-tap pumps (millions of calls/s at x4) and per-word Lua copies.
  - **v4 (2026-11-16)**, script needs the custom build now (apt shortcut uses stunrun-interp60-apt.lua = v3 copy):
    no 68010 pumps (D5 refresh at vblank/frame; steps run from the done tap, publish tap, vblank and GSP counter clear;
    releasing the done from inside its own tap = tap returns 1). Custom build additions in init_stunrun (harddriv.cpp):
    0x828000/0x82C000 read-only window on som banks; write 0x828000 = immediate 68k buffer bank (the 818006/16 switch
    is deferred, so the ADSP's first output word went to the wrong bank and wiped the real list -> game restart);
    params 0x828020-27, command 0x828030, result 0x828032 (s60_command: 1 SNAP, 2 RESTORE ADSP data, 3 STORE output,
    4 TAIL capture, 5 BUILD list in GSP RAM, 6 COMPARE); GSP read speedup at FFF71670 for the flip spin loop
    FFF41650-FFF41680 (small gain). Result: 198% avg / 142% min headless at maincpu=3,gsp=3,adsp=6 (launcher now uses
    that), ~57 fps avg, 20 ticks, verify exact. Older script versions kept as .v1-.v4pre.
  - **v4 live test (2026-11-17): sound OK, reached level 3.** Log kept: ~/mame/stun60-live-2026-11-17.log (195 s).
    Ticks a steady 20/s throughout (correct speed). Gameplay mostly 60 fps; short dips to 33-45 for 1-2 s, mostly when jd >= ~0.5
    refresh (heavy ADSP jobs at adsp=6). Several 2-7 s stretches at exactly 20 fps with cycles 0 (no interp attempted, probably
    level-end/transition screens, unconfirmed). Frequent recoveries: 56 "released a stale ADSP done", 38 "bad output", 34 "no ADSP time".
    adsp=8 live (2026-11-17): music OK all through, 59.4 avg fps (33 s gameplay logged), sound "a tiny bit garbled". Headless speed
    adsp=6 187% avg/169% min, adsp=8 191%/180% (same cost). -audio_latency is ignored by sdl/pulse in 0.285; only portaudio
    honours it (units of 20 ms). Launcher now adds `-sound portaudio -audio_latency 3` (60 ms); user still heard slight choppiness (see below). Next ideas: check what the cycles-0 stretches are; look into the stale-done/bad-output causes.
  - **Music fix (2026-11-17):** music was missing in level 1-2 first tunnels (user report). Cause: the 68010 polls bit 15 of
    $A80000 (sound latch empty) before each command (send routine 023EDA, writes $600000 at 023EF6), but MAME's stunrun port
    has that bit "unused" = always empty, so at maincpu x3 back-to-back commands (game start 1D 1C 39) overwrote each other.
    Patch: hd68k_a80000_r (harddriv_m.cpp, .orig kept) returns the real latch state; the $600000 write handler (init_multisync)
    calls abort_timeslice() after main_command_w. Headless: all commands reach the 6502, audio RMS matches stock, 60 fps intact.
    Probes: re-probes/snd6.lua (6502-side CMD/MIX/YM log), rms.py (per-second loudness compare of -wavwrite files).
  - **Choppy sound diagnosis (2026-11-17):** user's longer adsp=8 run (log ~/mame/stun60-live-2026-11-17c.log): 58.7 avg fps
    over ~2 min of play, but sound "still a little choppy", like a Bluetooth headset at the edge of its range, getting worse after a while.
    - Emulated audio is clean: no dropouts in -wavwrite captures (re-probes/gaps.py), so it is host-side (MAME falling behind live).
    - Per-frame host cost (unthrottled, re-probes/wper.lua): stock game a flat ~3.5 ms/frame; with the script the pattern is
      2.3 / ~14 / 2.3 ms: real job + both extras run back to back in one frame (ADSP instruction count, ~3x a stock tick).
      Same spike at adsp=4/6/8 (12-16 ms max), so the clock isn't the lever. Throttled, that frame lands ~14 ms late.
    - Host power profile is "balanced" (governor powersave); suspected CPU slowdown under sustained load or heat.
    - Overclock WITHOUT the script never gets into gameplay (boot loop, only 3-4 sound commands); irrelevant live but odd.
    - Script now logs per second: `wall X s` (real time per emulated second), `max gap` (longest real gap between frames, ms),
      `late` (frames >25 ms apart). Previous script kept as stunrun-interp60.lua.v4b.
    - re-probes/hostmon.sh out.log [max_s]: logs CPU MHz avg/min, pkg temp, MAME CPU% each second while stun60 runs
      (stops when MAME exits). Run in the background before the user plays: `~/mame/scripts/re-probes/hostmon.sh ~/mame/hostmon.log 1800`.
  - **Host spike fixed (2026-11-17, evening):** a short live run with GNOME power mode = Performance still had wall 1.02-1.06 s
    and ~20 late frames/s (one per tick), so throttling wasn't the main cause. Script now spreads the ADSP work: extra 1 right
    after the real done, extra 2 after the next vblank, and the held done is released only at vblank B+2 (68010's next real
    job runs in the 3rd refresh). Env STUN60_SPREAD=2 (default) / 1 (only extra 2 delayed) / 0 (old). Headless adsp=8 per-frame
    host ms: old 17/3/3 pattern (p90 15.2, p99 17.9), mode 1 9/14/3, mode 2 flat ~8 (p90 8.3, p99 10.8); same 56 fps / 20 ticks,
    790/790 verifies exact. Previous script kept as stunrun-interp60.lua.v4c.
    Live run right after (log ~/mame/stun60-live-2026-11-17d.log, 165 s gameplay): wall avg 0.997 / max 1.007 s (before: 1.02-1.06),
    late 0.44/s (before ~20), max gap 22 ms avg; 57.3 fps, 20 ticks. hostmon: ~3.6 GHz avg, pkg temp up to 94 C, MAME ~60% CPU.
    23 s at ~20 fps with cycles 0. User: sound better; 20 fps dips also mid-tunnel with many enemies (robots, armored cars).
  - **Busy-scene fix (2026-11-17):** cause = size limits. Heavy scenes have 3D blocks of 6000-7250 words; find_block rejected
    d2 > 6000 (no cycle at all = "cycles 0", 20 fps) and custom MAME's s60 STORE (cmd 3) rejected n > 6000 ("bad output", then
    "stale ADSP done" fallout). Both raised to 0x1FFE (som bank = 0x2000 words; GSP buffers are 0x3000 words apart), MAME rebuilt.
    Headless 201 s scripted game: fps 51.4 -> 57.8, secs <40 fps 41 -> 11, cycles-0 secs 17 -> 4 (level-end fade/course map, legit),
    stale done 63 -> 0, bad output 29 -> 0; verify 3985/3985 exact (749 lists > 6000 words). Script logs "no 3D block: ..."
    (rate-limited) when a published list has no usable block. Remaining: "extra 1 missed (rendered true)" ~0.25/s (late, not lost).
  - **Live test of busy-scene fix (2026-11-17, log ~/mame/stun60-live-2026-11-17e.log, 217 s):** 55.5 fps (was 49.6), secs <40 fps
    23 (was 50), stale done/bad output gone; wall 0.997, late 0.24/s; host 3.57 GHz, temp up to 96 C. Remaining 20 fps stretches
    every ~50 s = level ends (stale d2, no 7000 block or the 323-word one) = legit. New: a 30 fps stretch at 211-218 s with
    ticks 15-16/s and gd pinned at 0.9: the GSP needs >1 refresh to draw (heavy scene), extra 1 misses every cycle.
    Headless gsp=3 vs gsp=4: mean host ms 8.4 vs 8.9 (p99 12.2 vs 12.5), gd avg 0.63 vs 0.46, secs gd>=0.85 9 vs 0.
    Launcher switched to maincpu=3,gsp=4,adsp=8 (both .desktop copies).
  - **Live gsp=4 run (2026-11-17, log ~/mame/stun60-live-2026-11-17f.log, 205 s): best so far.** 58.4 fps, ticks 19.94,
    secs <40 fps 8 (was 23), gd avg 0.49 (never >=0.85), late 0.04/s, wall avg 0.997 (4 secs 1.01-1.03 at 60 fps, harmless),
    "extra missed (rendered true)" 157 -> 3. All 5 remaining dips (1-2 s each, at ~10/44/89/144/209 s) have the transition
    signature (stale d2, 7000 at word 323/329 or none, "no ADSP time"), i.e. no 3D scene to interpolate. No hostmon that run.
  - **PAUSED HERE (2026-11-17, ~23:30; user back the next morning).** Done today: host spread fix, busy-scene fix, gsp=4,
    colour decode, Linux AppImage/tarball + Windows zip delivered, CachyOS migration bundle (tested). The user may continue on
    the CachyOS PC. Next: HD redraw at 4:3 (estimate given: first HD frames ~3-4 h of work, finished + packaged ~2 days), then a
    widescreen probe. Deferred: choppy sound on the user's real Windows PC (fine under Wine on CachyOS).
    Claude was asked to power off the Ubuntu PC after this via `gnome-session-quit --power-off --no-prompt` (no --force).
  - **Older pause note (2026-11-17, late).** Host spread, busy-scene size limits and gsp=4 are all in place and verified live
    (58.4 fps, correct speed, sound fine; user confirmed the 5 dips were level changes). GOAL REACHED; remaining work is optional polish.
    Launch: "S.T.U.N. Runner 60fps (custom MAME)" = stunrun-60fps-custom.desktop (also ~/Desktop):
    `STUN60_CLOCK=maincpu=3,gsp=4,adsp=8 ~/mame/build/mame-mame0285/stun60 stunrun -inipath /etc/mame -sound portaudio
    -audio_latency 3 -autoboot_script ~/mame/scripts/stunrun-interp60.lua` (stderr -> ~/mame/stun60-stderr.log, log ~/mame/stun60.log).
    To resume: optionally start `~/mame/scripts/re-probes/hostmon.sh ~/mame/hostmon.log 1800` in the background, ask the user
    to play (enemy-heavy tunnels), then read stun60.log: per-second lines (drawn/extra/ticks/cycles, wall/max gap/late) and any
    "no 3D block:" lines (published list without a usable 3D block: shows d2, where the 7000 opcode is, its end word).
    - Still open: "extra 1 missed (rendered true)" ~0.25/s (in-between ready but too late); CPU reaches 94 C under load;
      if sound is still choppy, try -audio_latency 4-5.
    Headless A/B driver: re-probes/ab.lua (per-frame host ms to $WLOG from frame 1400 + live_test.lua). Example:
    `STUN60_LOG=x.txt WLOG=w.txt END=13500 STUN60_CLOCK=maincpu=3,gsp=3,adsp=8 ~/mame/build/mame-mame0285/stun60 stunrun
    -inipath /etc/mame -video none -sound none -nothrottle -autoboot_script ~/mame/scripts/re-probes/ab.lua`
    (add STUN60_VERIFY=1 to check exactness; frame ~3300 and ~6200 are level ends = legit 20 fps; a run to 13500 takes ~3 min).
    Rebuild after editing harddriv.cpp/harddriv_m.cpp (incremental, a few minutes): in ~/mame/build/mame-mame0285 run
    `make SUBTARGET=stun60 SOURCES=src/mame/atari/harddriv.cpp NOWERROR=1 USE_QTDEBUG=0 TOOLS=0 TESTS=0 OPTIMIZE=2 -j8`.
    Headless test drivers in ~/mame/scripts/re-probes/: live_test.lua (scripted coin/start/fire, dofile's the script by path,
    END env), spd.lua (logs video.speed_percent, a fraction: 1.9 = 190%), wper.lua/wonly.lua (per-frame wall ms), snd6.lua, rms.py, gaps.py.
    m68.asm (full 68010 disassembly) is in re-probes/ too.
    Ideas for later: HD redraw (1440x1080) live (next big step; user wants it).
  - **Standalone packages (2026-11-17)** in ~/mame/package/ (README.txt shared; out/ = deliverables). No ROMs included.
    Delivered to the user's file share (location: private ~/CLAUDE.md, not in the repo).
    - Linux: STUNRunner60.AppDir (AppRun launcher: ROM next to AppImage / roms/ / ~/.local/share/stun60/roms / ~/mame/roms;
      data + log in ~/.local/share/stun60; sets STUN60_CLOCK + STUN60_DATA; bundles libSDL2 (sdl2-classic), SDL2_ttf, samplerate).
      AppImage built with tools/appimagetool-x86_64.AppImage (--appimage-extract-and-run --no-appstream). Needs glibc >= 2.43.
      Also out/STUNRunner60-linux-x86_64.tar.gz (same folder, ./run). Both tested headless.
    - Script: STUN60_DATA env = folder for log + overlay setting (else old ~/mame paths; HOME falls back to USERPROFILE). Prev: .v4d.
    - Windows: cross-compiled with MinGW-w64 GCC 13 posix (sudo apt install mingw-w64 done). Toolchain symlink dir
      ~/mame/build/mingw64/bin (posix variants + windres). Build: in ~/mame/build/mame-mame0285
      `make TARGETOS=windows CROSS_BUILD=1 MINGW64=$HOME/mame/build/mingw64 PTR64=1 SUBTARGET=stun60 SOURCES=src/mame/atari/harddriv.cpp
      NOWERROR=1 USE_QTDEBUG=0 TOOLS=0 TESTS=0 OPTIMIZE=2 -j8` (log ~/mame/build/build-win.log). Launcher: package/win/launcher.c ->
      STUNRunner60.exe (sets env, data\ folder, checks ROM, starts bin\stun60.exe). Wine 10 installed by user; test prefix
      ~/mame/package/wineprefix.
      wineserver is /usr/lib/x86_64-linux-gnu/wine/wineserver (not on PATH); the launcher returns at once, so wait on the stun60.exe pid.
      **Windows DONE (2026-11-17):** build ~17 min, stun60.exe 55 MB stripped, static (system DLLs only). Wine tests: launcher OK;
      scripted gameplay 58.0 fps, ticks 19.95, verify 968/968 exact, 198% unthrottled. Delivered upgraded/Windows/
      STUNRunner60-windows-x64.zip (13 MB) + README (CRLF). Running stun60.exe directly writes cfg/nvram into the cwd:
      keep test runs out of the package folder.
      **User test on real Windows (2026-11-17): runs, but the choppy-sound issue is back** (deferred by user). Ideas: launcher uses
      -sound portaudio -audio_latency 3 (tuned on Linux); try -sound xaudio2 (Windows default) and/or -audio_latency 4-5,
      check data\stun60.log wall/late columns from the user's PC (host speed vs this laptop).
      2026-11-18: user says the Windows version seemed to run OK in a later check; maybe the choppy run was a fluke. Backburnered.
      Same Windows zip under Wine on another Linux PC (CachyOS): sound fine. So the build is OK; the problem is specific to that
      Windows PC/audio path (portaudio backend on Windows, latency, or host speed). Deferred.
  - Overlay key is the letter O (user confirmed it works; zero does nothing, by design).
  - **Plan agreed (2026-11-17):** HD redraw at 4:3 first (live renderer in the custom build), then a widescreen probe:
    find the ADSP projection/clip limits, widen them, check edge pop-in (open areas), extend the skyline bitmap, keep HUD centred.
    Fallback: crop 4:3 to 16:9. A ROM-only patch for stock MAME is impossible (stock clocks can't render 60 fps).
  - **Colour decode DONE (2026-11-17), 100% pixel-exact** on frames 2400/3000/3600 (every drawn 3D pixel vs snapshot).
    Tools/data: ~/mame/scripts/re-probes/col/ (colours.py = reference decode + render; capcol.lua = cap.lua + palette dump;
    ctab.lua = table+palette dump; gsp_poly.asm = GSP poly handler disassembly).
    - Chain: poly low10 = idx -> pen = low byte of word at GSP FFF71D20+16*idx (GSP writes it to F4000000 = gsp_control_lo[0],
      the VRAM expander fill colour) -> RGB from palette RAM bank 0: shares ":mainpcb:gsp_palram_lo"/"_hi" (read_u16(2*pen)),
      R = lo>>8, G = lo&255, B = hi&255 (harddriv_v.cpp gsp_palette_change; pixel = palettebank*256 + 8-bit value).
    - Table is constant (all entries solid pairs, no dither; 875/1024 = idx&255). The PALETTE changes over time
      (47 entries by frame 3000, 178 by 3600), so read it every frame. The old cmap.json had 2 wrong entries (idx 31, 116).
    - Mode 2 (shadow): flags 0814 = black pen 20 on 1 pixel in 4, screen-space: x%4==0 on even list-y rows, x%4==2 on odd
      (fill pattern B9=01010101 rotated per line). Often fully overdrawn by the craft. Mode 1 (B9=15151515) / mode 3 /
      bit12 alt handler (FFF48FC0) not seen in these frames.
    - Polys don't cover the whole playfield in open areas (48% at frame 3600): the rest is the skyline bitmap (HUD/bitmap opcodes).
Older status (2026-11-15, user taking a break to decide). Two options were presented:
- A (recommended): real-time frame generation (lsfg-vk + Lossless Scaling; see above). The user must buy and
  install Lossless Scaling on Steam first. Then: install lsfg-vk, make a MAME vulkan launcher at stock speed,
  and solve feeding only the new game frames (uneven 2-4 refresh pacing). Expect ghosting and added input lag.
- B: true 20 Hz logic + interpolated 60 Hz rendering inside MAME (needs overclock sliders every launch).
  First step, about as much work as the 2026-11-15 session: map the 68010 tick (logic vs display-list build;
  the list goes to GSP mailboxes FFF9FC00/FFFCFC00) and find camera position/orientation in RAM.
  Then report feasibility before going further.
- The per-tick time-step search is done: no single knob exists (see findings above).
- Probe scripts from this session were in the scratchpad `re/`: play2.lua (real-play input script),
  tl2.lua (frame timeline), dump.lua (68010 RAM dumps per tick), who.lua (writer PCs); copies kept in `~/mame/scripts/re-probes/`.
- Working files: scratchpad `re/` (traces, probe scripts) are temporary; anything worth keeping
  goes in `~/mame/scripts/`.

## Repo move + red-screen fix (2026-11-18, late)
- **Repos:** development continues in github.com/HornheaDD/STUN_HD60 (git remote `hd`, public, pushed 2026-11-18; main tracks hd/main).
  STUN60 (`origin`) stays frozen as the 60 fps-only v1.0; it only gets a README pointer (branch `stun60-pointer`,
  pushed). Push only when the user says so. User confirmed the red-screen fix in a live game.
- **Red picture after H (HD off) = MAME BGFX bug, fixed in the patch** (`src/osd/modules/render/bgfx/chainmanager.*`):
  chain_manager::update_screen_textures sets up a slot's converter ("XXconvert") and texture names once; the HD screen is
  RGB32 (format 2), the original PALETTE16 (format 1), so after a view switch the raw palette indices were shown (red).
  Now it tracks the format per slot and on a change drops source/screen/palette textures and reload_chains().
  Verified in an isolated `dbus-run-session kwin_wayland --virtual --xwayland` run: 5 toggles, "chain reloaded" each
  time (-verbose), 100% speed. Screen capture there is blocked by the permission classifier: user confirms visually.
- Lua: H logic is now `hd_toggle()`, exported as global STUN60_HD_TOGGLE for scripted tests.
- **Next: HD backgrounds (user chose "option 2"):** hook the display-list bitmap opcodes (4/9/D), identify each background
  image (ROM source + position), extract from the user's ROM, upscale, draw the HD version on the HD screen. ROM-derived:
  the repo ships only the tool; the pack is built on the player's machine on first run (never commit images).

## HD backgrounds, step 1 DONE (2026-11-19): images decoded straight from the ROM
- Display list op 8 = bitmap blit: words x, y, flags (0x20 = transparent pen 0), address (hi word, lo word). Image at the
  address in GSP RAM: header 6 words (height, width, ...) then width*height 8-bit pens (pixel = palettebank*256 + pen).
  Skyline = two 512x48 halves (FFE00000, FFE30060) drawn at x and x+512, y=0x70 in play; also 512x96 course maps
  (y=0x40), 340x140 panels, a 72x72 animation (24 frames), small icons. Op 9 = palette load, op D = image pointer slots,
  op 4 = text. Handlers disassembled with re-probes/bg/dasm_ops.lua (GSP dasm length is in bits: x16).
- The 68010 unpacks them at level load: routine 022766 (incremental) / 0225E4, image number $FF9BCC -> pointer table $BFE00
  (68010 ROM; entry 0 unused), output via host port $C0000C into GSP FFE00000. Format documented in hdpack/stunbg.py.
- **hdpack/stunbg.py zip outdir**: standalone extractor from the user's own stunrun.zip (no MAME needed). 80 images;
  all 25 images captured live (re-probes/bg/extract.lua, raw2png.py) match byte-exact. Streams 1-3, 24-28 have no header
  (full-screen 512x240 / 512x208 buffers, loaded elsewhere; not decoded further).
- Output is pens only. Still open: per-level palettes (op 9 data in the 68010 ROM) to turn pens into RGB without running the
  game; then upscale (pick an upscaler), then draw the HD skyline in hd_compose (blit position from the op 8 args).
- ROM-derived output never goes in git (re-probes/bg/out/ is ignored; extractor output goes outside the repo).

## HD backgrounds, step 2 DONE (2026-11-19): gameplay skylines in HD, live
- Palettes: image stream n's 16 colours (pens 240-255) = RGB triplets at ptr[$48068 + 4n] (68010 ROM; same index as $BFE00).
  Level base palettes (256 RGB, 0x300 bytes) at ptr[$47406 + 4*level] (routine 0296AA merges them, with fades). Between-level
  city screens (streams 4-14, 512x96) also use pens 6-31 from the level palette (window lights cycle there): NOT done yet,
  level<->image mapping unresolved. Gameplay skylines (all pens >= 240) are exact: s06 city night, s16 canyon, s17 forest,
  s18 green hills, s20 plain, s21 golden hills, s22 farmland, s23 galaxy (3 images).
- hdpack/build_pack.py zip pack [--keep-png]: unpack, pad 16 px with the cyclic neighbour half (no seams), Real-ESRGAN
  realesrgan-x4plus (user's pick, sample sheet hdpack/samples/), Lanczos to 3x5, write .s60bg (format in the script) with a
  per-HD-pixel pen map for live re-tinting. ~50 s on the GTX 1070, 14 images, 38 MB. Real-ESRGAN = official
  realesrgan-ncnn-vulkan 20220424 ubuntu zip in build/tools/realesrgan (not in git). Local pack: hdpack/pack (ignored).
- Driver (harddriv_v.cpp): STUN60_HDPACK=dir loads the pack (key = FNV-1a of the low-res pens). A GSP read tap on the
  display-list jump table (FFF470E0, op 8 entry FFF471E0; A4 = command, A5 = args) records blits per drawn list; it must be
  installed after start (scheduler synchronize from the first draw-done; taps from device_start get dropped). GSP RAM is
  mirrored: index = (addr >> 4) & (len - 1). hd_draw_bg runs after the scale-up, before polygons: an HD pixel is used where
  the low-res pixel shows the image's pen (HUD/overlays stay) or is 3D; colour = upscaled * live/ref per pen (fades work).
  Game quirk: a blit starting at x < 0 lands one line lower (measured 100%), reproduced.
- Tests: verify 4012/4012 to level 4 with the pack in view, 3D gameplay 58.7 fps (58.5 without); HD off 677/677.
  run-stun60.sh sets STUN60_HDPACK=~/mame/hdpack/pack when that folder exists.

## HD backgrounds, step 3 DONE (2026-11-19): built automatically on first launch, zero wait
- The user wants no waiting for new players. The driver now builds the pack itself (no Python in the packages):
  hd_start_builder() copies the maincpu ROM region (byte order detected from table entry 1 = 0x00060002), then a detached
  std::thread (lowest priority: setpriority(0,19) / THREAD_PRIORITY_LOWEST) unpacks + pads the images, writes PNGs to
  pack/_work, runs $STUN60_ESRGAN once per batch (batch 1 = level 1's skyline, batch 2 = the rest; `nice -n 19` /
  CreateProcessW BELOW_NORMAL + CREATE_NO_WINDOW), reads the 4x PNGs (util::png), Lanczos-3 resamples to SXxSY, writes
  .s60bg via tmp+rename and queues the image; hd_take_built() (from hd_parse_list, try_lock) moves them into m_hd_bgs.
  Only images whose key isn't already in the pack are built (later launches: nothing to do).
- Measured (GTX 1070, throttled first launch, empty pack): level 1 skyline ready 3.5 s, all 14 in 14.0 s; per-second wall/late
  identical to a run with the pack cached; verify 677/677. Output = Python reference (mean diff 0.2/255, pen maps equal).
  One realesrgan start costs ~6 s (model load), so batching matters. CPU mode (-g -1) doesn't work: no Vulkan = no AI pack
  (game keeps the original skylines and logs it).
- run-stun60.sh: STUN60_HDPACK=~/mame/hdpack/pack, STUN60_ESRGAN=build/tools/realesrgan/... when present.
- Packages (later): bundle realesrgan-ncnn-vulkan + models/realesrgan-x4plus.{bin,param} (~45 MB, BSD-3), set the two env
  vars in AppRun / launcher.c (pack in the user data folder).

## HD backgrounds, step 4 DONE (2026-11-19): level-start screens, palette variants, model per image
- ROM tables per level L (0-25): skyline image = byte $4CB1C[L], level-start screen = byte $4CB36[L] (found at 0322A0/B4,
  $FF9578 = level), base palette = $47406[L]. Level-start screens (512x96, drawn at y=0x40: city, sunset city, pink base...)
  use pens 0-239 from the base palette + 240-255 from the image palette. Same pixels appear with 2 palettes (stream pairs
  4/5, 6/7 ... share one pointer) -> pack format S60BG03: 256-colour ref palette, several variants per pixel key; at runtime
  the variant whose ref colours are closest to the live palette is drawn, then tinted live/ref per pen.
- Night/dark images (>50% pixels with max channel < 48: s04, s06 night city, s23 galaxy) use realesr-animevideov3: the
  general model erased the small window lights (comparison in scratch; user picked x4plus for daytime). Batches per model.
- First launch: 27 images (incl. galaxy + other attract/ending images via a 3rd pass), level 1 after ~5 s, all in ~24 s,
  75 MB. Verify 4012/4012, 58.7 fps. Not covered: header-less full-screen images (course map, title; streams 1-3, 24-28).
- Running several emulators at once starves the nice-19 builder (by design); kill stray test emulators (an orphan from the
  kwin test ran for 1.5 h).

## HD packages built and RELEASED (2026-11-19): GitHub release hd-v1.0 on STUN_HD60 (tag hd-v1.0; local v1.0 = STUN60's)
- package/out-hd/: STUNRunnerHD60-x86_64.AppImage (52 MB), STUNRunnerHD60-linux-x86_64.tar.gz (54 MB, run -> AppRun
  symlink), STUNRunnerHD60-windows-x64.zip (50 MB; zipped with Python zipfile, no `zip` here). v1.0 files in package/out untouched.
- Linux: package/STUNRunnerHD60.AppDir (copy of the v1 AppDir): stripped stun60 (glibc <= 2.36), Lua script, AppRun with
  data dir ~/.local/share/stun60-hd (also finds ROMs in .../stun60/roms), STUN60_HD=3x5, STUN60_HDPACK=$DATA/hdpack,
  STUN60_ESRGAN=$SHARE/realesrgan/realesrgan-ncnn-vulkan; bundled realesrgan (needs glibc 2.29, system libvulkan) +
  models realesrgan-x4plus + realesr-animevideov3-x4 + LICENSE.txt; libgomp.so.1 from Debian 12 libgomp1_12.2.0-14+deb12u1
  (sha256 48fec46b...; glibc 2.34; never CachyOS's x86-64-v3 build).
- Windows: launcher win/launcher-hd.c -> STUNRunnerHD60.exe (same flags as v1 + STUN60_HD/HDPACK/ESRGAN defaults);
  bin\realesrgan\ = official windows zip's exe + vcomp140.dll + the 2 models; vulkan-1.dll comes with the GPU driver.
  Windows realesrgan zip unpacked in build/tools/realesrgan-win.
- README-HD.txt = end-user notes (first-launch explanation; CRLF copy in the zip).
- Tests: AppImage as a new user (fake HOME): 27 images in 22.7 s; second launch loads 27, builds 0; no Vulkan
  (VK_ICD_FILENAMES=/nonexistent): "Real-ESRGAN failed" once, game runs normally. Windows zip under Wine 11 (fresh prefix,
  launcher): 27 images built through Wine's Vulkan, byte-identical to the Linux pack. Not tested on real Windows hardware.

## Wireframe lines in HD DONE (2026-11-19, user report): boost wireframe + all-wireframe scenes, local commit only
- Probe: scripts/re-probes/wf/wf.lua (per list: op counts, op-7 poly flag classes, FFF77E60, level $FF9578 word; env AY=255
  = Advanced course (stick Y held until the trigger), LEV=n forces the level, FORCE=bits ORs into FFF77E60 after frame 1300,
  SNAPS="f1 f2", TAG). Output scripts/re-probes/wf/out/ (ignored). Course select: AD Stick Y 255 = Advanced (Labyrinth L11).
- GSP poly handler (re-probes/col/gsp_poly.asm): A13 = FFF77E60 (copied per list from list header +0x110 by opD/A/B code).
  A13 bit 3 -> EVERY poly goes to the outline routine FFF45800 (checked before the mode); else mode bits 10-11:
  0 solid, 1 = pattern 15151515 (3 of 4 px; boost dissolve), 2 = 01010101 (1 of 4; shadow), 3 = outline (boost wireframe).
  Colour index (flags & 0xFF) == 4 also gets 15151515 in modes 0/2. Pattern phase measured: mode 1 skips x%4==3 on even
  list-y rows, x%4==1 on odd (mode 2 lights x%4==0 even / 2 odd).
  Outline routine: FILL top row xl..xr; per segment (n>1) LINE left edge from current point by (floor(sl*(n-1)) (16.16, low
  32 bits), n-1), then the right edge unless A13 bit 5; current points advance by those integer deltas; FILL bottom row.
- Boost (headless default run, level 2 ~frame 3810-4090): mode 1 dissolve ~4 lists, then 104 mode-3 polys (the craft).
  FFF77E60 stayed 0 in levels 11-22 headless (scripted driving dies early); bit 3 forced looks like the user's
  "tunnel entirely wireframe". Same routine either way.
- harddriv_v.cpp: s60hd_poly.outline/left_only + corner points (vy, lxi/rxi game-integer, lxf/rxf exact); list.gflags.
  Step 1 marks pixels within 1 px of each game-integer outline line (up to 4 pens per pixel, m_hd_wpen/m_hd_wcnt; cleared
  by later filled polys) -> class 3 = wireframe pixel (background borrowed like class 1, HD bg drawn there too). Step 3
  draws outline polys in list order as anti-aliased round-capped lines, width STUN60_HDLINE HD px (default 2), skipping
  class-2 pixels. Mode 1 / idx 4: exp only on the pattern's pixels, HD = colour at 75% over what is behind.
- Parser bug fixed: the segment loop required a+64 < end+16 before reading the FFFFFFFF end marker, so the last 1-2 polys
  of every op-7 block were rejected (stayed low-res in all scenes). Now: marker needs 2 words, a segment 5.
- Tests: verify 1792/1792 exact to frame 6600, 58.0 fps (identical to the released hd-v1.0 binary). HD compose cost with
  everything wireframe (forced) ~2.5 ms/frame vs ~0.8 normal. Comparisons: hd-experiment/live-hd/wireframe-*.png.
- Not done: bit 12 polys (alt handler FFF48FC0, scaled 2D sprites such as the red arrow decals) are still low-res.
- **Released as hd-v1.1 (2026-11-19)** on STUN_HD60: rebuilt with ./build.sh package + windows, stripped into the AppDir /
  out-hd/STUNRunnerHD60-windows/bin, AppImage via tools/appimagetool (--appimage-extract-and-run --no-appstream), tar.gz =
  AppDir copy + README.txt + run -> AppRun, zip via Python zipfile (README CRLF). v1.0 files moved to package/out-hd-v1.0/.
  Tests: package binary verify 1792/1792, 58.0 fps; AppImage new user 27 images in 23.5 s; Wine 60 fps / 20 ticks.

## Tunnel gates (iris) are flipbook models (2026-11-19): gate morph DONE in the script (local commit)
- Probe scripts/re-probes/gate/jobrec.lua (AY=255 F0 F1 OUT): logs every 68010 -> ADSP upload write (addr, value, PC, A2).
  Labyrinth (Advanced, L11) gate ~frames 4170-4260 (orange/black iris at the tunnel mouth).
- Object slot ids (PC 02E22C/02E236 new slot, 02E360/02E36E update) for the gate object (A2 FFA5F2 in that run) step
  CC,CD,CE,CF,D0,D1,D2,D3 about every 8 frames (~7.5 Hz): 8 pre-built models swapped, no parameter to lerp. lerp_job keeps
  job A's ids, so in-betweens repeat the model. Same scheme for other animated objects (167..16B, E4/E5, DC/DD...).
- **Feasibility done (2026-11-19):** probe re-probes/gate/simrec.lua logs ADSP SIM streams (SIMCLK = ADSP data 0x2001,
  MP = 0x2007 -> base 0x10000*MP, SIMBUF reads 0x2000; env SEQ=1 logs every word). SIM ROM = region ":mainpcb:user1"
  (0x30000 words). Model table: word user1[id] = model address / 4. Model: nv, nv-1, 1, then nv vertices (x, y, z) (the
  last one = face normal (0,0,-16384)); then a face list: one word, then (face address (16-bit, in base-1 window), colour)
  pairs, 0000 0000; each face = 1-based vertex indices after a first word (= normal index), FFFF-terminated.
  Gate iris CC..D3 @1A1C8..1A6E8: flat (z=0), 8 blades (5-6 corners each), nv 29,36,36,37,36,36,35,30: corner counts
  and face order differ per stage -> no plain vertex lerp; morph per blade (match blades by colour + angle, resample the
  outlines to a common corner count). Free space: user1 0x24D81, 45695 zero words (window base 2), enough for blended
  models (write the blend there, point table[id] at it for the in-between job only, restore after).
  Cadence: the model steps every 2 game ticks; real frames show stage X twice, so in-between-only morphing moves 3
  frames then pauses 3. Even motion needs the real frames' model blended too (display only, game logic unaffected).
- Smoothing would need a vertex morph: decode the model format in ADSP memory (geometry streamed from the "SIM" user1
  ROM), check consecutive frames share topology, and for the in-between jobs write blended vertices into a spare model.
- **Gate morph implemented (stunrun-interp60.lua "Gate morph" block; v5 = previous script):** at start it reads models
  CC..D3 from user1 (disabled if the data doesn't look as expected or the buffer area 0x25000+ isn't zero), matches
  blades per adjacent pair (colour + centroid angle, best cyclic shift), pads outlines to equal corner counts (edge
  midpoints, all combinations) and aligns them (best rotation, same winding). Per recorded job (on_ctl release) it tracks
  each 68010 object's model id (PCs 02E22C/02E360, A2) and sets its phase: first job of a stage = id - 0.5 when the
  previous stage lasted >= 2 jobs, else id. gm_apply writes blended models (8 slots of 0x180 words at 0x25000, window
  base 2, table ptr = addr/4) and points table[id] at them, else restores the original pointer. Real jobs: patched at
  the release write; extras: before start_job_2 with phase lerped A->B (|dphase| <= 1). Reset restores the table.
  Env STUN60_GATEMORPH=0 off, STUN60_GATELOG=1 logs stage changes. Must be defined before on_ctl (Lua locals).
- Tests: Labyrinth (re-probes/gate/gate_test.lua, AY=255): gates at ~frame 1133 (level start) and ~2267, cadence
  exactly 2 jobs, verify 1216/1216 exact, 57.25 fps morph on = off; normal verify 1792/1792, 58.0 fps.
  Comparison (3x slow motion): hd-experiment/live-hd/gate-morph-compare.gif (local, not committed).
- **Released as hd-v1.2 (2026-11-19):** script-only change, binaries = v1.1; new script copied into the AppDir and
  out-hd/STUNRunnerHD60-windows/bin, README-HD.txt notes the gate morph; archives rebuilt as for v1.1 (v1.1 files in
  package/out-hd-v1.1/). AppImage + Wine smoke tests: gate morph on, 60 fps / 20 ticks.

## Model morph (2026-11-20): all smoothable flipbook models, RELEASED in hd-v1.3
- Survey (re-probes/flip/idsurvey.lua: per 68010 object A2, model id changes; seqs.py/cad.py summarise): animated ids
  and cadence (game ticks per stage):
  - E4/E5 = the player's shot (long thin triangles); E6 -> E8 -> EA -> EC = spark burst when a shot hits (1 tick each,
    every course, very frequent). Shards are independent triangles flying outward; E8->EA is 1:1, E6 has 7 extra core
    shards, EC shrinks them. Matched by direction from the centre.
  - 124..129 (loop) = flapping bird enemy (wing beat, 5 ticks per pose), rigid panels.
  - FB -> FC = star that grows once after a hit (1 tick), then rests at FC. 12A -> 12B <-> 12C (wobbles every tick)
    -> 12D -> 12E = a drop that splashes; 12C->12D->12E change shape completely (not morphed).
  - CC..D3 gates (2 ticks per stage, existing gate morph).
  - Not morphable: 137..13A = colour chase (same geometry, colours rotate); 162..166 / 167..16B = bit-12 sprite quads
    (only the sprite image changes); DC/DD = left/right street lamp (not an animation).
- Model format corrected: header = n, nvert, nnorm (gates have 1 normal); then n entries (vertices, then normals,
  |normal| ~16384), face normal index = 1-based into all entries. Largest ROM model: 269 entries / 132 faces.
- Offline tools: re-probes/flip/dumpsim.lua (user1 -> out/user1.bin, ignored), model.py (decoder), draw.py (3-view render),
  morph.py (Python prototype of the matcher; renders in-between sheets out/morph-*.png).
- Script "Model morph" block (replaces the gate morph; prev script = stunrun-interp60.lua.v6): GM.SEQ lists sequences
  (gate / burst "shard" / bird + star loop / drip 12A-12C "rigid"). Pairs built at start from the ROM: gates with the old
  blade matcher; others with a Hungarian assignment on cost = side (normal dot, x400: 2-sided panels!) + shape (sorted
  edge lengths) + colour (600) + centroid distance x0.5, or for shards (1-dot(direction))x4000; equal corner counts ->
  best cyclic shift, corners shared via (iA, iB) keys; unmatched / corner-count mismatch -> shrink to / grow from the
  centroid (dropped below 15%). Writer: per-face lerped normals renormalised to 16384, colour switches at 0.5, one 0x400-
  word slot per managed id at 0x25000+ (23 ids). Pairs work both ways (12B<->12C).
  Per object: prev id, current id, d = length of the stage that just ended (capped 8; a rest pose or the first stage counts
  max 2 -> gates behave exactly as before). Display fraction f = min(1, (jc - since + 1) / d). Extras: same stage -> lerp f;
  B starts the next stage -> finish A's blend, then continue B's (t=0 = A exactly, needed for exact verify).
  Env: STUN60_MORPH=0 (or STUN60_GATEMORPH=0) off, STUN60_MORPHLOG=1 (or STUN60_GATELOG=1) logs stage changes.
- Tests: A/B vs v6 (re-probes/flip/ab_test.lua = gate_test with SCRIPT env): same drawn/extra/ticks, Lua ms unchanged,
  startup +~15 ms; verify exact (see current state). Burst before/after strip: flip/out/burst-compare2.png (in-betweens
  now show the sparks spreading). Bird seen only far away headless (few pixels); no glitches. Not yet seen live.

## HD anti-aliasing (2026-11-20): edge-only supersampling + threaded polygon pass, local commit only
- harddriv_v.cpp hd_compose step 3. STUN60_HDAA=A (default 2, 1 = off, max 4); STUN60_HDTHREADS (default
  hardware_concurrency/2 clamped 1..4). Full-frame 2x2 SSAA cost 12-14 ms (3x3: 25 ms) -> rejected.
- Method: pass 1 draws as before (one sample per HD pixel) and marks "edge pixels": per polygon per HD row, spans at the A
  sub-rows (sample units); pixels between the min and max left end and min/max right end are marked (whole union if some
  sub-row is empty). Sub-row spans are stored (band.sub) for pass 2. Pass 2: edge pixels sorted by row (counting sort + small
  per-row sorts), A x A samples initialised from m_hd_pre (copy of the playfield before step 3), all polygons + wireframe
  lines redrawn into those samples in list order with the same rules, averaged back. Equals full supersampling exactly
  (bbox of diff = None on 3 frames). Edge pixels 13k-56k of 1.6M.
- Bands: the playfield rows split into nb = m_hd_threads bands, each drawn by its own std::thread (spawned per frame; band 0
  on the emulation thread); bands share m_hd_eidx/m_hd_pre/bitmap rows disjointly. AA off output = old renderer exactly.
- Cost (3 concurrent test emulators, so pessimistic): polygon pass 1-1.9 ms (AA off) vs 2-3.5 ms (AA 2x2, 4 threads).
  Unthrottled speed with HD always on: v1.3 ~134%, AA off 151%, AA 2x2 127%. Verify 1815/1815 both, same fps/ticks.
- Images: scripts/re-probes/flip/out/aa-zoom.png (before/after tunnel edges, ignored folder).

## HD sprites (2026-11-20): flag-bit-12 records = scaled sprite blits, redrawn from the source image, local commit only
- GSP FFF48FC0 (disassembly: re-probes/sprite/dasm_alt.lua -> out/gsp_alt_full.asm, ignored): record words x0, y0, x1, ya, -, y1;
  sprite number = flags & 0x3F -> 32-bit pointer table FFF78150 (bit address + 32 * n); sprite = height, width, 4 more words,
  then width x height 8-bit pens (same header as the background images), pen 0 transparent (CONTROL E0h: T + window clip).
  Checks (skip when failed): x0 < 0x200, y0 < 0x118, width < 0x15E and height < 0xC8 unless list flags (FFF77E60) bit 4,
  y1 >= 0x28. Stepping: step = (src << 16) / dst (16.16); pixel k shows source k * int + floor((k + 1) * frac), rows alike;
  drawn from (x0, y0) for (y1 - ya + 1) rows.
- **The red arrow / star track markings are NOT sprites** (ordinary polygons; the AA covers them). Sprites seen on both courses
  (STUN60_HDSPRDUMP=dir saves each once as PPM; STUN60_HDSPRLOG=1 logs every 60th list): 03..0C = 10-frame 32x32 impact-spark
  flipbook (very common, shown ~10x10 low-res), 02 = attract story panel 360x168 at FFE00000 (zooms in, then 363x170).
  So the 162..16B model ids of the morph survey are these sprite quads.
- Driver: s60hd_poly.sprite + rect + steps + copied pens (hd_parse_list). Step 1 rasterizes them with the exact GSP stepping
  into m_hd_exp (classification then counts them as 3D: "over" 0 on the panel when the INSERT COIN text is off). Step 3: HD
  pixel takes source floor(u * step) (u = position in low-res pixels from the rectangle's corner; the GSP sample lies in
  [k*step, (k+1)*step], so this is the unbiased version; centre / left-edge variants were 0.4 / 0.8 px too high, measured by
  shift search against v1.3). With AA the whole rectangle is marked as edge pixels (outline + shrunk detail anti-aliased).
- Tests: verify 1815/1815, drawn 54.4, speed 127% (= AA build). Images: re-probes/flip/out/spr-zoom.png (spark),
  re-probes/sprite/out/panel-zoom.png, sprites-sheet.png (all ignored, ROM-derived).

## HD compose pipelined (2026-11-20, user report "announcer at game start sounds choppy")
- Cause: AA added ~3-4 ms/frame in the game-start scene (runner walks to the craft, ~367 polys, ~60k edge pixels) where the
  emulation is busiest; host time per emulated second reached 1123 ms (> 1000 = behind real time = choppy sound).
  Measured with re-probes/flip/ftime.lua (per-frame host ms, WLOG, frames F0..F1, wraps ab_test.lua): worst second
  v1.3 883 ms, AA 4 threads 1123, AA off 890, AA 8 threads 994.
- Fix (user's choice, accepted 1 frame of HD delay): hd_compose runs in a worker thread (m_hd_worker, condvar) while the next
  frame is emulated. At the bottom row: wait for the worker, show its bitmap (m_hd_disp/m_hd_work swap), hd_take_built()
  (moved here from hd_parse_list, so m_hd_bgs changes only while the worker is idle), swap low-res buffers, copy the palette
  (m_hd_pal) + bank (m_hd_bank), start the job. MACHINE_NOTIFY_EXIT joins the worker (hd_stop). STUN60_HDSYNC=1 = old
  synchronous path (no delay).
- Results: worst second 695 ms; pipelined snapshot at frame N+1 == synchronous snapshot at frame N (pixel-identical, 3 frames);
  verify 1815/1815, drawn 54.4, unthrottled speed 179% (v1.3 134%, AA synchronous 127%).

## Pilot walk glide (2026-11-20, user: "the pilot walking to the vehicle is choppy")
- The pilot at game start is NOT 3D: a 2D picture animation (display-list op 8 blit, 72 px wide, y 0x8C, images FFE00000..
  FFE470A0), new image + x step of 7-10 px every 2nd tick (6 frames), same as the arcade. ADSP uploads and ADSP RAM are
  identical tick to tick in that scene (probes re-probes/flip/jobrec60.lua, adspdiff.lua); ops60.lua logs every drawn list's
  ops + args (x of op 8 per frame); pilotpolys.lua (op-7 polys in a box) ruled out polygons.
- Script "Blit glide" block (prev script .v7): at each real publish, op 8 commands are found in the list head (before the
  7000 block, absolute) and the tail (offset from its start; extras rebuild the tail right after their block, CMD 5 returns
  its length) by pattern (8000, y < 0x118, image address >= FF800000 with a sane header). Tracks: same y, nearest x (<= 24),
  pictures <= 256 px wide only. On an x change: glide from the shown position to the new x over d real lists (d = previous
  step's length, capped 8; first step after a rest 2; d = 1 -> no glide, game x). Display x = from + (x - from) *
  min(1, (n - since + tf) / d) patched into the real list (tf 0) and each extra (tf = 1/3, 2/3) after CMD 5.
  Env STUN60_GLIDE=0 off, STUN60_GLIDELOG=1 logs each step.
- Results: pilot moves 1-2 px per frame instead of 7-10 every 6 (one -5 snap at the very end where the game itself goes
  68 -> 76 -> 68 within 3 frames). Full runs: normal 3240/3240 (only the 14 pilot steps glide), Advanced 1891/1891 (a 48 px
  picture at y 3 moving every tick stays unglided). Images still change at the game's 10 Hz.

## HD whole screens + xBR text (2026-11-21, user: "upscale the title screen, the screens between levels, and the HUD")
- User's look choice (sample sheets in scratch: nearest / xBR / hqx / 3 Real-ESRGAN models): Real-ESRGAN for the images
  (title, course map, HUD panel), xBR for the text the game draws. Direct Real-ESRGAN turned small "S" into "9" on the course
  map; pixel-doubling the input first (s60_img.pre = 2) fixes it.
- The header-less streams are whole screens copied straight into the frame buffer (no display-list op, so no blit to follow):
  s1 HUD panel 512x32 (screen row 208), s2 title 512x240, s3 FBI seal, s24 starfield, s25 course map 512x208 (grid, legend,
  circuit panel; track line + text drawn live), s26-28 high-score / story frames (240). Palettes found by matching the live
  palette (re-probes: scratch paldump.lua; palette = first of manager.machine.palettes, 1024 entries) against the ROM: base =
  level-1 base palette $44630; title pens 0-223 at $461F0; image palette $48068[n] from the 16-pen block of the first used pen
  >= 200 (s25: 224, s26-28: 208, s3: 240). Pens 16 / 29 cycle (flashing), the live re-tint handles them.
- Builder: s60_fullscreen_images(); title/HUD/map share batch 1 with level 1's skyline, the other 5 go last. Edge padding =
  repeated edge columns (left/right index clamped). Measured first launch: batch 1 ~18 s (was 3.5 s skyline-only; the 2x
  input costs it), last batch 13 s. Pack 75 -> 135 MB, 35 images.
- Compose (harddriv_v.cpp): hd_add_bg remembers whole-screen keys (512 x 240/208/32). Step 2a samples the frame (every 3rd
  row, 5th column) per area (row 0 / row 208), best image with >= 60% pen match is drawn via hd_draw_bg (synthetic blit
  x 0, y 0x28 + row). Matches: title 97%, HUD 93%, map 100% (rest = text on top). Order now: pick bgs (2a + 2b) ->
  hd_mark_bg (m_hd_img per low-res pixel) -> xBR -> hd_draw_bg.
- xBR (step 2x, STUN60_HDXBR=0 off): low-res pixels with a differing non-3D neighbour (pair pass, m_hd_nf; two HD-image
  pixels never differ) get Hyllian's 4x-filter corner rules (YUV distance 48/7/6, e < i, strong/weak, shallow/steep);
  each HD pixel blends to the corner colour by analytic coverage of the edge line (45: u+v>1.5, shallow u/2+v>1,
  steep u+v/2>1, both u+v>1; AA width from SX/SY). 3D neighbours = own colour. HD pixels that took a neighbour colour are
  marked (m_hd_xm) and hd_draw_bg skips them (smooth text over HD images).
- Cost (HDDEBUG "classify+scale"): gameplay ~3.5 ms (before ~2.3), title/map screens ~7 ms (no 3D there). Verify 1815/1815
  exact, drawn 51.9 / ticks 19.00 = identical to the v1.4 binary on the same run; unthrottled speed 177% -> 160% (HD always on).
- Test notes: re-probes/flip/snap.lua does NOT load the 60 fps script (HD only); ab_test.lua does. Always set STUN60_LOG
  in tests (default log = ~/mame/stun60.log, the user's live log; overwritten by test runs on 2026-11-21).
