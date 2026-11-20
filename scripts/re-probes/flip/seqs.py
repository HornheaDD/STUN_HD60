import sys, collections
for fn in sys.argv[1:]:
    rows = [l.split() for l in open(fn)]
    hist = collections.defaultdict(list)
    for f, a2, id in rows: hist[a2].append((int(f), int(id, 16)))
    trans = collections.Counter()
    for a2, h in hist.items():
        for (f0, i0), (f1, i1) in zip(h, h[1:]):
            if f1 - f0 <= 20: trans[(i0, i1, f1-f0)] += 1
    # group into chains of ids by transitions
    nxt = collections.defaultdict(collections.Counter)
    for (a, b, df), n in trans.items(): nxt[a][b] += n
    print(fn)
    seen = set()
    for a in sorted(nxt):
        print('  %3X -> %s' % (a, ' '.join('%X(%d)' % (b, n) for b, n in nxt[a].most_common(4))))
