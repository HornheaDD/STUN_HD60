#!/usr/bin/env python3
"""Extract S.T.U.N. Runner's background bitmaps (skylines, course maps, title panels) from YOUR OWN stunrun.zip.

The 68010 program ROM holds a pointer table at $BFE00; each entry points to a compressed stream that the game's
routine at $022766 unpacks into GSP video RAM at FFE00000 when a level loads. This is a re-implementation of that
unpacker. The output is ROM-derived: keep it on your own machine, never commit or publish it.

Stream (byte codes, output is a byte stream of 8-bit pens):
  00          load a 16-entry pen table (next 16 bytes)
  0n..3F      n literal bytes
  40          end of stream
  41..7F      n = c & 3F bytes follow, each = 2 pixels: table[hi nibble], table[lo nibble]
  81..BF      n = c & 3F, next byte b repeated n times
  C1..FF      n = c & 3F, next byte b: the pair table[b>>4], table[b&15] repeated n times
The unpacked buffer is a run of images: 12-byte header (u16 height, u16 width, 4 more words) + width*height pens.
"""
import sys, zipfile, struct, argparse, os

MAIN = [("136070-2102.200r", "136070-2101.210r"), ("136070-6104.200s", "136070-6103.210s"),
        ("136070-6106.200t", "136070-6105.210t"), ("136070-2108.200u", "136070-2107.210u"),
        ("136070-2110.200v", "136070-2109.210v"), ("136070-2112.200w", "136070-2111.210w")]
TABLE = 0xBFE00

def load_main(zpath):
    z = zipfile.ZipFile(zpath); names = {os.path.basename(n): n for n in z.namelist()}
    rom = bytearray()
    for even, odd in MAIN:
        e, o = z.read(names[even]), z.read(names[odd])
        rom += bytes(b for p in zip(e, o) for b in p)
    return bytes(rom)

def unpack(rom, a):
    out = bytearray(); t = [0] * 16
    if rom[a] != 0: raise ValueError("stream does not start with a table")
    while True:
        c = rom[a]; a += 1
        n = c & 0x3F
        if c & 0x80:
            if not n: raise ValueError("bad count at %X" % (a - 1))
            b = rom[a]; a += 1
            out += (bytes([t[b >> 4], t[b & 15]]) if c & 0x40 else bytes([b])) * n
        elif c & 0x40:
            if not n: return out
            for b in rom[a:a + n]: out += bytes([t[b >> 4], t[b & 15]])
            a += n
        elif n:
            out += rom[a:a + n]; a += n
        else:
            t = list(rom[a:a + 16]); a += 16

def images(buf):
    """Split an unpacked buffer into (offset, width, height, header_words, pens)."""
    # the 68010 sends each byte pair as one big-endian word; the GSP stores words little-endian (pixel 0 = low byte)
    buf = bytearray(buf + b"\0" * (len(buf) & 1)); buf[0::2], buf[1::2] = buf[1::2], buf[0::2]
    o, res = 0, []
    while o + 12 <= len(buf):
        hdr = struct.unpack_from("<6H", buf, o); h, w = hdr[0], hdr[1]
        if not (0 < w <= 1024 and 0 < h <= 512) or o + 12 + w * h > len(buf): break
        res.append((o, w, h, hdr, bytes(buf[o + 12:o + 12 + w * h]))); o += 12 + w * h
    return res, o

def streams(rom):
    """Yield (number, address) for each distinct stream; entry 0 is unused (the game's image number starts at 1)."""
    seen = set()
    for n in range(1, 128):
        p = struct.unpack_from(">I", rom, TABLE + 4 * n)[0]
        if p == 0 or p >= len(rom) or rom[p] != 0: return
        if p not in seen: seen.add(p); yield n, p

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("zip"); ap.add_argument("outdir")
    args = ap.parse_args()
    rom = load_main(args.zip); os.makedirs(args.outdir, exist_ok=True)
    for n, p in streams(rom):
        buf = unpack(rom, p); ims, used = images(buf)
        print("stream %2d at %06X: %6d bytes, %d image(s)%s" % (n, p, len(buf), len(ims),
              "" if used == len(buf) else ", %d bytes left over" % (len(buf) - used)))
        for i, (o, w, h, hdr, px) in enumerate(ims):
            with open(os.path.join(args.outdir, "s%02d_%d_%dx%d.raw" % (n, i, w, h)), "wb") as f:
                f.write(struct.pack("<HH", w, h) + px)
            print("   image %d: offset %05X (GSP %08X) %dx%d header %s" % (i, o, 0xFFE00000 + o * 8, w, h,
                  " ".join("%04X" % v for v in hdr)))
