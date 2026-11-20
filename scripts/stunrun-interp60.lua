-- S.T.U.N. Runner: 60 fps by in-engine interpolation (live prototype)
--
-- The game updates its logic and 3D scene 20 times a second (one ADSP render per tick).
-- This script makes the game's own ADSP render two extra frames per tick, with the camera
-- and all moving objects placed 1/3 and 2/3 of the way to the next tick, and shows them
-- in between the real frames. Game logic still runs at its normal 20 ticks per second.
--
-- Needs overclocking (Tab > Slider Controls, MAME started with -cheat): gsp, adsp and
-- maincpu at about 400%. Without enough overclock the extra frames are dropped and the
-- game falls back to its normal 20 fps pacing (never runs fast or slow because of this).
-- RAM/IO patching; the only ROM change is the model morph (blended flipbook models in unused SIM ROM space, see below).
-- See CLAUDE.md for how it works.

-- MAME re-runs the autoboot script after a machine reset; keep only the first instance.
if STUN60_INSTANCE then return end
STUN60_INSTANCE = true
DBG = os.getenv("STUN60_DEBUG") == "1"
local VERIFY = os.getenv("STUN60_VERIFY") == "1"   -- headless check: also render t=0 and compare
-- STUN60_DATA (set by the packaged launchers): folder for the log and the overlay setting; else the old ~/mame paths
local DATA   = os.getenv("STUN60_DATA")
local HOMED  = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
local LOGF   = os.getenv("STUN60_LOG") or (DATA and (DATA .. "/stun60.log")) or (HOMED .. "/mame/stun60.log")   -- log file (always on)
-- STUN60_SPREAD: 2 (default) = one ADSP job per refresh (extra 1 / extra 2 / next real job),
-- 1 = only extra 2 delayed, 0 = old schedule (all three back to back in one frame)
local SPMODE = os.getenv("STUN60_SPREAD") or "2"
local SPREAD2 = SPMODE == "2"
local SPREAD = SPMODE ~= "0"
local RELAX  = os.getenv("STUN60_RELAX") == "1"    -- testing: ignore deadlines (slow motion, shows every frame)
local TS     = {1/3, 2/3}
local function DL(x) if RELAX then return x + 1e6 end return x end

local mach = manager.machine
local m    = mach.devices[":mainpcb:maincpu"]
local ms   = m.spaces["program"]
local MPC  = m.state["PC"]
local MA2  = m.state["A2"]
local MD5  = m.state["D5"]
local ad   = mach.devices[":mainpcb:adsp"].spaces["data"]
local gsp  = mach.devices[":mainpcb:gsp"].spaces["program"]
local scr  = mach.screens[":mainpcb:screen"]
local FP   = scr.frame_period
local function now() return mach.time:as_double() / FP end   -- in screen refreshes

local logf = LOGF and io.open(LOGF, "w")
local function L(s) if logf then logf:write(string.format("%10.3f %s\n", now(), s)); logf:flush() end end

-- ---------------------------------------------------------------------------
-- state
local self_write = false        -- our own writes must not trigger our own taps
local bank = 0                  -- 68k buffer bank last selected by the 68010
local rec, jobs = nil, {}       -- recorded ADSP job uploads {addr, data, pc}
local jobcount = 0
local cycle = nil               -- current interpolation cycle (one per real list)
local cap_target = 3
local st = {gspf = 0, extra = 0, ticks = 0, drop = 0, cyc = 0}
local shown = {gspf = "--", extra = "--", ticks = "--", drop = "--"}

local POS = {[0x02E342]=1,[0x02E34C]=1,[0x02E356]=1,[0x02E24A]=1,[0x02E250]=1,[0x02E256]=1,
             [0x02E16C]=1,[0x02E176]=1,[0x02E180]=1,[0x02DED6]=1,[0x02DEE0]=1,[0x02DEEA]=1}
local MAT = {[0x022DE0]=1,[0x022DE2]=1,[0x022DE4]=1,[0x022DE6]=1,[0x022DE8]=1}
local function s16(v) v = v & 0xffff; if v >= 0x8000 then return v - 0x10000 end return v end
local function s32(v) if v >= 0x80000000 then return v - 0x100000000 end return v end
local function W68(a, d) self_write = true; ms:write_u16(a, d); self_write = false end
local function WG(a, d)  self_write = true; gsp:write_u16(a, d); self_write = false end

