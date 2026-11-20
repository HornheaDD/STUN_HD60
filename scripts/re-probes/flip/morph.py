# prototype of the generic model morph: match faces A->B, build blended models
from model import model
import math
def faces(m):
    out = []
    for k,(c,n,idx) in enumerate(m['faces']):
        p = [m['v'][i-1] for i in idx]
        cen = [sum(q[j] for q in p)/len(p) for j in range(3)]
        r = math.sqrt(sum(x*x for x in cen)) or 1.0
        el = sorted(math.dist(p[i], p[(i+1)%len(p)]) for i in range(len(p)))
        out.append(dict(c=c, idx=idx, p=p, cen=cen, r=r, dir=[x/r for x in cen], el=el, nrm=m['v'][n-1]))
    return out
def ndot(f, g):
    a, b = f['nrm'], g['nrm']
    return sum(x*y for x,y in zip(a,b)) / ((math.sqrt(sum(x*x for x in a)) * math.sqrt(sum(x*x for x in b))) or 1)
def cost(f, g, kind):
    side = (1 - ndot(f, g)) * 400          # front/back faces of double-sided panels
    if kind == 'shard':     # particles flying out: same direction from the centre
        dot = sum(a*b for a,b in zip(f['dir'], g['dir']))
        return side + (1 - dot) * 4000 + (0 if len(f['p']) == len(g['p']) else 500)
    shape = sum(abs(a-b) for a,b in zip(f['el'], g['el'])) if len(f['el']) == len(g['el']) else 400
    return side + shape + (0 if f['c'] == g['c'] else 600) + math.dist(f['cen'], g['cen']) * 0.5
def hungarian(C):                       # square matrix, min cost assignment; returns row->col
    n = len(C); INF = float('inf')
    u = [0]*(n+1); v = [0]*(n+1); p = [0]*(n+1); way = [0]*(n+1)
    for i in range(1, n+1):
        p[0] = i; j0 = 0; minv = [INF]*(n+1); used = [False]*(n+1)
        while True:
            used[j0] = True; i0 = p[j0]; delta = INF; j1 = 0
            for j in range(1, n+1):
                if not used[j]:
                    cur = C[i0-1][j-1] - u[i0] - v[j]
                    if cur < minv[j]: minv[j] = cur; way[j] = j0
                    if minv[j] < delta: delta = minv[j]; j1 = j
            for j in range(n+1):
                if used[j]: u[p[j]] += delta; v[j] -= delta
                else: minv[j] -= delta
            j0 = j1
            if p[j0] == 0: break
        while True:
            j1 = way[j0]; p[j0] = p[j1]; j0 = j1
            if j0 == 0: break
    r = [None]*n
    for j in range(1, n+1): r[p[j]-1] = j-1
    return r
UNM = 3000
def match(a, b, kind):
    A, B = faces(model(a)), faces(model(b)); n = max(len(A), len(B))
    C = [[(cost(A[i], B[j], kind) if i < len(A) and j < len(B) else UNM) for j in range(n)] for i in range(n)]
    asg = hungarian(C); pairs = []
    for i, j in enumerate(asg):
        fa = A[i] if i < len(A) else None; fb = B[j] if j < len(B) else None
        if fa and fb and C[i][j] >= UNM: pairs += [(fa, None), (None, fb)]
        elif fa or fb: pairs.append((fa, fb))
    return pairs
def align(fa, fb):
    # same corner count: best cyclic shift of fb (centroid-relative), keeps winding; returns index pairs
    n = len(fa['p']); best = None
    for r in range(n):
        c = sum(math.dist([x-y for x,y in zip(fa['p'][i], fa['cen'])], [x-y for x,y in zip(fb['p'][(i+r)%n], fb['cen'])]) for i in range(n))
        if best is None or c < best[0]: best = (c, r)
    return [(fa['idx'][i], fb['idx'][(i+best[1])%n]) for i in range(n)]
def blend(a, b, kind, t):
    ma, mb = model(a), model(b); verts, key, out = [], {}, []
    for fa, fb in match(a, b, kind):
        if fa and fb and len(fa['p']) == len(fb['p']):
            ids = align(fa, fb)
            pts = []
            for ia, ib in ids:
                k = (ia, ib)
                if k not in key:
                    A_, B_ = ma['v'][ia-1], mb['v'][ib-1]
                    key[k] = len(verts); verts.append(tuple(A_[j] + (B_[j]-A_[j])*t for j in range(3)))
                pts.append(key[k])
            col = fa['c'] if t < 0.5 else fb['c']
        else:   # unmatched (or corner count differs): collapse to/grow from the centroid
            f = fa or fb; s = (1 - t) if (fa and not fb) else t
            if fa and fb: f, s = (fa, 1 - 2*t) if t < 0.5 else (fb, 2*t - 1)
            if s < 0.15: continue
            pts = []
            for q in f['p']:
                verts.append(tuple(f['cen'][j] + (q[j]-f['cen'][j])*s for j in range(3))); pts.append(len(verts)-1)
            col = f['c']
        out.append((col, pts))
    return verts, out
if __name__ == '__main__':
    from PIL import Image, ImageDraw
    import colorsys, sys
    SEQ = [('expl', 'shard', [0xE6,0xE8,0xEA,0xEC]), ('bird', 'rigid', [0x124,0x125,0x126,0x127,0x128,0x129,0x124]),
           ('star', 'rigid', [0xFB,0xFC,0xFB]), ('drip', 'rigid', [0x12A,0x12B,0x12C])]
    for name, kind, ids in SEQ:
        frames = []
        for a, b in zip(ids, ids[1:]):
            for t in (0, 1/3, 2/3): frames.append(blend(a, b, kind, t))
        frames.append(blend(ids[-2], ids[-1], kind, 1))
        views = ((0,1),(0,2),(2,1)) ; S = 220
        ext = max(abs(c) for v,_ in frames for p in v for c in p)
        im = Image.new('RGB', (S*len(frames), S*3), 'white'); d = ImageDraw.Draw(im)
        for col,(v,fs) in enumerate(frames):
            for row,(x,y) in enumerate(views):
                for c, pts in fs:
                    rgb = tuple(int(255*q) for q in colorsys.hsv_to_rgb((c & 0x3F)/64, 0.6, 0.9))
                    d.polygon([(col*S+S/2+v[i][x]/ext*S*0.45, row*S+S/2-v[i][y]/ext*S*0.45) for i in pts], fill=rgb, outline='black')
            d.text((col*S+3,3), '%d%s' % (col//3, ['', '+1/3', '+2/3'][col%3]), fill='black')
        im.save('out/morph-%s.png' % name)
        nv = max(len(v) for v,_ in frames); nf = max(len(f) for _,f in frames)
        print(name, 'frames', len(frames), 'max verts', nv, 'max faces', nf)
