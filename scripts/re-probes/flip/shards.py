from model import model
import math
def shards(id):
    m = model(id); out = []
    for c,n,idx in m['faces']:
        p = [m['v'][i-1] for i in idx]
        cx = [sum(q[k] for q in p)/len(p) for k in range(3)]
        r = math.sqrt(sum(x*x for x in cx)) or 1
        size = max(math.dist(p[i], p[j]) for i in range(len(p)) for j in range(len(p)))
        out.append(dict(c=c, cen=cx, r=r, dir=[x/r for x in cx], size=size, p=p))
    return out
def match(a, b):
    A, B = shards(a), shards(b)
    print('%X(%d) -> %X(%d)' % (a, len(A), b, len(B)))
    used = set()
    for i, s in enumerate(A):
        best = max(range(len(B)), key=lambda j: sum(x*y for x,y in zip(s['dir'], B[j]['dir'])))
        dot = sum(x*y for x,y in zip(s['dir'], B[best]['dir']))
        print('  %2d r%5.0f sz%4.0f c%04X -> %2d r%5.0f sz%4.0f c%04X dot %.3f %s' % (i, s['r'], s['size'], s['c'], best, B[best]['r'], B[best]['size'], B[best]['c'], dot, 'DUP' if best in used else ''))
        used.add(best)
for a,b in [(0xE6,0xE8),(0xE8,0xEA),(0xEA,0xEC)]: match(a,b)
