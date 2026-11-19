-- log display-list opcodes used per frame during a scripted game (counts + args of the non-3D ones)
local gspd = manager.machine.devices[":mainpcb:gsp"]; local gsp = gspd.spaces["program"]
local P = manager.machine.ioport.ports
local function F(p,n) return P[p].fields[n] end
local coin, coin2 = F(":mainpcb:jsa:JSAII","Coin 1"), F(":mainpcb:IN0","Coin 1")
local start, b1 = F(":mainpcb:a80000","1 Player Start"), F(":mainpcb:a80000","P1 Button 1")
local S = gspd.state
local out = io.open(os.getenv("HOME").."/mame/scripts/re-probes/bg/out/op8log.txt","w")
local frame = 0
local function words(a, n) local t = {} for i=0,n-1 do t[#t+1] = string.format("%04X", gsp:read_u16(a + i*16)) end return table.concat(t," ") end
tr = gsp:install_read_tap(0xFFF470E0, 0xFFF472DF, "jt", function(o, d, m)
  if S["PC"].value ~= 0xFFF47030 and S["PC"].value ~= 0xFFF47020 then end
  local a4 = S["A4"].value & 0xffff; local a5 = S["A5"].value
  local op = a4 >> 12
  if o % 32 == 0 and (op == 8 or op == 3 or op == 5) then
    out:write(string.format("%d op%X %04X @%08X: %s\n", frame, op, a4, a5, words(a5, 6)))
  end
end)
emu.register_frame_done(function()
  frame = frame + 1
  local t = frame
  local c=(t>=600 and t<620) or (t>=640 and t<660); coin:set_value(c and 1 or 0); coin2:set_value(c and 1 or 0)
  start:set_value(((t>=700 and t<720) or (t>=900 and t<920)) and 1 or 0)
  b1:set_value(t>=1000 and ((t//30)%2) or 0)
  if frame == 6000 then out:close(); manager.machine:exit() end
end)
