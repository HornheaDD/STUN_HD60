-- dump ADSP data memory (words 0..0x1FFF) at each 68010 bank toggle (= job start) between frames F0 and F1, stock speed
local m = manager.machine.devices[":mainpcb:maincpu"]; local ms = m.spaces["program"]
local ad = manager.machine.devices[":mainpcb:adsp"]; local ads = ad.spaces["data"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local F0, F1 = tonumber(os.getenv("F0")), tonumber(os.getenv("F1"))
local out = io.open(os.getenv("OUT"), "w")
local frame, n = 0, 0
tc = ms:install_write_tap(0x818006, 0x818017, "ctl", function(o, d)
  if frame < F0 or frame > F1 then return end
  if o == 0x818006 or o == 0x818016 then
    n = n + 1; out:write(string.format("JOB %d frame %d\n", n, frame))
    local t = {}
    for a = 0, 0x1FFF do t[#t+1] = string.format("%04X", ads:read_u16(a) & 0xffff) end
    out:write(table.concat(t, " "), "\n")
  end
end)
local _rf = emu.register_frame_done
emu.register_frame_done(function()
  frame = frame + 1; local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720)) and 1 or 0)
  b1:set_value(t>=920 and ((t//30)%2) or 0)
  if t == F1 + 2 then out:close(); manager.machine:exit() end
end)
if os.getenv("SCRIPT") then dofile(os.getenv("SCRIPT")) end
