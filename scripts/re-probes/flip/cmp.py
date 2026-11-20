from model import model
import sys
def faces_xyz(m):
    return sorted((c, tuple(m['v'][i-1] for i in idx)) for c, n, idx in m['faces'])
def desc(ids):
    for a, b in zip(ids, ids[1:] + ids[:1]):
        A, B = model(a), model(b)
        va, vb = A['v'][:A['nvert']], B['v'][:B['nvert']]
        print('  %X->%X verts same %s, vertex-set same %s, faces(by coords) same %s, cols same %s' % (a, b, va == vb, sorted(va)==sorted(vb),
              faces_xyz(A) == faces_xyz(B), sorted(c for c,_,_ in A['faces']) == sorted(c for c,_,_ in B['faces'])))
for name, ids in [('137', [0x137,0x138,0x139,0x13A]), ('124',list(range(0x124,0x12A))), ('162',list(range(0x162,0x167))), ('FB',[0xFB,0xFC]), ('DC',[0xDC,0xDD]), ('12A',list(range(0x12A,0x12F)))]:
    print(name); desc(ids)
m=model(0x137); print([ (c, idx) for c,n,idx in m['faces']]); print(m['v'][:8])
m=model(0x138); print([ (c, idx) for c,n,idx in m['faces']]); print(m['v'][:8])
for i in range(0x162,0x167): print('%X'%i, model(i)['v'])