-- ---------------------------------------------------------------------------
-- Model morph: some objects are flipbooks of pre-built 3D models that the game switches every tick or few ticks
-- (iris gates at tunnel mouths, the spark burst when a shot hits, the flapping bird, the pulsing star, the drip).
-- For even motion every rendered frame (the real ones too) gets a blend between the previous and the current model:
-- faces are matched between consecutive models (gates: blades by colour + angle; others: min-cost assignment on
-- shape, colour, side and position, or on direction for the burst's flying shards), corners aligned, and the blended
-- model is written into unused SIM ROM space; the model table entry of the id in the object slot points at it while
-- the ADSP renders that job (display only, game logic unaffected). Everything is built at start from the ROM itself.
-- SIM ROM ("user1"): word [id] = model address / 4. Model: n, nvert, nnorm, n entries (x, y, z: vertices, then face
-- normals), a pointer to the face list, (face address, colour) pairs, 0 0, faces (normal index, 1-based vertex
-- indices, FFFF). Addresses are 16-bit inside the model's 0x10000-word window.
-- Env: STUN60_MORPH=0 (or the old STUN60_GATEMORPH=0) off, STUN60_MORPHLOG=1 logs stage changes.
local GM = {on = os.getenv("STUN60_MORPH") ~= "0" and os.getenv("STUN60_GATEMORPH") ~= "0",
            log = os.getenv("STUN60_MORPHLOG") == "1" or os.getenv("STUN60_GATELOG") == "1",
            BUF = 0x25000, SLOT = 0x400}
GM.SEQ = {
  {name = "gate",  kind = "gate",  ids = {0xCC, 0xCD, 0xCE, 0xCF, 0xD0, 0xD1, 0xD2, 0xD3}},
  {name = "burst", kind = "shard", ids = {0xE6, 0xE8, 0xEA, 0xEC}},
  {name = "bird",  kind = "rigid", ids = {0x124, 0x125, 0x126, 0x127, 0x128, 0x129}, loop = true},
  {name = "star",  kind = "rigid", ids = {0xFB, 0xFC}, loop = true},
  {name = "drip",  kind = "rigid", ids = {0x12A, 0x12B, 0x12C}},
}
do
  local R = mach.memory.regions[":mainpcb:user1"]
  GM.R = R
  local function rw(i) return R:read_u16(i * 2) end
  local function sw(v) if v >= 0x8000 then return v - 0x10000 end return v end
  local function dist(a, b) local s = 0; for k = 1, #a do s = s + (a[k] - b[k])^2 end; return math.sqrt(s) end
  -- generic model: entries (vertices + normals), nvert, faces {c, n (normal entry), idx}
  local function model(id)
    local a = rw(id) * 4
    local n, nvert = rw(a), rw(a + 1)
    if n < 2 or n > 400 or nvert + rw(a + 2) ~= n then return nil end
    local v = {}
    for i = 0, n - 1 do v[i + 1] = {sw(rw(a + 3 + 3*i)), sw(rw(a + 4 + 3*i)), sw(rw(a + 5 + 3*i))} end
    local base = a & ~0xFFFF
    local q, faces = base + rw(a + 3 + 3*n), {}
    while rw(q) ~= 0 do
      if #faces >= 200 then return nil end
      local r = base + rw(q); local col = rw(q + 1); q = q + 2
      local f = {c = col, n = rw(r), idx = {}}
      if not v[f.n] then return nil end
      r = r + 1
      while rw(r) ~= 0xFFFF do
        local i = rw(r); if i < 1 or i > nvert or #f.idx >= 40 then return nil end
        f.idx[#f.idx+1] = i; r = r + 1
      end
      if #f.idx < 3 then return nil end
      faces[#faces+1] = f
    end
    return {v = v, nvert = nvert, faces = faces}
  end
  GM.model = model

  -- gates: flat blades, matched by colour + centroid angle, outlines padded to equal corner counts
  local CY = 1561
  local function ang(p) local x, y = 0, 0; for _,q in ipairs(p) do x = x + q[1]; y = y + q[2] end; return math.atan(y / #p - CY, x / #p) end
  local function area(p) local s = 0; for i = 1, #p do local a, b = p[i], p[i % #p + 1]; s = s + a[1]*b[2] - b[1]*a[2] end; return s end
  local function pads(P, N)       -- every way to add N - #P points on the edges of P (evenly spaced on an edge)
    local out, n = {}, #P
    local function rec(i, left, cnt)
      if i > n then
        if left == 0 then
          local o = {}
          for k = 1, n do
            local a, b = P[k], P[k % n + 1]; o[#o+1] = a
            for j = 1, cnt[k] do local t = j / (cnt[k] + 1); o[#o+1] = {a[1] + (b[1]-a[1])*t, a[2] + (b[2]-a[2])*t} end
          end
          out[#out+1] = o
        end
        return
      end
      for c = 0, left do cnt[i] = c; rec(i + 1, left - c, cnt) end
    end
    rec(1, N - n, {})
    return out
  end
  local function align2(P, Q)
    local N = math.max(#P, #Q)
    if (area(P) > 0) ~= (area(Q) > 0) then local r = {}; for i = #Q, 1, -1 do r[#r+1] = Q[i] end; Q = r end
    local best, bp, bq = nil
    for _,Pp in ipairs(pads(P, N)) do
      for _,Qp in ipairs(pads(Q, N)) do
        for r = 0, N - 1 do
          local c = 0
          for i = 1, N do local a, b = Pp[i], Qp[(i - 1 + r) % N + 1]; c = c + (a[1]-b[1])^2 + (a[2]-b[2])^2 end
          if not best or c < best then
            best, bp = c, Pp
            bq = {}; for i = 1, N do bq[i] = Qp[(i - 1 + r) % N + 1] end
          end
        end
      end
    end
    return bp, bq
  end
  local NZ = {0, 0, -16384}
  local function gate_pairs(ma, mb)
    local function blades(m)
      local out = {}
      for _,f in ipairs(m.faces) do
        local pts = {}
        for _,i in ipairs(f.idx) do if m.v[i][3] ~= 0 then return nil end; pts[#pts+1] = {m.v[i][1], m.v[i][2]} end
        if #pts > 12 then return nil end
        out[#out+1] = {col = f.c, pts = pts}
      end
      return #out == 8 and out or nil
    end
    local A, B = blades(ma), blades(mb)
    if not (A and B) then return nil end
    table.sort(A, function(x, y) return ang(x.pts) < ang(y.pts) end)
    table.sort(B, function(x, y) return ang(x.pts) < ang(y.pts) end)
    local best, bs = nil, 0
    for sft = 0, #B - 1 do
      local c = 0
      for i, f in ipairs(A) do
        local g = B[(i - 1 + sft) % #B + 1]
        local d = math.abs((ang(f.pts) - ang(g.pts) + math.pi) % (2 * math.pi) - math.pi)
        c = c + d + ((g.col ~= f.col) and 100 or 0)
      end
      if not best or c < best then best, bs = c, sft end
    end
    local prs = {}
    for i, f in ipairs(A) do
      local g = B[(i - 1 + bs) % #B + 1]
      local P, Q = align2(f.pts, g.pts)
      local pp, qq = {}, {}
      for k = 1, #P do pp[k] = {P[k][1], P[k][2], 0}; qq[k] = {Q[k][1], Q[k][2], 0} end
      prs[#prs+1] = {ca = f.col, cb = f.col, P = pp, Q = qq, na = NZ, nb = NZ}
    end
    return prs
  end

  -- 3D sequences: faces matched by a min-cost assignment
  local function fdesc(m)
    local out = {}
    for _,f in ipairs(m.faces) do
      local p = {}
      for _,i in ipairs(f.idx) do p[#p+1] = m.v[i] end
      local cen = {0, 0, 0}
      for _,q in ipairs(p) do for k = 1, 3 do cen[k] = cen[k] + q[k] / #p end end
      local r = math.sqrt(cen[1]^2 + cen[2]^2 + cen[3]^2); if r == 0 then r = 1 end
      local el = {}
      for i = 1, #p do el[i] = dist(p[i], p[i % #p + 1]) end
      table.sort(el)
      local nr = m.v[f.n]
      local nl = math.sqrt(nr[1]^2 + nr[2]^2 + nr[3]^2); if nl == 0 then nl = 1 end
      out[#out+1] = {c = f.c, idx = f.idx, p = p, cen = cen, dir = {cen[1]/r, cen[2]/r, cen[3]/r}, el = el,
                     nrm = nr, nu = {nr[1]/nl, nr[2]/nl, nr[3]/nl}}
    end
    return out
  end
  local function cost(f, g, kind)
    local side = (1 - (f.nu[1]*g.nu[1] + f.nu[2]*g.nu[2] + f.nu[3]*g.nu[3])) * 400   -- front/back of 2-sided panels
    if kind == "shard" then          -- particles flying outward: same direction from the centre
      local dot = f.dir[1]*g.dir[1] + f.dir[2]*g.dir[2] + f.dir[3]*g.dir[3]
      return side + (1 - dot) * 4000 + ((#f.p == #g.p) and 0 or 500)
    end
    local shape = 400
    if #f.el == #g.el then shape = 0; for i = 1, #f.el do shape = shape + math.abs(f.el[i] - g.el[i]) end end
    return side + shape + ((f.c == g.c) and 0 or 600) + dist(f.cen, g.cen) * 0.5
  end
  local function hungarian(C, n)       -- square n x n cost matrix -> row -> column (min total cost)
    local INF = math.huge
    local u, v, p, way = {}, {}, {}, {}
    for j = 0, n do u[j] = 0; v[j] = 0; p[j] = 0; way[j] = 0 end
    for i = 1, n do
      p[0] = i; local j0 = 0
      local minv, used = {}, {}
      for j = 0, n do minv[j] = INF; used[j] = false end
      repeat
        used[j0] = true
        local i0, delta, j1 = p[j0], INF, 0
        for j = 1, n do
          if not used[j] then
            local cur = C[i0][j] - u[i0] - v[j]
            if cur < minv[j] then minv[j] = cur; way[j] = j0 end
            if minv[j] < delta then delta = minv[j]; j1 = j end
          end
        end
        for j = 0, n do
          if used[j] then u[p[j]] = u[p[j]] + delta; v[j] = v[j] - delta else minv[j] = minv[j] - delta end
        end
        j0 = j1
      until p[j0] == 0
      repeat local j1 = way[j0]; p[j0] = p[j1]; j0 = j1 until j0 == 0
    end
    local r = {}
    for j = 1, n do r[p[j]] = j end
    return r
  end
  local UNM = 3000
  local function shrink(f, toB)        -- unmatched face: collapses to (or grows from) its centroid
    local P, Q = {}, {}
    for k, q in ipairs(f.p) do
      if toB then P[k] = q; Q[k] = f.cen else P[k] = f.cen; Q[k] = q end
    end
    return {ca = f.c, cb = f.c, P = P, Q = Q, na = f.nrm, nb = f.nrm, fade = toB and 1 or 2}
  end
  local function gen_pairs(ma, mb, kind)
    local A, B = fdesc(ma), fdesc(mb)
    local n = math.max(#A, #B)
    local C = {}
    for i = 1, n do
      C[i] = {}
      for j = 1, n do C[i][j] = (A[i] and B[j]) and math.min(cost(A[i], B[j], kind), UNM) or UNM end
    end
    local asg, prs = hungarian(C, n), {}
    for i = 1, n do
      local fa, fb = A[i], B[asg[i]]
      if fa and fb and #fa.p == #fb.p and C[i][asg[i]] < UNM then
        -- same corner count: best cyclic shift (centroid-relative, keeps the winding); shared corners stay shared
        local m, best, br = #fa.p, nil, 0
        for r = 0, m - 1 do
          local c = 0
          for k = 1, m do
            local a, b = fa.p[k], fb.p[(k - 1 + r) % m + 1]
            c = c + dist({a[1]-fa.cen[1], a[2]-fa.cen[2], a[3]-fa.cen[3]}, {b[1]-fb.cen[1], b[2]-fb.cen[2], b[3]-fb.cen[3]})
          end
          if not best or c < best then best, br = c, r end
        end
        local P, Q, key = {}, {}, {}
        for k = 1, m do
          local kb = (k - 1 + br) % m + 1
          P[k] = fa.p[k]; Q[k] = fb.p[kb]; key[k] = fa.idx[k] * 1024 + fb.idx[kb]
        end
        prs[#prs+1] = {ca = fa.c, cb = fb.c, P = P, Q = Q, na = fa.nrm, nb = fb.nrm, key = key}
      else
        if fa then prs[#prs+1] = shrink(fa, true) end
        if fb then prs[#prs+1] = shrink(fb, false) end
      end
    end
    return prs
  end

  -- build all pairs; GM.pairs[a][b] = face pairs for a -> b (b -> a uses the same list reversed in time)
  if GM.on then
    local ok, nslot = true, 0
    GM.orig, GM.cur, GM.key, GM.slot, GM.pairs, GM.seqof = {}, {}, {}, {}, {}, {}
    for _,s in ipairs(GM.SEQ) do
      local ms, sok = {}, true
      for _,id in ipairs(s.ids) do ms[id] = model(id); if not ms[id] then sok = false end end
      local links = {}
      for k = 1, #s.ids - 1 do links[#links+1] = {s.ids[k], s.ids[k+1]} end
      if s.loop then links[#links+1] = {s.ids[#s.ids], s.ids[1]} end
      if sok then
        for _,l in ipairs(links) do
          local a, b = l[1], l[2]
          local prs = (s.kind == "gate") and gate_pairs(ms[a], ms[b]) or gen_pairs(ms[a], ms[b], s.kind)
          if not prs then sok = false; break end
          GM.pairs[a] = GM.pairs[a] or {}; GM.pairs[a][b] = prs
        end
      end
      if sok then
        for _,id in ipairs(s.ids) do
          GM.orig[id] = rw(id); GM.cur[id] = GM.orig[id]; GM.slot[id] = nslot; GM.seqof[id] = s; nslot = nslot + 1
        end
        s.ok = true
      else
        s.ok = false
      end
    end
    for i = GM.BUF, GM.BUF + GM.SLOT * nslot - 1 do if rw(i) ~= 0 then ok = false; break end end
    if GM.BUF + GM.SLOT * nslot > 0x30000 then ok = false end
    GM.on = ok and nslot > 0
  end
end
do
  local names = {}
  for _,s in ipairs(GM.SEQ) do if GM.on and s.ok then names[#names+1] = s.name end end
  L("model morph " .. (GM.on and ("on: " .. table.concat(names, " ")) or "off (STUN60_MORPH=0 or unexpected ROM data)"))
end
-- pairs and fraction for a blend from model a to model b at f (b -> a = a -> b at 1 - f)
local function gm_pairs(a, b, f)
  if GM.pairs[a] and GM.pairs[a][b] then return GM.pairs[a][b], f end
  if GM.pairs[b] and GM.pairs[b][a] then return GM.pairs[b][a], 1 - f end
  return nil
end
-- write the blend a -> b at fraction f into the slot of id (word address returned, nil if it doesn't fit)
local function gm_write(id, a, b, f)
  local prs, g = gm_pairs(a, b, f)
  if not prs then return nil end
  local B = GM.BUF + GM.SLOT * GM.slot[id]
  local verts, faces, vkey = {}, {}, {}
  for _,pr in ipairs(prs) do
    local s = 1
    if pr.fade == 1 then s = 1 - g elseif pr.fade == 2 then s = g end
    if s >= 0.15 then
      local idx = {}
      for k = 1, #pr.P do
        local kk = pr.key and pr.key[k]
        if kk and vkey[kk] then idx[k] = vkey[kk]
        else
          local p, q = pr.P[k], pr.Q[k]
          verts[#verts+1] = {math.floor(p[1] + (q[1]-p[1])*g + 0.5), math.floor(p[2] + (q[2]-p[2])*g + 0.5),
                             math.floor(p[3] + (q[3]-p[3])*g + 0.5)}
          idx[k] = #verts
          if kk then vkey[kk] = #verts end
        end
      end
      local na, nb = pr.na, pr.nb
      local nx, ny, nz = na[1] + (nb[1]-na[1])*g, na[2] + (nb[2]-na[2])*g, na[3] + (nb[3]-na[3])*g
      local l = math.sqrt(nx*nx + ny*ny + nz*nz)
      if l < 1000 then nx, ny, nz, l = na[1], na[2], na[3], 16384 end
      local sc = 16384 / l
      faces[#faces+1] = {col = (g < 0.5) and pr.ca or pr.cb, idx = idx,
                         nrm = {math.floor(nx*sc + 0.5), math.floor(ny*sc + 0.5), math.floor(nz*sc + 0.5)}}
    end
  end
  local nv = #verts
  local n = nv + #faces
  local size = 4 + 3 * n + 2 * #faces + 2
  for _,fc in ipairs(faces) do size = size + #fc.idx + 2 end
  if size > GM.SLOT or #faces == 0 then return nil end
  local w = {n, nv, #faces}
  for _,v in ipairs(verts) do w[#w+1] = v[1] & 0xFFFF; w[#w+1] = v[2] & 0xFFFF; w[#w+1] = v[3] & 0xFFFF end
  for _,fc in ipairs(faces) do w[#w+1] = fc.nrm[1] & 0xFFFF; w[#w+1] = fc.nrm[2] & 0xFFFF; w[#w+1] = fc.nrm[3] & 0xFFFF end
  local L0 = B + #w + 1                                         -- face list right after its pointer
  w[#w+1] = L0 & 0xFFFF
  local F = L0 + 2 * #faces + 2
  for _,fc in ipairs(faces) do w[#w+1] = F & 0xFFFF; w[#w+1] = fc.col; F = F + #fc.idx + 2 end
  w[#w+1] = 0; w[#w+1] = 0
  for k, fc in ipairs(faces) do
    w[#w+1] = nv + k
    for _,i in ipairs(fc.idx) do w[#w+1] = i end
    w[#w+1] = 0xFFFF
  end
  for i, v in ipairs(w) do GM.R:write_u16((B + i - 1) * 2, v) end
  return B
end
-- point each managed id at the model for its state (map: id -> {a, b, f} = blend a -> b at f); others: original
local function gm_apply(map)
  if not GM.on then return end
  for id, orig in pairs(GM.orig) do
    local st, ptr = map and map[id], orig
    if st and st.f < 0.995 and st.a ~= st.b then
      if st.f < 0.005 then ptr = GM.orig[st.a] or orig
      else
        local key = st.a * 0x1000000 + st.b * 0x1000 + math.floor(st.f * 1000 + 0.5)
        if GM.key[id] == key then ptr = (GM.BUF + GM.SLOT * GM.slot[id]) // 4
        else
          local B = gm_write(id, st.a, st.b, st.f)
          if B then GM.key[id] = key; ptr = B // 4 else GM.key[id] = nil end
        end
      end
    end
    if GM.cur[id] ~= ptr then GM.R:write_u16(id * 2, ptr); GM.cur[id] = ptr end
  end
end
-- per 68010 object: previous and current model id, since which job, how long the previous stage lasted
local gm_track = {}
local function gm_on_job(J, jc)
  if not GM.on then return end
  for obj, id in pairs(J.ids or {}) do
    local t = gm_track[obj]
    if not t then gm_track[obj] = {id = id, since = jc, last = jc, d = 1}
    else
      if id ~= t.id then
        local link = gm_pairs(t.id, id, 0) ~= nil
        -- cadence = length of the stage that just ended, if it was itself an animation step (not a rest pose)
        t.d = math.max(1, math.min(t.prev and 8 or 2, jc - t.since))
        t.prev = link and t.id or nil
        if GM.log and (GM.orig[id] or GM.orig[t.id]) then
          L(string.format("morph %08X: %X -> %X after %d jobs%s", obj, t.id, id, jc - t.since, link and "" or " (no morph)"))
        end
        t.id, t.since = id, jc
      end
      t.last = jc
    end
  end
  local st = {}
  for obj, t in pairs(gm_track) do
    if jc - t.last > 50 then gm_track[obj] = nil
    elseif GM.orig[t.id] and jc - t.last <= 3 then
      local f = t.prev and math.min(1, (jc - t.since + 1) / t.d) or 1
      st[obj] = {id = t.id, a = t.prev or t.id, b = t.id, f = f}
    end
  end
  J.gph = st
end
-- state per id for a render between real jobs A and B at t (the ADSP job carries A's ids)
local function gm_map(A, B, t)
  if not (A and A.gph) then return nil end
  local map = {}
  for obj, a in pairs(A.gph) do
    local b = B and B.gph and B.gph[obj]
    local s = {a = a.a, b = a.b, f = a.f}
    if b then
      if b.a == a.a and b.b == a.b then s.f = a.f + (b.f - a.f) * t                  -- same stage
      elseif b.a == a.b and b.b ~= a.b then                                          -- B starts the next stage:
        local u = t * ((1 - a.f) + b.f)                                               -- finish A's blend, then B's
        if u <= 1 - a.f then s.f = a.f + u else s = {a = b.a, b = b.b, f = u - (1 - a.f)} end
      end
    end
    map[a.id] = s
  end
  return map
end

-- ---------------------------------------------------------------------------
-- recording the 68010's ADSP job uploads
local function on_ctl(o, d)
  if self_write then return end
  if o == 0x818006 or o == 0x818016 then
    bank = (o == 0x818016) and 1 or 0
    if DBG then L(string.format("68010 bank -> %d (pc %06X)", bank, MPC.value)) end
    recseq = (recseq or 0) + 1
    rec = {slot = recseq % 14}                  -- ADSP memory as it was before this job (custom MAME slot)
    CMD(1, rec.slot)
  elseif o == 0x81801A and rec and MPC.value ~= 0x02E464 and MPC.value ~= 0x02E414 then
    jobs[#jobs+1] = rec; jobcount = jobcount + 1
    gm_on_job(rec, jobcount); gm_apply(gm_map(rec, nil, 0))      -- the ADSP renders this job next: its gate phase
    rec = nil
    if DBG then L(string.format("68010 job %d uploaded (%d writes)", jobcount, #jobs[#jobs])) end
    if #jobs > 8 then table.remove(jobs, 1) end
  end
end
local function on_data(o, d)
  if self_write or not rec then return end
  local pc = MPC.value
  if pc == 0x02E22C or pc == 0x02E360 then rec.ids = rec.ids or {}; rec.ids[MA2.value] = d & 0xffff end   -- object model id
  if (POS[pc] or MAT[pc]) and not (o >= 0x80BFC8 and o <= 0x80BFFC) then
    rec[#rec+1] = {o, d & 0xffff, pc, MA2.value}     -- object field: remember which 68010 object
  else
    rec[#rec+1] = {o, d & 0xffff, pc}
  end
end

-- Interpolate a recorded job toward the next one. Camera words are matched by address;
-- object matrices/positions by 68010 object pointer and field order (ADSP slots can move).
local function obj_fields(J)
  local f = {}
  for _,w in ipairs(J) do
    if w[4] then
      local k = w[4]; f[k] = f[k] or {}
      local l = f[k]; l[#l+1] = w[2]
    end
  end
  return f
end
local function lerp_job(A, B, t)
  local bv = {}; for _,w in ipairs(B) do bv[w[1]] = w[2] end
  local bo = obj_fields(B)
  local cnt = {}
  local out, i = {}, 1
  while i <= #A do
    local o, d, pc, obj = A[i][1], A[i][2], A[i][3], A[i][4]
    local nx = A[i+1]
    if obj then
      local k = (cnt[obj] or 0) + 1
      local bl = bo[obj]
      if POS[pc] and nx and nx[4] == obj and nx[1] == o + 2 then
        if bl and bl[k] and bl[k+1] then
          local va, vb = s32((d << 16) | nx[2]), s32((bl[k] << 16) | bl[k+1])
          local v = math.floor(va + (vb - va) * t + 0.5) & 0xffffffff
          out[#out+1] = {o, v >> 16}; out[#out+1] = {o+2, v & 0xffff}
        else
          out[#out+1] = {o, d}; out[#out+1] = {o+2, nx[2]}
        end
        cnt[obj] = k + 1; i = i + 2
      else
        if MAT[pc] and bl and bl[k] then d = math.floor(s16(d) + (s16(bl[k]) - s16(d)) * t + 0.5) & 0xffff end
        out[#out+1] = {o, d}; cnt[obj] = k; i = i + 1
      end
    elseif POS[pc] and nx and nx[1] == o + 2 and bv[o] and bv[o+2] then      -- camera position
      local va, vb = s32((d << 16) | nx[2]), s32((bv[o] << 16) | bv[o+2])
      local v = math.floor(va + (vb - va) * t + 0.5) & 0xffffffff
      out[#out+1] = {o, v >> 16}; out[#out+1] = {o+2, v & 0xffff}; i = i + 2
    else
      if MAT[pc] and bv[o] then d = math.floor(s16(d) + (s16(bv[o]) - s16(d)) * t + 0.5) & 0xffff end  -- camera matrix
      out[#out+1] = {o, d}; i = i + 1
    end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- ADSP helpers
-- bulk work runs in the custom MAME build (stun60 helper commands, see harddriv.cpp s60_command)
function CMD(cmd, p0, p1, p2)
  W68(0x828020, p0 or 0); W68(0x828022, p1 or 0); W68(0x828024, p2 or 0)
  W68(0x828030, cmd)
  return ms:read_u16(0x828032)
end
local SNAP = 15                                   -- snapshot slot for the ADSP state of the current cycle
local job_running, job_done = false, false
-- Two stages: MAME applies the buffer-bank switch with a delay, so the ADSP must not
-- run (and write output) until the switch has really happened.
local function start_job_1()
  W68(0x81800A, 0); W68(0x818008, 0)                     -- halt ADSP (/BR)
  W68(0x828000, bank ~ 1)       -- (custom MAME: immediate) the ADSP will write the already-copied bank
end
local function start_job_2(words)
  job_running, job_done = true, false
  self_write = true
  for _,w in ipairs(words) do ms:write_u16(w[1], w[2]) end   -- includes the $80BFFE job trigger
  self_write = false
  W68(0x818018, 0); W68(0x81801A, 0)                     -- release
end
-- ---------------------------------------------------------------------------
-- Blit glide: 2D picture animations (display-list op 8 blits) that the game moves in steps every few ticks, such as the
-- pilot walking to his craft at the start (7-10 pixels every second tick), glide at 60 fps instead. Each real list's
-- blits are matched to tracks (same y, nearest x); when a track's x changes, it glides from where it is shown now to the
-- new x over as many real lists as the previous step lasted (a first step after a rest: 2), real lists and extras alike.
-- Only pictures up to 256 pixels wide, and only steps of 2+ ticks (anything moving every tick keeps the game's x).
-- Display only (the game's x is patched in the GSP list); the pictures themselves still change at the game's rate.
-- Env STUN60_GLIDE=0 off, STUN60_GLIDELOG=1 logs each step.
local BG = {on = os.getenv("STUN60_GLIDE") ~= "0", log = os.getenv("STUN60_GLIDELOG") == "1", tracks = {}, n = 0, k = 0}
-- op 8 commands in nwords words from a: 8000, x, y, flags, image address (hi, lo); image = height, width, ...
local function scan_blits(a, nwords, rel)
  local out = {}
  for i = 0, nwords - 6 do
    local ad = a + 16 * i
    if gsp:read_u16(ad) == 0x8000 then
      local y, hi = gsp:read_u16(ad + 32), gsp:read_u16(ad + 64)
      if y < 0x118 and hi >= 0xFF80 then
        local img = (hi << 16) | gsp:read_u16(ad + 80)
        local h, w = gsp:read_u16(img), gsp:read_u16(img + 16)
        if h >= 1 and h <= 512 and w >= 1 and w <= 1024 then
          out[#out+1] = {rel = rel, off = i + 1, x = s16(gsp:read_u16(ad + 16)), y = y, w = w}
        end
      end
    end
  end
  return out
end
local function glide_pos(t, n, tf)
  local f = math.min(1, (n - t.since + tf) / t.d)
  return t.from + (t.x - t.from) * f
end
-- a real list was published: match its blits to tracks (returns the list's number)
local function glide_update(blits)
  BG.n = BG.n + 1
  local n, used = BG.n, {}
  for _,b in ipairs(blits) do
   if b.w <= 256 then                       -- small pictures only (never the 512-wide skyline halves)
    local best, bd
    for id, t in pairs(BG.tracks) do
      if not used[id] and t.y == b.y and n - t.last <= 8 then
        local dd = math.abs(t.x - b.x)
        if dd <= 24 and (not bd or dd < bd) then best, bd = id, dd end
      end
    end
    local t = best and BG.tracks[best]
    if not t then
      BG.k = BG.k + 1; best = BG.k
      t = {y = b.y, x = b.x, from = b.x, since = n, d = 2, moving = false}
      BG.tracks[best] = t
    elseif b.x ~= t.x then
      local cur = glide_pos(t, n, 0)
      t.d = math.max(1, math.min(t.moving and 8 or 2, n - t.since))
      t.moving = true
      if t.d < 2 then cur = b.x end          -- moves every tick: keep the game's position (no lag)
      if BG.log then L(string.format("glide y %d w %d: x %d -> %d over %d lists%s", b.y, b.w, t.x, b.x, t.d, t.d < 2 and " (no glide)" or "")) end
      t.from, t.x, t.since = cur, b.x, n
    elseif n - t.since > 8 then
      t.moving = false
    end
    t.last = n; used[best] = true; b.track = t
   end
  end
  for id, t in pairs(BG.tracks) do if n - t.last > 30 then BG.tracks[id] = nil end end
  return n
end
-- write the glide x of each blit (tf = fraction of a tick after real list n); tail = where the tail starts in this list
local function glide_patch(blits, n, tf, tail)
  for _,b in ipairs(blits) do
    local t = b.track
    if t then
      local x = math.floor(glide_pos(t, n, tf) + 0.5)
      local a = (b.rel == "tail") and (tail + 16 * b.off) or b.off
      if x ~= b.x or tf > 0 then WG(a, x & 0xffff) end
    end
  end
end

-- ---------------------------------------------------------------------------
-- GSP list handling
local function find_block(mb, d2)
  if not d2 or d2 < 2 or d2 > 0x1FFE then return nil end
  local a = mb + 0x10
  for k = 0, 800 do
    local p = a + 16*k
    if gsp:read_u16(p) == 0x7000 and gsp:read_u16(p + 16*d2) == 0xFFFF then return p end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- cycle control (v3: vblank-locked schedule)
--
-- GSP: polls a mailbox; once a list is raised (FFFF) it draws it, flips at the next vblank,
-- then clears the mailbox (list on screen, buffer free), raises the game tick, waits for the cap
-- (refreshes since the previous draw start) and starts the next draw.
-- 68010 loop: tick -> publish real list R(k) -> logic -> wait ADSP done -> bank toggle ->
-- upload next job -> copy finished output into the other GSP buffer -> wait tick.
-- One cycle per real list. When R(k) is published, both jobs we interpolate between are
-- already uploaded (jobs[n-1] made R(k), jobs[n] makes R(k+1)). We hold jobs[n]'s done flag so
-- the 68010 can't start its next job, use the ADSP for the 2 extras, then release it.
-- R(k) starts drawing after vblank B; extra j is raised after vblank B+j; every GSP tick is
-- held and the game gets exactly one, at vblank B+3, so R(k+1) starts drawing at B+3:
-- the original 3-refresh rhythm, with or without extras.
local pending = nil          -- held real "done" flag: {jc = jobcount, t = time}
local last_cycle, last_end = nil, -1e9
local last_vbl = 0           -- time of the latest vblank
local gsp_polling = false    -- the GSP passed its cap wait and is waiting for a raised list
local gd = 0.6               -- GSP draw time estimate (refreshes)
local jd = 0.9               -- extra ADSP job time estimate (refreshes)
local skipped_cycles = 0     -- cycles in a row where all extras were skipped for lack of ADSP time
local adsp_skips = 0         -- extras skipped for lack of ADSP time this second (drives the "too slow" warning)
local draw_t0 = nil          -- when the GSP started drawing one of our extras

local in_done_tap, release_by_return = false, false
local function release_done()
  if not pending then return end
  pending = nil
  if in_done_tap then release_by_return = true      -- the done tap returns 1 instead (a write here would be overwritten)
  else W68(0xFF9BB4, 1) end
end
local function release_tick(c)
  -- exactly one tick per cycle (all GSP ticks are held while interpolating)
  c.tick_owed = false; W68(0xFFDB48, 0xFFFF); st.ticks = st.ticks + 1
end
local function end_cycle(c, why)
  if c.ended then return end
  c.ended = true
  st.cyc = st.cyc + 1
  if c.skipped then skipped_cycles = skipped_cycles + 1 end
  if c.owns_done then
    c.owns_done = false
    if c.snap then CMD(2, SNAP) end
    if c.bank_moved then c.bank_moved = false; W68(0x828000, bank) end
    release_done()
  end
  release_tick(c)
  last_cycle, last_end = c, now()
  local missed = 0
  for k = 1, #TS do if c.slot[k] ~= "shown" and c.slot[k] ~= "raised" then missed = missed + 1 end end
  st.drop = st.drop + missed
  if why or DBG then
    L(string.format("cycle end%s: extras %d missed %d age %.2f", why and (" ("..why..")") or "", #TS - missed, missed, now() - c.t0))
  end
  if cycle == c then cycle = nil end
end

local function deadline(c, k)       -- last moment to raise extra k so it is drawn before vblank B+k+1
  return (c.vb or c.t0) + k + 1 - gd - 0.05
end

local function try_publish(c)
  if not c.vb or c.ended then return end
  local t = now()
  for k = 1, #TS do
    local sk = c.slot[k]
    if not sk then
      if not RELAX and t > deadline(c, k) then
        c.slot[k] = "missed"; L(string.format("extra %d missed (rendered %s, buffer %04X)", k, tostring(c.outs[k] ~= nil), gsp:read_u16(c.mb)))
      else
        local o = c.outs[k]
        if o == nil then return end              -- not rendered yet: wait (keep order)
        if o == false then c.slot[k] = "missed"; L("extra "..k.." bad output")
        else
          local ok_time
          if RELAX then ok_time = (k == 1) or c.slot[k-1] ~= "raised"
          else ok_time = last_vbl >= c.vb + k - 0.01 end
          if ok_time and gsp:read_u16(c.mb) == 0 then          -- buffer free (previous list on screen)
            local nb = CMD(5, k, c.p >> 16, c.p & 0xffff)
            if c.blits and nb and nb > 0 then glide_patch(c.blits, c.gn, TS[k], c.p + 16 * (nb + 1)) end
            WG(c.mb, 0xFFFF); c.slot[k] = "raised"; st.extra = st.extra + 1
            if gsp_polling then gsp_polling = false; draw_t0 = t end
            if DBG then L(string.format("raised extra %d at B+%.2f", k, t - c.vb)) end
          end
          return
        end
      end
    end
  end
end

local function check_end(c)
  if c.ended or not c.vb then return end
  if c.state == "job" then return end              -- let our ADSP job finish
  if RELAX then
    local last = c.slot[#TS]
    if last == "shown" or (c.state == "wait_end" and last == "missed") then end_cycle(c) end
  elseif last_vbl >= c.vb + 3 - 0.01 then
    end_cycle(c)
  end
end

local function step(c)
  local t = now()
  for _ = 1, 8 do
    if c.ended then return end
    local s0 = c.state
    if s0 == "wait_done" then
      if pending and pending.jc == jobcount and jobcount == c.nj0 then
        if #jobs < 2 then c.state = "wait_end"
        else
          c.owns_done = true
          c.A, c.Bj = jobs[#jobs-1], jobs[#jobs]
          CMD(1, SNAP); c.snap = true; c.idx = 1; c.state = "start_job"
        end
      elseif t > DL(c.t0 + 2.0) or jobcount ~= c.nj0 then
        c.state = "wait_end"; L("no ADSP time this cycle (overclock adsp)")
      end
    elseif s0 == "start_job" then
      local tt = c.tlist[c.idx]
      if not tt then c.state = "release"
      else
        local k = c.kof[c.idx]
        -- the job-time estimate only learns from jobs we run, so after ~5 s of skipping try one anyway
        -- (in case the adsp clock was raised meanwhile)
        local probe = k == #TS and skipped_cycles >= 100
        -- spread the host cost: extra 2+ is only shown after vblank B+k, so when there is time, start it
        -- after the next vblank instead of right behind the previous job (else one emulated frame
        -- carries the real job + both extras = ~3x a stock frame's host time -> late frames, choppy sound)
        local spread = SPREAD and k and k >= 2 and not RELAX and c.tprev and last_vbl < c.tprev
                       and last_vbl + 1 + jd <= deadline(c, k)
        if spread then
          -- wait: the vblank tap runs step again
        elseif k and not RELAX and not probe and t + jd > deadline(c, k) then
          c.outs[k] = false; c.idx = c.idx + 1; c.progress = true
          c.skipped = true      -- can't be ready in time: skip it
          adsp_skips = adsp_skips + 1
          L(string.format("skip extra %d (adsp)", k))
        else
          -- halt the ADSP, point the 68k at the other bank (the ADSP then writes the bank the 68010
          -- already copied; MAME applies this at the next sync, before the ADSP runs again),
          -- restore the ADSP state from before job A, upload the lerped job, release
          start_job_1()
          CMD(2, c.A.slot)
          gm_apply(gm_map(c.A, c.Bj, c.tlist[c.idx]))
          start_job_2(lerp_job(c.A, c.Bj, c.tlist[c.idx]))
          c.bank_moved = true
          skipped_cycles = 0
          c.tjob = t; c.tprev = t; c.state = "job"
        end
      end
    elseif s0 == "job" then
      if job_done then
        job_running = false
        jd = math.max(jd * 0.9, t - c.tjob + 0.03)
        c.state = "read"
      elseif t > c.tjob + 12 then                     -- safety net
        job_running = false
        L("extra ADSP job never finished")
        c.outs[c.kof[c.idx] or 0] = false
        c.idx = #c.tlist + 1; c.state = "start_job"
      end
    elseif s0 == "read" then
      do
        local k = c.kof[c.idx]
        local n = CMD(3, bank, k or 3)                 -- the ADSP wrote bank (68k bank is bank^1)
        if not k then
          local same = n > 0 and CMD(6, 3, c.p >> 16, c.p & 0xffff) or 0
          L(string.format("verify t=0: %d of %d words match the real list (%d)", same, n, c.d2))
        else
          c.outs[k] = n > 0 and n or false
        end
        c.idx = c.idx + 1; c.state = "start_job"
      end
    elseif s0 == "release" and SPREAD2 and not RELAX and c.vb and last_vbl < c.vb + 2 - 0.01 then
      -- wait: let the 68010's next real ADSP job run in the third refresh (one job per frame)
    elseif s0 == "release" then
      CMD(2, SNAP)
      if c.bank_moved then c.bank_moved = false; W68(0x828000, bank) end  -- 68k bank back
      c.owns_done = false; release_done()          -- the 68010 may now start its next ADSP job
      c.state = "wait_end"
    end
    try_publish(c)
    check_end(c)
    if c.state == s0 and not c.progress then return end
    c.progress = false
    if DBG then L("state "..s0.." -> "..c.state) end
  end
end

-- emergency exit: put the ADSP/bank back as the 68010 left them
local function abort_cycle(c, why)
  if c.ended then return end
  L(string.format("ABORT in state %s: %s", tostring(c.state), why))
  pcall(function()
    if c.bank_moved then c.bank_moved = false; W68(0x828000, bank) end
  end)
  job_running = false
  c.state = "aborted"
  end_cycle(c, "abort: " .. why)
end
local errcount = 0
local function safe_step(c)
  local ok, e = pcall(step, c)
  if not ok then
    errcount = errcount + 1
    L("LUA ERROR in step (state " .. tostring(c.state) .. "): " .. tostring(e))
    abort_cycle(c, "lua error")
  elseif not c.ended and now() - c.t0 > 45 then
    abort_cycle(c, "watchdog (cycle older than 45 refreshes)")
  end
end

local pumpn = 0
local cpu_time = 0
local in_tap = false         -- our own reads inside a write tap must not run the state machine
local function pump()
  local c = cycle
  if not c or in_tap then return end
  pumpn = pumpn + 1
  if pumpn % 16 ~= 0 then return end
  local t0 = os.clock()
  safe_step(c)
  cpu_time = cpu_time + os.clock() - t0
end

-- mailbox writes: the 68010 publishes a real list (FFFF), the GSP clears one it has put on screen (0)
local function on_mailbox(o, d)
  if o ~= 0xFFF9FC00 and o ~= 0xFFFCFC00 then return end
  d = d & 0xffff
  if d == 0 then
    local c = cycle
    if c and o == c.mb and not c.ended then
      for k = 1, #TS do if c.slot[k] == "raised" then c.slot[k] = "shown"; break end end
      -- (no step here: a write to this mailbox from inside its own tap would be overwritten)
    end
    return
  end
  if self_write or d ~= 0xFFFF then return end
  local drawing_now = gsp_polling
  gsp_polling = false
  if cycle then end_cycle(cycle, "superseded") end
  local d2 = ms:read_u16(0xFFDB4E)
  local p = find_block(o, d2)
  if not p then
    cap_target = 3
    if now() - (nofind_t or -1e9) > 20 then        -- (at most one line per 20 refreshes)
      nofind_t = now()
      local a, first7, seen = o + 0x10, nil, {}
      for k = 0, 4000 do
        local w = gsp:read_u16(a + 16*k)
        if w == 0x7000 and not first7 then first7 = k end
        if k < 12 then seen[#seen+1] = string.format("%04X", w) end
      end
      L(string.format("no 3D block: mb %X d2 %d first 7000 at word %s, end word %s, head %s", o, d2, tostring(first7),
        first7 and string.format("%04X", gsp:read_u16(a + 16*(first7 + d2))) or "-", table.concat(seen, " ")))
    end
    return
  end
  local q = p + 16*(d2 + 1)
  local blits, gn
  if BG.on then
    -- blits in the list head (before the 3D block; absolute addresses) and in the tail (offsets from its start)
    local head = o + 0x10
    blits = {}
    for _,b in ipairs(scan_blits(head, (p - head) // 16, "head")) do b.off = head + 16 * (b.off - 1) + 16; blits[#blits+1] = b end
    for _,b in ipairs(scan_blits(q, 700, "tail")) do blits[#blits+1] = b end
    gn = glide_update(blits)
    glide_patch(blits, gn, 0, q)                    -- the real list shows the glide position too
  end
  CMD(4, q >> 16, q & 0xffff, 700)                  -- capture the HUD tail after the 3D block
  local tl, kof = {}, {}
  if VERIFY then tl[#tl+1] = 0 end
  for k, t in ipairs(TS) do tl[#tl+1] = t; kof[#tl] = k end
  local c = {mb = o, p = p, d2 = d2, t0 = now(), slot = {}, blits = blits, gn = gn,
             tick_owed = false, owns_done = false,
             state = "wait_done", outs = {}, tlist = tl, kof = kof, nj0 = jobcount}
  if drawing_now then c.vb = last_vbl end           -- the GSP was waiting: it starts on R(k) right now
  cycle = c; cap_target = 1
  if DBG then L(string.format("new cycle mb %X d2 %d jobs %d pending %s B %s", o, d2, jobcount, tostring(pending ~= nil), c.vb and string.format("%.2f", c.vb) or "later")) end
  safe_step(c)          -- (no mailbox writes can happen here: the buffer is busy until R(k) is on screen)
end

-- GSP passed its cap wait (frame counter cleared): it draws a raised list now, or polls for one
local function on_counter_clear()
  local c = cycle
  local a, b = gsp:read_u16(0xFFF9FC00), gsp:read_u16(0xFFFCFC00)
  if a == 0xFFFF or b == 0xFFFF then
    gsp_polling = false
    if c and not c.vb and gsp:read_u16(c.mb) == 0xFFFF and not c.slot[1] then c.vb = last_vbl end
    if c and c.slot[1] then draw_t0 = now() end
  else
    gsp_polling = true
    if c and not c.ended then safe_step(c) end   -- buffer just freed: raise a ready extra right now
  end
end

-- ADSP "job done" flag
local function on_done(o, d)
  if self_write or (d & 0xffff) ~= 1 then return end
  if job_running then                                           -- our extra job finished
    job_done = true
    local c = cycle
    if c and not c.ended then
      in_done_tap, release_by_return = true, false
      safe_step(c)
      in_done_tap = false
      if release_by_return then release_by_return = false; return 1 end   -- extras done: release the 68010
    end
    return 0
  end
  local c = cycle
  local hold = false
  if c and not c.ended then
    hold = (jobcount > c.nj0) or (c.state == "wait_done" and jobcount == c.nj0)
  elseif last_cycle and now() - last_end < 0.5 then
    hold = jobcount > last_cycle.nj0
  end
  if hold then
    pending = {jc = jobcount, t = now()}
    if DBG then L("holding ADSP done of job "..jobcount) end
    if c and not c.ended then
      in_done_tap, release_by_return = true, false
      safe_step(c)                                  -- starts our first extra job right away
      in_done_tap = false
      if release_by_return then release_by_return = false; return 1 end   -- nothing to do: don't hold
    end
    return 0
  end
end

-- game tick (raised by the GSP after each list goes on screen). While interpolating, all of
-- them are held; the game gets one per cycle from end_cycle.
local function on_tick(o, d)
  if self_write or (d & 0xffff) ~= 0xFFFF then return end
  local c = cycle
  -- (suppress by keeping the current value: it may still hold our own unread tick)
  if (c and not c.ended) or (last_cycle and now() - last_end < 0.5) then
    if c and not c.ended then c.tick_owed = true end
    in_tap = true; local v = ms:read_u16(0xFFDB48); in_tap = false
    return v
  end
  st.ticks = st.ticks + 1
end

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- overlay: O cycles full / small / off (remembered); warning when the clocks are too low
local OVF = DATA and (DATA .. "/stun60-overlay.txt") or (HOMED .. "/.mame/stun60-overlay.txt")
local ovmode = "small"
do local f = io.open(OVF, "r"); if f then local v = f:read("l"); f:close()
  if v == "full" or v == "small" or v == "off" then ovmode = v end end end
local inp = mach.input
local key_o = inp:code_from_token("KEYCODE_O")
local key_was = false
-- C cycles the screen effect (BGFX chain): CRT deluxe -> CRT sharp -> off. Needs the custom build's ui:stun60_slider and
-- -video bgfx. MAME saves the chosen chain in cfg/stunrun.cfg (same as Tab > Slider Controls > "Window 0, Screen 0 Effect").
local key_c = inp:code_from_token("KEYCODE_C")
local keyc_was = false
local CRT_SLIDER = "Window 0, Screen 0 Effect"
-- H toggles the HD redraw (custom build started with STUN60_HD: a second screen with the 3D scene redrawn at
-- 3x5 the resolution); the choice is remembered. The overlay is drawn on whichever screen is in view.
local HDF = DATA and (DATA .. "/stun60-hd.txt") or (HOMED .. "/.mame/stun60-hd.txt")
local hdscr = mach.screens[":mainpcb:hdscreen"]
local key_h = inp:code_from_token("KEYCODE_H")
local keyh_was = false
local hd_on = hdscr ~= nil
do local f = io.open(HDF, "r"); if f then local v = f:read("l"); f:close(); if v == "off" then hd_on = false end end end
local hd_sx, hd_sy = 3, 5
do local a, b = (os.getenv("STUN60_HD") or ""):match("^(%d+)x(%d+)$"); if a then hd_sx, hd_sy = tonumber(a), tonumber(b) end end
local dscr, kx, ky = scr, 1, 1   -- screen the overlay is drawn on, and the scale from 512x240 coordinates
local hd_applied = nil
local function apply_hd()
  if not hdscr then return end
  local t = mach.render.ui_target
  local want = hd_on and "Screen 1 Standard (4:3)" or "Screen 0 Standard (4:3)"
  if t then for i, n in ipairs(t.view_names) do if n == want then t.view_index = i end end end
  if hd_on then dscr, kx, ky = hdscr, hd_sx, hd_sy else dscr, kx, ky = scr, 1, 1 end
  hd_applied = hd_on
end
local function dbox(x1, y1, x2, y2, f, l) dscr:draw_box(x1 * kx, y1 * ky, x2 * kx, y2 * ky, f, l) end
local function dtext(x, y, t, c) dscr:draw_text(x == "center" and "center" or x * kx, y * ky, t, c) end
local CRT_ORDER = { {"crt-geom-deluxe", "CRT scanlines (deluxe)"}, {"crt-geom", "CRT scanlines (sharp)"}, {"default", "No screen effect"} }
local crt_idx = nil          -- chain name -> slider value, filled on first use
local crt_msg, crt_msg_until = nil, 0
local function crt_slider(v)
  local ui = manager.ui
  if not (ui and ui.stun60_slider) then return nil end
  local ok, cur, txt, mn, mx = pcall(ui.stun60_slider, ui, CRT_SLIDER, v)
  if ok then return cur, txt, mn, mx end
  L("crt: stun60_slider error " .. tostring(cur)); return nil
end
local function crt_cycle()
  local cur, txt, mn, mx = crt_slider()
  if not cur then crt_msg = "Screen effects need the BGFX video mode"; crt_msg_until = mach.time:as_double() + 2.5; return end
  if not crt_idx then          -- find the slider values of our chains (each probe reloads the chain once)
    crt_idx = { default = 1 }; local want = 2
    for v = 2, mx do
      local _, t = crt_slider(v)
      if t == "crt-geom-deluxe" or t == "crt-geom" then crt_idx[t] = v; want = want - 1 end
      if want == 0 then break end
    end
    L("crt: chain values deluxe=" .. tostring(crt_idx["crt-geom-deluxe"]) .. " geom=" .. tostring(crt_idx["crt-geom"]))
  end
  local pos = 0
  for i, e in ipairs(CRT_ORDER) do if e[1] == txt then pos = i end end
  for step = 1, #CRT_ORDER do
    local e = CRT_ORDER[(pos + step - 1) % #CRT_ORDER + 1]
    if crt_idx[e[1]] then
      local _, t = crt_slider(crt_idx[e[1]])
      crt_msg = (t == e[1]) and e[2] or ("Screen effect: " .. tostring(t)); crt_msg_until = mach.time:as_double() + 2.5
      L("crt: switched to " .. tostring(t)); return
    end
  end
end
STUN60_CRT_CYCLE = crt_cycle  -- for headless/scripted tests
local function hd_toggle()
  if hdscr then
    hd_on = not hd_on
    local f = io.open(HDF, "w"); if f then f:write(hd_on and "on" or "off", "\n"); f:close() end
    crt_msg = hd_on and "HD redraw on" or "Original resolution"
  else
    crt_msg = "HD redraw not enabled (STUN60_HD)"
  end
  crt_msg_until = mach.time:as_double() + 2.5
  L("hd: " .. tostring(hd_on))
end
STUN60_HD_TOGGLE = hd_toggle   -- for headless/scripted tests
local low_secs = 0           -- seconds of gameplay in a row with few in-between frames
local function overlay_second()  -- called once per second, after the counters are latched
  -- only ADSP-time skips count: screens that are slow for the GSP (e.g. the attract-mode story panel,
  -- ~2.1 refreshes per list at gsp x4) also drop extras, but no clock setting fixes those and they are static
  local cyc, ex, sk = tonumber(shown.cyc) or 0, tonumber(shown.extra) or 0, adsp_skips
  adsp_skips = 0
  if cyc >= 12 and ex < 10 and sk >= 10 then low_secs = low_secs + 1
  elseif ex >= 20 or cyc < 5 then low_secs = 0 end
  if low_secs == 3 then L("warning shown: overclock too low") end
end
function draw_overlay()
  local k = inp:code_pressed(key_o)
  if k and not key_was then
    ovmode = (ovmode == "full" and "small") or (ovmode == "small" and "off") or "full"
    local f = io.open(OVF, "w"); if f then f:write(ovmode, "\n"); f:close() end
  end
  key_was = k
  local kc = inp:code_pressed(key_c)
  if kc and not keyc_was then crt_cycle() end
  keyc_was = kc
  local kh = inp:code_pressed(key_h)
  if kh and not keyh_was then hd_toggle() end
  keyh_was = kh
  if hd_applied ~= hd_on then apply_hd() end
  if crt_msg and mach.time:as_double() < crt_msg_until then
    dbox(156, 4, 356, 18, 0xff000000, 0xff000000)   -- solid black box, top centre
    dtext("center", 6, crt_msg, 0xffffffff)
  end
  if ovmode == "full" then
    dbox(2, 2, 150, 24, 0xc0000000, 0xffffff00)
    dtext(5, 3, "Drawn FPS: " .. shown.gspf .. "  ticks: " .. shown.ticks, 0xff000000)
    dtext(5, 13, "interp: " .. shown.extra .. "  dropped: " .. shown.drop ..
      (errcount > 0 and ("  ERR " .. errcount) or ""), 0xff000000)
  elseif ovmode == "small" then
    local txt = shown.gspf .. (errcount > 0 and " ERR" or "")
    dbox(2, 2, 22, 11, 0x80000000, 0x80000000)
    dtext(4, 2, txt, 0xffffff00)
  end
  if low_secs >= 3 then
    dbox(56, 30, 456, 64, 0xe0000000, 0xffff4040)
    dtext("center", 34, "Emulated ADSP too slow for 60 fps", 0xffff8080)
    dtext("center", 46, "Raise adsp in STUN60_CLOCK (default maincpu=3,gsp=4,adsp=8)", 0xffffffff)
  end
end

-- The 68010 wait loops give up (and restart the game) after a fixed number of polls.
-- While we are the reason it waits, keep its loop counter (D5) fresh (checked every vblank/frame).
function refresh_68k_waits()
  if not (cycle or pending) then return end
  local pc = MPC.value
  if pc >= 0x02FC7C and pc <= 0x02FCB6 then MD5.value = 0x80000
  elseif pc >= 0x02C3AC and pc <= 0x02C3DA then MD5.value = 0 end
end

local installed, nfr = false, 0
STUN60_RESET_SUB = emu.add_machine_reset_notifier(function()
  cycle = nil; job_running = false; job_done = false; rec = nil; jobs = {}; cap_target = 3
  pending = nil; gsp_polling = false
  gm_track = {}; gm_apply(nil)
  L("machine reset")
end)
-- host timing: wall time per emulated second, longest gap between frames, frames > 25 ms apart
local tps = emu.osd_ticks_per_second()
local w_prev, w_sec, w_max, w_late = nil, nil, 0, 0
emu.register_frame_done(function()
  nfr = nfr + 1
  do
    local w = emu.osd_ticks()
    if w_prev then
      local dt = (w - w_prev) / tps
      if dt > w_max then w_max = dt end
      if dt > 0.025 then w_late = w_late + 1 end
    end
    w_prev = w
    if not w_sec then w_sec = w end
  end
  if not installed and mach.time:as_double() > 5 then
    -- (68010 RAM taps installed early get dropped by a memory remap at boot)
    installed = true
    tap_ctl  = ms:install_write_tap(0x818000, 0x81807F, "s60ctl", on_ctl)
    tap_dat  = ms:install_write_tap(0x808000, 0x80BFFF, "s60dat", on_data)
    tap_done = ms:install_write_tap(0xFF9BB4, 0xFF9BB5, "s60done", on_done)
    tap_tick = ms:install_write_tap(0xFFDB48, 0xFFDB49, "s60tick", on_tick)
    tap_mba  = gsp:install_write_tap(0xFFF9FC00, 0xFFF9FC0F, "s60mba", on_mailbox)
    tap_mbb  = gsp:install_write_tap(0xFFFCFC00, 0xFFFCFC0F, "s60mbb", on_mailbox)
    pump_a   = gsp:install_read_tap(0xFFF9FC00, 0xFFF9FC0F, "s60pa", function() pump() end)
    pump_b   = gsp:install_read_tap(0xFFFCFC00, 0xFFFCFC0F, "s60pb", function() pump() end)
    -- GSP frame counter: +1 at each vblank, cleared when the GSP passes its cap wait
    tap_vbl  = gsp:install_write_tap(0xFFF716A0, 0xFFF716AF, "s60vbl", function(o, d)
      if (d & 0xff) ~= 0 then
        last_vbl = now()
        refresh_68k_waits()
        if cycle then safe_step(cycle) end
      else
        on_counter_clear()
      end end)
    -- the GSP finished drawing a list (flip request, cleared at the flip)
    tap_drawn = gsp:install_write_tap(0xFFF71680, 0xFFF7168F, "s60drawn", function(o, d)
      if (d & 0xffff) ~= 0 and draw_t0 then
        gd = math.min(0.9, math.max(0.3, gd * 0.8 + (now() - draw_t0) * 0.2)); draw_t0 = nil
      end end)

    -- (no read taps on the 68010's polled flags: at 4x clock they fire millions of times a second)
    tap_fps  = gsp:install_write_tap(0xFFF716B0, 0xFFF716BF, "s60fps", function() st.gspf = st.gspf + 1 end)
  end
  -- never leave the 68010 waiting on a held done flag without a cycle that will use it
  if pending and (not cycle or cycle.ended) and now() - pending.t > 1.5 then
    L("released a stale ADSP done"); release_done()
  end
  if not cycle and now() - last_end > 1.0 then cap_target = 3 end
  if installed then gsp:write_u16(0xFFF77E80, cap_target) end
  refresh_68k_waits()
  if cycle then safe_step(cycle) end
  if nfr % 60 == 0 then
    for k,v in pairs(st) do shown[k] = tostring(v); st[k] = 0 end
    L(string.format("per second: drawn %s, extra %s, ticks %s, dropped %s, cycles %s, gd %.2f jd %.2f, lua ms %.1f",
      shown.gspf, shown.extra, shown.ticks, shown.drop, shown.cyc, gd, jd, cpu_time*1000)
      .. string.format(", wall %.3f s, max gap %.0f ms, late %d", (emu.osd_ticks() - w_sec) / tps, w_max * 1000, w_late))
    w_sec = emu.osd_ticks(); w_max = 0; w_late = 0
    cpu_time = 0
    overlay_second()
  end
  draw_overlay()
end)
