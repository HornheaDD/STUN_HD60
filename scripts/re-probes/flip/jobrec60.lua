-- record the 68010's ADSP job uploads (addr, value, pc, A2) per job between frames F0 and F1 (stock speed, no interp)
local m = manager.machine.devices[":mainpcb:maincpu"]; local ms = m.spaces["program"]
local MPC, MA2 = m.state["PC"], m.state["A2"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local sy = F(":mainpcb:8BADC.2","AD Stick Y")
local AY = tonumber(os.getenv("AY") or "128")
local F0, F1 = tonumber(os.getenv("F0") or "4150"), tonumber(os.getenv("F1") or "4300")
local out = io.open(os.getenv("OUT"), "w")
local frame, job = 0, 0
tc = ms:install_write_tap(0x818000, 0x81807F, "ctl", function(o, d)
  if frame < F0 or frame > F1 then return end
  if o == 0x818006 or o == 0x818016 then job = job + 1; out:write(string.format("JOB %d frame %d\n", job, frame)) end
end)
td = ms:install_write_tap(0x808000, 0x80BFFF, "dat", function(o, d)
  if frame < F0 or frame > F1 then return end
  out:write(string.format("%06X %04X %06X %08X\n", o, d & 0xffff, MPC.value, MA2.value))
end)
emu.register_frame_done(function()
  frame = frame + 1; local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  sy:set_value((t >= 730 and t < 990) and AY or 128)
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if t == F1 + 2 then out:close(); manager.machine:exit() end
end)
dofile(os.getenv("HOME") .. "/mame/scripts/stunrun-interp60.lua")
