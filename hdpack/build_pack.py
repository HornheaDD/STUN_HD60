#!/usr/bin/env python3
"""Build the HD background pack for S.T.U.N. Runner HD60 from YOUR OWN stunrun.zip.

Unpacks the background images with stunbg.py, upscales them with Real-ESRGAN (realesrgan-x4plus) and writes one
.s60bg file per image into the pack folder. The pack is ROM-derived: keep it on your own machine, never publish it.

Each image is upscaled once to the HD screen's scale (SX x SY, default 3x5). The file also keeps, for every HD pixel,
the original pen it came from, so the game can re-tint it with the live palette (fades, colour cycling).

.s60bg layout (little-endian):
  char[8] "S60BG01\\0"; u32 key (FNV-1a of the low-res pen bytes, matched against GSP RAM in game);
  u16 w, h (low-res); u16 sx, sy; 16 x (r, g, b) reference colours for pens 240-255 (what the upscale saw);
  u32 rgb[w*sx * h*sy] (0xFFRRGGBB); u8 pen[w*sx * h*sy].
"""
import argparse, os, struct, subprocess, sys, tempfile
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stunbg

PAD = 16   # low-res pixels of context added around each image before upscaling (wrap-around left/right)

def fnv(b):
    h = 2166136261
    for x in b: h = ((h ^ x) * 16777619) & 0xffffffff
    return h

def esrgan(exe, model, src, dst):
    models = os.path.join(os.path.dirname(exe), "models")
    r = subprocess.run([exe, "-i", src, "-o", dst, "-n", model, "-s", "4", "-m", models],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if r.returncode != 0 or not os.path.exists(dst):
        raise RuntimeError("realesrgan failed: " + r.stdout[-500:])

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("zip"); ap.add_argument("pack")
    ap.add_argument("--realesrgan", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "build", "tools", "realesrgan", "realesrgan-ncnn-vulkan"))
    ap.add_argument("--model", default="realesrgan-x4plus")
    ap.add_argument("--scale", default="3x5")
    ap.add_argument("--keep-png", action="store_true", help="also save the HD images as PNG for viewing")
    a = ap.parse_args()
    sx, sy = (int(v) for v in a.scale.split("x"))
    rom = stunbg.load_main(a.zip)
    os.makedirs(a.pack, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="s60bg-")
    n_out = 0
    for n, p in stunbg.streams(rom):
        pal = stunbg.palette(rom, n)
        ims, _ = stunbg.images(stunbg.unpack(rom, p))
        # gameplay backgrounds: every pen in 240-255 (colours fully defined by the image's own palette)
        ims = [im for im in ims if min(im[4]) >= 240]
        if not pal or not ims: continue
        for i, (o, w, h, hdr, px) in enumerate(ims):
            # neighbours for the wrap-around padding: panoramas are drawn as image i next to image i+1 (cyclic)
            left, right = ims[i - 1][4] if len(ims) > 1 else px, ims[(i + 1) % len(ims)][4] if len(ims) > 1 else px
            lw, rw = ims[i - 1][1] if len(ims) > 1 else w, ims[(i + 1) % len(ims)][1] if len(ims) > 1 else w
            W, H = w + 2 * PAD, h + 2 * PAD
            def pen(x, y):
                y = min(max(y, 0), h - 1)
                if x < 0: return left[y * lw + lw + x]
                if x >= w: return right[y * rw + (x - w)]
                return px[y * w + x]
            src = Image.new("RGB", (W, H))
            src.putdata([pal[pen(x - PAD, y - PAD) - 240] for y in range(H) for x in range(W)])
            sp, dp = os.path.join(tmp, "in.png"), os.path.join(tmp, "out.png")
            src.save(sp); esrgan(a.realesrgan, a.model, sp, dp)
            up = Image.open(dp).convert("RGB")                                   # 4x
            up = up.resize((W * sx, H * sy), Image.Resampling.LANCZOS)          # to the HD screen's scale
            up = up.crop((PAD * sx, PAD * sy, (PAD + w) * sx, (PAD + h) * sy))
            rgb = up.tobytes()
            pens = bytes(px[(Y // sy) * w + (X // sx)] for Y in range(h * sy) for X in range(w * sx))
            key = fnv(px)
            name = "s%02d_%d" % (n, i)
            with open(os.path.join(a.pack, name + ".s60bg"), "wb") as f:
                f.write(b"S60BG01\0" + struct.pack("<IHHHH", key, w, h, sx, sy))
                f.write(bytes(c for col in pal for c in col))
                f.write(up.convert("RGBA").tobytes("raw", "BGRA"))   # u32 0x??RRGGBB little-endian
                f.write(pens)
            if a.keep_png: up.save(os.path.join(a.pack, name + ".png"))
            n_out += 1
            print("%s: %dx%d -> %dx%d key %08X" % (name, w, h, w * sx, h * sy, key), flush=True)
    print("pack: %d images in %s" % (n_out, a.pack))

if __name__ == "__main__":
    main()
