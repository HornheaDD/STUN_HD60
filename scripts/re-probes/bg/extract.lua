-- Extract every bitmap the game blits with display-list opcode 8 (skyline panoramas, logos) from GSP RAM.
-- Output (ROM-derived, never commit): out/img/<addr>_<hash>.raw (u16 w, u16 h, w*h pen bytes) + .pal (256 x "lo hi")
-- and out/img/index.txt (first frame seen, x, y, flags, addr, w, h, hash). Scripted game: coin/start/fire.
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local S = gspd.state
local OUT = os.getenv("HOME").."/mame/scripts/re-probes/bg/out/img/"
local END = tonumber(os.getenv("END") or "14000")
os.execute("mkdir -p "..OUT)
local idx = io.open(OUT.."index.txt","w")
local seen, frame = {}, 0
local sh = manager.machine.memory.shares
local plo, phi = sh[":mainpcb:gsp_palram_lo"], sh[":mainpcb:gsp_palram_hi"]
local function hash(a, w, h)
  local x = 2166136261
  local n = (w*h)//2
  for i = 0, n-1, 37 do x = ((x ~ gsp:read_u16(a + i*16)) * 16777619) & 0xffffffff end
  return x
end
local function dump(name, a, w, h)
  local f = io.open(OUT..name..".raw","wb"); f:write(string.pack("<I2I2", w, h))
  local t = {}
  for i = 0, (w*h)//2 - 1 do local v = gsp:read_u16(a + i*16); t[#t+1] = string.char(v & 0xff, v >> 8) end
  f:write(table.concat(t)); f:close()
  local pf = io.open(OUT..name..".pal","w")
  for i=0,255 do pf:write(string.format("%04X %04X\n", plo:read_u16(2*i), phi:read_u16(2*i))) end; pf:close()
end
tr = gsp:install_read_tap(0xFFF470E0, 0xFFF472DF, "jt", function(o, d, m)
  if o % 32 ~= 0 then return end
  local a4 = S["A4"].value & 0xffff
  if (a4 >> 12) ~= 8 then return end
  local a5 = S["A5"].value
  local x, y, fl = gsp:read_u16(a5), gsp:read_u16(a5+16), gsp:read_u16(a5+32)
  local addr = (gsp:read_u16(a5+48) << 16) | gsp:read_u16(a5+64)
  local h, w = gsp:read_u16(addr), gsp:read_u16(addr+16)
  local cnt = gsp:read_u16(addr+64)
  if w == 0 or h == 0 or w > 1024 or h > 512 then return end
  local hv = hash(addr+0x60, w, h)
  local name = string.format("%08X_%08X", addr, hv)
  if not seen[name] then
    seen[name] = true
    idx:write(string.format("%d x=%04X y=%04X fl=%04X addr=%08X w=%d h=%d cnt=%d %s\n", frame, x, y, fl, addr, w, h, cnt, name)); idx:flush()
    if cnt == 0 then dump(name, addr+0x60, w, h) end
  end
end)
emu.register_frame_done(function()
  frame = frame + 1
  local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720) or (t>=900 and t<920)) and 1 or 0)
  b1:set_value(t>=1000 and ((t//30)%2) or 0)
  if frame == END then idx:close(); manager.machine:exit() end
end)
