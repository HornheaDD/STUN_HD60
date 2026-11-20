import collections, sys
G = {'expl': {0xE4,0xE5,0xE6,0xE8,0xEA,0xEC}, '124': set(range(0x124,0x12A)), '12A': set(range(0x12A,0x12F)), 'FB': {0xFB,0xFC}, 'DC': {0xDC,0xDD}, '137': set(range(0x137,0x13B)), '162': set(range(0x162,0x16C))}
for fn in sys.argv[1:]:
    rows = [(int(f), a, int(i,16)) for f,a,i in (l.split() for l in open(fn))]
    hist = collections.defaultdict(list)
    for f,a,i in rows: hist[a].append((f,i))
    print(fn)
    for g, ids in G.items():
        d = collections.Counter(); frames = []
        for a,h in hist.items():
            for (f0,i0),(f1,i1) in zip(h,h[1:]):
                if i0 in ids and i1 in ids: d[f1-f0]+=1
            frames += [f for f,i in h if i in ids]
        print('  %-5s steps(frames:count) %s  seen frames %s' % (g, dict(sorted(d.items())), (min(frames), max(frames)) if frames else '-'))
