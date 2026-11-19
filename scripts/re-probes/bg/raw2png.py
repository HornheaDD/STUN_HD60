# Convert extract.lua output (out/img/*.raw + .pal) to PNG (indices -> RGB with the palette captured alongside).
import sys, glob, os, struct
from PIL import Image
D = sys.argv[1] if len(sys.argv) > 1 else 'out/img'
for raw in sorted(glob.glob(os.path.join(D, '*.raw'))):
    d = open(raw, 'rb').read(); w, h = struct.unpack('<HH', d[:4]); px = d[4:4 + w*h]
    pal = []
    for line in open(raw[:-4] + '.pal'):
        lo, hi = (int(v, 16) for v in line.split()); pal.append((lo >> 8, lo & 255, hi & 255))
    im = Image.new('RGB', (w, h)); im.putdata([pal[p] for p in px]); im.save(raw[:-4] + '.png')
    print(os.path.basename(raw), w, h, 'distinct pens', len(set(px)))
