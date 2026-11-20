from model import model
import math, sys
def faces(id):
    m = model(id); out = []
    for c,n,idx in m['faces']:
        p = [m['v'][i-1] for i in idx]
        cen = [sum(q[k] for q in p)/len(p) for k in range(3)]
        out.append(dict(c=c, p=p, cen=cen, n=len(p), nrm=m['v'][n-1]))
    return out
def cost(f, g):
    return math.dist(f['cen'], g['cen']) + (0 if f['c']==g['c'] else 1000) + (0 if f['n']==g['n'] else 300)
def report(a, b):
    A, B = faces(a), faces(b)
    # greedy global assignment
    cand = sorted((cost(f,g), i, j) for i,f in enumerate(A) for j,g in enumerate(B))
    ua, ub, pairs = set(), set(), []
    for c,i,j in cand:
        if i in ua or j in ub: continue
        ua.add(i); ub.add(j); pairs.append((c,i,j))
    ext = max(max(abs(x) for x in f['cen']) for f in A)
    bad = [p for p in pairs if p[0] >= 300]
    print('%X->%X faces %d->%d matched %d, mean dist %.0f (extent %.0f), max %.0f, cross-colour/size %d, unmatched A %d B %d' % (
        a, b, len(A), len(B), len(pairs), sum(p[0] for p in pairs if p[0]<300)/max(1,len(pairs)-len(bad)), ext, max(p[0] for p in pairs), len(bad), len(A)-len(ua), len(B)-len(ub)))
seqs = {'124':[0x124,0x125,0x126,0x127,0x128,0x129,0x124], 'FB':[0xFB,0xFC,0xFB], '12A':[0x12A,0x12B,0x12C,0x12D,0x12E], 'expl':[0xE6,0xE8,0xEA,0xEC], 'DC':[0xDC,0xDD]}
for k,s in seqs.items():
    print(k)
    for a,b in zip(s,s[1:]): report(a,b)
