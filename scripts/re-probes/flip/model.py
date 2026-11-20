import struct, sys
W = struct.unpack('<%dH' % (393216//2), open(sys.argv[1] if len(sys.argv)>1 and sys.argv[1].endswith('.bin') else 'out/user1.bin','rb').read())
def s(v): return v-0x10000 if v>=0x8000 else v
def model(id):
    a = W[id]*4
    nv = W[a]
    if nv < 2 or nv > 400 or W[a+1] + W[a+2] != nv: return None
    v = [(s(W[a+3+3*i]), s(W[a+4+3*i]), s(W[a+5+3*i])) for i in range(nv)]
    base = a & ~0xFFFF
    q = base + W[a+3+3*nv]; faces = []
    while W[q] != 0 and len(faces) < 300:
        fp, col = W[q], W[q+1]; q += 2
        r = base + fp; nidx = W[r]; r += 1; idx = []
        while W[r] != 0xFFFF and len(idx) < 40: idx.append(W[r]); r += 1
        faces.append((col, nidx, idx))
    return dict(addr=a, nv=nv, nvert=W[a+1], nnorm=W[a+2], v=v, faces=faces)
def topo(m): return [(c, n, tuple(i)) for c, n, i in m['faces']]
if __name__ == '__main__':
    for a in sys.argv[1:]:
        if a.endswith('.bin'): continue
        id = int(a, 16); m = model(id)
        if not m: print('%X: not a model' % id); continue
        print('%X @%X nv %d faces %d' % (id, m['addr'], m['nv'], len(m['faces'])))
        for c, n, i in m['faces']: print('   col %04X n%d' % (c, n), i)
