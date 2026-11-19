-- per ADSP job: which SIM (user1 ROM) blocks the ADSP streams (base, start address, words read), plus the 68010's
-- object id writes, between frames F0 and F1 (stock speed). Output: OUT
local m = manager.machine.devices[":mainpcb:maincpu"]; local ms = m.spaces["program"]
local MPC, MA2 = m.state["PC"], m.state["A2"]
local ad = manager.machine.devices[":mainpcb:adsp"]; local ads = ad.spaces["data"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local sy = F(":mainpcb:8BADC.2","AD Stick Y")
local AY = tonumber(os.getenv("AY") or "128")
local F0, F1 = tonumber(os.getenv("F0") or "4190"), tonumber(os.getenv("F1") or "4260")
local out = io.open(os.getenv("OUT"), "w")
local frame, base, cur, n = 0, 0, nil, 0
local function flush() if cur then out:write(string.format("S %X %04X %d\n", base, cur, n)) end cur = nil; n = 0 end
tw = ads:install_write_tap(0x2000, 0x2fff, "simw", function(o, d)
  if frame < F0 or frame > F1 then return end
  local r = o & 7
  if r == 1 then flush(); cur = d & 0xffff; if SEQ then out:write(string.format("A %X %04X pc %04X\n", base, cur, ad.state["PC"].value)) end
  elseif r == 7 then flush(); base = d & 0xffff; if SEQ then out:write(string.format("B %X pc %04X\n", base, ad.state["PC"].value)) end end
end)
local SEQ = os.getenv("SEQ")
tr = ads:install_read_tap(0x2000, 0x2fff, "simr", function(o, d)
  if frame < F0 or frame > F1 then return end
  if (o & 7) == 0 then n = n + 1; if SEQ then out:write(string.format("R %04X\n", d & 0xffff)) end end
end)
tc = ms:install_write_tap(0x818000, 0x81807F, "ctl", function(o, d)
  if frame < F0 or frame > F1 then return end
  if o == 0x818006 or o == 0x818016 then flush(); out:write(string.format("JOB frame %d\n", frame)) end
end)
td = ms:install_write_tap(0x808000, 0x80BFFF, "dat", function(o, d)
  if frame < F0 or frame > F1 then return end
  local pc = MPC.value
  if pc == 0x02E22C or pc == 0x02E360 then out:write(string.format("ID %08X %04X %04X\n", MA2.value, d & 0xffff, o)) end
end)
emu.register_frame_done(function()
  frame = frame + 1; local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  sy:set_value((t >= 730 and t < 990) and AY or 128)
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if t == F1 + 2 then flush(); out:close(); manager.machine:exit() end
end)
