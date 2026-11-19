-- wireframe probe: per drawn list, count display-list opcodes and the op-7 polygon flag classes
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local S = gspd.state
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local sy = F(":mainpcb:8BADC.2","AD Stick Y")
local AY = tonumber(os.getenv("AY") or "128")
local last13, snapped = -1, 0
local mcs = manager.machine.devices[":mainpcb:maincpu"].spaces["program"]
local LEV = tonumber(os.getenv("LEV") or "-1")
local END = tonumber(os.getenv("END") or "4000")
local SNAPS = {}
for s in (os.getenv("SNAPS") or ""):gmatch("%d+") do SNAPS[tonumber(s)] = true end
local out = io.open(os.getenv("HOME").."/mame/scripts/re-probes/wf/out/wf" .. (os.getenv("TAG") or "") .. ".txt","w")
local FORCE = tonumber(os.getenv("FORCE") or "0")
local frame, ops, oparg = 0, {}, {}
if FORCE ~= 0 then tf = gsp:install_write_tap(0xFFF77E60, 0xFFF77E6F, "force", function(o, d, m) if frame and frame >= 1300 then return d | FORCE end end) end
local w = function(a) return gsp:read_u16(a) end
tj = gsp:install_read_tap(0xFFF470E0, 0xFFF472DF, "jt", function(o, d, m)
  if o % 32 ~= 0 then return end
  local a4 = S["A4"].value & 0xffff; local op = a4 >> 12
  if (o - 0xFFF470E0) // 32 ~= op then return end
  ops[op] = (ops[op] or 0) + 1
  if op == 2 or op == 3 or op == 1 or op == 6 or op == 0xA or op == 0xB or op == 0xC or op == 0xE then
    local a5 = S["A5"].value; local t = {}
    for i = 0, 5 do t[#t+1] = string.format("%04X", w(a5 + 16*i)) end
    oparg[#oparg+1] = string.format("op%X:%04X[%s]", op, a4, table.concat(t, " "))
  end
end)
local function polys()
  local ptr = w(0xFFF77F30) | (w(0xFFF77F40) << 16)
  local h = {}
  for k = 0, 1199 do
    local p = ptr + 16*k
    if w(p) == 0x7000 then
      local base = p + 16; local cnt = w(base)
      if cnt >= 2 and cnt <= 0x2000 then
        local a3 = base + cnt*16
        for i = 0, 2047 do
          local off = w(a3 + 16*i)
          if off & 0x8000 ~= 0 or off == 0 or off >= cnt then break end
          local f = w(base + off*16) & 0xFC00
          h[f] = (h[f] or 0) + 1
        end
        break
      end
    end
  end
  local t = {}
  for f, n in pairs(h) do t[#t+1] = string.format("%04X:%d", f, n) end
  table.sort(t); return table.concat(t, " ")
end
tw = gsp:install_write_tap(0xFFF71680, 0xFFF7168F, "dd", function(o, d, m)
  if d == 0 then return end
  local t = {}
  for op = 0, 15 do if ops[op] then t[#t+1] = string.format("%X:%d", op, ops[op]) end end
  local g = w(0xFFF77E60)
  if g ~= last13 then out:write(string.format("%d FLAGS FFF77E60=%04X\n", frame, g)); last13 = g; if g & 8 ~= 0 and snapped < 3 then snapped = snapped + 1; snapat = frame + 2 + 20*snapped end end
  out:write(string.format("%d ops %s | polys %s | %s\n", frame, table.concat(t, " "), polys(), table.concat(oparg, " ")))
  ops, oparg = {}, {}
end)
emu.register_frame_done(function()
  frame = frame + 1
  local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  sy:set_value((t >= 730 and t < 990) and AY or 128)
  if snapat and frame == snapat then manager.machine.video:snapshot() end
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if frame % 300 == 0 then out:write(string.format("%d LEVEL %04X\n", frame, mcs:read_u16(0xFF9578))) end
  if LEV >= 0 and frame >= 960 and frame < 1100 then mcs:write_u16(0xFF9578, LEV) end
  if SNAPS[frame] then manager.machine.video:snapshot() end
  if frame == END then out:close(); manager.machine:exit() end
end)
