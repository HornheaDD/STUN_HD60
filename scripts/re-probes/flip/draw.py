from model import model
from PIL import Image, ImageDraw
import sys, colorsys
def draw(ids, fn, views=((0,1),(0,2),(2,1)), S=300):
    im = Image.new('RGB', (S*len(ids), S*len(views)), 'white'); d = ImageDraw.Draw(im)
    allv = [v for i in ids for v in model(i)['v'][:model(i)['nvert']]]
    ext = max(abs(c) for v in allv for c in v) or 1
    for col, id in enumerate(ids):
        m = model(id)
        for row, (a, b) in enumerate(views):
            for fc, n, idx in m['faces']:
                pts = [(col*S + S/2 + m['v'][i-1][a]/ext*S*0.45, row*S + S/2 - m['v'][i-1][b]/ext*S*0.45) for i in idx]
                h = (fc & 0x3F) / 64.0
                rgb = tuple(int(255*x) for x in colorsys.hsv_to_rgb(h, 0.6, 0.9))
                d.polygon(pts, fill=rgb, outline='black')
        d.text((col*S+4, 4), '%X' % id, fill='black')
    im.save(fn)
if __name__ == '__main__':
    draw([int(x,16) for x in sys.argv[2:]], sys.argv[1])
