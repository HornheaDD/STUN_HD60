S.T.U.N. Runner HD60
====================

Atari's S.T.U.N. Runner (1989) at 60 frames per second and the correct game speed.
This is a custom build of MAME 0.285 (only the S.T.U.N. Runner driver) plus a Lua script.
The game's own 3D chip renders two extra in-between frames per game tick, with the camera
and objects interpolated, so the motion is real 60 fps (not blended frames).
The 3D scene is redrawn in high resolution (1536x1200) from the game's own polygon data (including
the wireframe the craft turns into on a boost and the all-wireframe sections), and the skyline
backgrounds are the game's own artwork upscaled with an AI upscaler (see below).
H switches between the HD picture and the original 512x240 one at any time.
Optional CRT look (scanlines, shadow mask, glow) via MAME's BGFX shaders.

ROMs are NOT included. You need the MAME 0.285 romset "stunrun.zip" (the parent set).

HD backgrounds: what happens on first launch
  No artwork is included in this download: the HD backgrounds are made on your PC from your own
  stunrun.zip, the first time you start the game. You don't have to wait for it:
  - The game starts immediately; the skylines show the original pixels at first.
  - In the background (lowest priority, so the game keeps its speed) the backgrounds are unpacked
    from the ROM and upscaled with Real-ESRGAN (27 images). Level 1's skyline comes first; each one
    switches to HD by itself as soon as it is ready. No restart needed.
  - On a gaming graphics card this takes about 25 seconds in total (level 1 after about 5), so it
    is done before you have put a coin in. A slower graphics card only means the original skylines
    stay a little longer.
  - The result (about 75 MB) is saved in the data folder (hdpack), so later launches are HD from
    the start. Delete that folder to rebuild it.
  - Real-ESRGAN needs a graphics card with Vulkan support (any recent NVIDIA, AMD or Intel driver).
    Without it the game keeps the original skylines; everything else works the same. The reason is
    in hdpack/esrgan.log in the data folder.

Linux (AppImage)
  1. Put STUNRunnerHD60-x86_64.AppImage and stunrun.zip in the same folder
     (or put stunrun.zip in ~/.local/share/stun60-hd/roms; ~/.local/share/stun60/roms from the
     60 fps version is found too).
  2. chmod +x STUNRunnerHD60-x86_64.AppImage, then double-click it or run it.
  Needs glibc 2.36 or newer: Debian 12+, Ubuntu 24.04+, Fedora 37+, Arch/CachyOS and other
  current distros. Uses the system's OpenGL/Vulkan, audio (PulseAudio/PipeWire/ALSA) and fonts.
  If FUSE is missing: ./STUNRunnerHD60-x86_64.AppImage --appimage-extract-and-run
  The .tar.gz is the same thing unpacked: extract it, put stunrun.zip in the folder, run ./run
  Saved data, log, settings and the HD background pack: ~/.local/share/stun60-hd

Windows (64-bit, Windows 10 or 11)
  1. Extract the zip anywhere.
  2. Put stunrun.zip next to STUNRunnerHD60.exe (or in the roms folder).
  3. Run STUNRunnerHD60.exe.
  Saved data, log, settings and the HD background pack: the data folder next to the exe.

Controls and tips
  - MAME's normal controls (5 = coin, 1 = start, Tab = MAME menu, Esc = quit).
  - H switches between the HD picture and the original resolution. The choice is remembered.
  - O cycles the on-screen overlay: small (fps) / full (stats) / off. The choice is remembered.
  - C cycles the screen effect: CRT scanlines (deluxe) / CRT scanlines (sharp) / off.
    The choice is remembered. The first launch starts with CRT deluxe.
    (Same setting as Tab > Slider Controls > "Window 0, Screen 0 Effect", which lists more effects.)
  - The CPUs are overclocked (68010 x3, video x4, 3D x8), which this needs; the launcher sets it.
    Advanced: the environment variable STUN60_CLOCK (e.g. maincpu=3,gsp=4,adsp=8) overrides it,
    STUN60_CRT=deluxe|geom|off forces a screen effect for one launch, and STUN60_HD= (empty) starts
    without the HD screen.
  - Level-change and attract-mode text screens stay at 20 fps (nothing 3D to interpolate there).
  - The iris gates at the tunnel mouths open smoothly: the original steps them like a flipbook
    (about 7 times a second); they are morphed blade by blade. STUN60_GATEMORPH=0 turns this off.
  - It needs a reasonably fast CPU: roughly an Intel 8th-gen quad-core laptop chip or better.
    The HD redraw adds about 2-3 ms of CPU time per frame while the HD picture is shown.
  - The full-screen course map between levels and a few flat 2D objects on the track (such as the
    red arrow markings) are not upscaled yet (original pixels, scaled).
  - STUN60_HDLINE sets the width of the HD wireframe lines in HD pixels (default 2).
  - stun60.log in the data folder shows per-second stats (drawn fps, game ticks, timing).

Credits
  Built on MAME 0.285 (GPL-2.0-or-later; the changed driver files are BSD-3-Clause).
  Real-ESRGAN (realesrgan-ncnn-vulkan) by Xintao Wang et al., BSD-3-Clause, see realesrgan/LICENSE.txt.
  Source and development log: https://github.com/HornheaDD/STUN_HD60
  S.T.U.N. Runner is (c) 1989 Atari Games. Not affiliated with Atari or the MAME team.
