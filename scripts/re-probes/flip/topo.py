import collections
from model import model, topo
SEQ = {'expl': [0xE4,0xE5,0xE6,0xE8,0xEA,0xEC], 'A162': list(range(0x162,0x167)), 'B167': list(range(0x167,0x16C)),
       'C124': list(range(0x124,0x12A)), 'D12A': list(range(0x12A,0x12F)), 'E137': list(range(0x137,0x13B)), 'FB': [0xFB,0xFC],
       'DC': [0xDC,0xDD]}
for name, ids in SEQ.items():
    print(name)
    for id in ids:
        m = model(id)
        if not m: print('  %X none' % id); continue
        zs = set(v[2] for v in m['v'][:m['nvert']])
        cols = collections.Counter(c for c, n, i in m['faces'])
        print('  %X @%05X nv %3d/%d faces %3d flat %s cols %s sizes %s' % (id, m['addr'], m['nvert'], m['nnorm'], len(m['faces']), len(zs)==1,
              dict(cols), collections.Counter(len(i) for c,n,i in m['faces']).most_common(3)))
    ts = [topo(model(i)) for i in ids if model(i)]
    print('  same topology for all:', all(t == ts[0] for t in ts))
